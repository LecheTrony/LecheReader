import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/models/book.dart';
import '../../core/models/shelf.dart';
import '../../core/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import 'pdf_page_layout.dart';
import 'widgets/reader_settings_panel.dart';

/// Lector de documentos PDF con navegación continua, índice y marcadores.
class PdfReaderView extends ConsumerStatefulWidget {
  const PdfReaderView({super.key, required this.book});

  final Book book;

  @override
  ConsumerState<PdfReaderView> createState() => _PdfReaderViewState();
}

class _PdfReaderViewState extends ConsumerState<PdfReaderView> {
  late final PdfViewerController _controller;
  late int _currentPage;
  int _pageCount = 0;
  bool _chromeVisible = true;
  bool _ready = false;
  Timer? _saveTimer;
  int _lastSavedPage = -1;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    _currentPage = _initialPage(widget.book.location);
  }

  int _initialPage(String? location) {
    if (location == null || !location.startsWith('p:')) return 1;
    return math.max(1, int.tryParse(location.substring(2)) ?? 1);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveNow();
    super.dispose();
  }

  void _saveSoon() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _saveNow);
  }

  void _saveNow() {
    if (!_ready || _pageCount <= 0) return;
    if (_lastSavedPage == _currentPage) return;
    _lastSavedPage = _currentPage;
    final progress = (_currentPage / _pageCount).clamp(0.0, 1.0);
    ref.read(libraryProvider.notifier).applyProgress(
          bookId: widget.book.id!,
          progress: progress,
          location: 'p:$_currentPage',
          status: progress >= 0.995
              ? ReadingStatus.finished
              : ReadingStatus.reading,
        );
  }

  void _onPageChanged(int? page) {
    if (page == null || page == _currentPage) return;
    setState(() => _currentPage = page);
    _saveSoon();
  }

  Future<void> _goToPage(int page) async {
    if (!_ready || _pageCount <= 0) return;
    final target = page.clamp(1, _pageCount);
    if (target == _currentPage) return;
    await _controller.goToPage(
      pageNumber: target,
      duration: const Duration(milliseconds: 240),
    );
  }

  void _cycleTheme() {
    final themes = ReaderTheme.values;
    final current = ref.read(settingsProvider).readerTheme;
    ref
        .read(settingsProvider.notifier)
        .setReaderTheme(themes[(current.index + 1) % themes.length]);
  }

  Future<void> _showOutline() async {
    if (!_ready) return;
    final entries = await _controller.useDocument((document) async {
      final outline = await document.loadOutline();
      final list = <({String title, int page, int depth})>[];
      void walk(List<PdfOutlineNode> nodes, int depth) {
        for (final node in nodes) {
          final page = node.dest?.pageNumber;
          if (node.title.trim().isNotEmpty) {
            list.add((
              title: node.title.trim(),
              page: page ?? 0,
              depth: depth,
            ));
          }
          if (node.children.isNotEmpty) walk(node.children, depth + 1);
        }
      }

      walk(outline, 0);
      return list;
    });
    if (!mounted) return;
    final items = entries ?? const <({String title, int page, int depth})>[];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final palette = context.palette;
        return FractionallySizedBox(
          heightFactor: 0.78,
          child: Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Índice',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              '$_pageCount páginas',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.format_list_bulleted_rounded,
                                  size: 36,
                                  color: palette.inkSoft,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Este PDF no incluye un índice.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Puedes moverte con la barra inferior '
                                  'o con el gesto de desplazamiento.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final entry = items[index];
                            final selected = entry.page == _currentPage;
                            return ListTile(
                              contentPadding: EdgeInsets.only(
                                left: 22 + entry.depth * 16.0,
                                right: 22,
                              ),
                              title: Text(
                                entry.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: selected
                                          ? palette.primary
                                          : palette.ink,
                                    ),
                              ),
                              trailing: entry.page > 0
                                  ? Text(
                                      '${entry.page}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(color: palette.inkSoft),
                                    )
                                  : null,
                              onTap: entry.page <= 0
                                  ? null
                                  : () {
                                      Navigator.of(sheetContext).pop();
                                      _goToPage(entry.page);
                                    },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showBookmarks() async {
    final bookId = widget.book.id!;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final palette = context.palette;
            final bookmarks = ref.watch(bookmarksProvider(bookId));
            final items = bookmarks.value ?? const <Bookmark>[];
            return FractionallySizedBox(
              heightFactor: 0.7,
              child: Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Marcadores',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await _addBookmark();
                            ref.invalidate(bookmarksProvider(bookId));
                          },
                          icon: const Icon(Icons.bookmark_add_outlined, size: 19),
                          label: const Text('Marcar esta página'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(),
                    Expanded(
                      child: items.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(30),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bookmark_border_rounded,
                                      size: 36,
                                      color: palette.inkSoft,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Todavía no hay marcadores.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Marca una página para volver a ella '
                                      'cuando quieras.',
                                      textAlign: TextAlign.center,
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final bookmark = items[index];
                                return ListTile(
                                  contentPadding: const EdgeInsets.only(
                                    left: 22,
                                    right: 8,
                                  ),
                                  leading: Icon(
                                    Icons.bookmark_rounded,
                                    color: palette.primary,
                                    size: 20,
                                  ),
                                  title: Text(
                                    bookmark.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${(bookmark.progress * 100).round()}% '
                                    '· ${_relativeDate(bookmark.createdAt)}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'Eliminar',
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 19,
                                      color: palette.inkSoft,
                                    ),
                                    onPressed: () async {
                                      await ref
                                          .read(appDatabaseProvider)
                                          .deleteBookmark(bookmark.id!);
                                      ref.invalidate(
                                        bookmarksProvider(bookId),
                                      );
                                    },
                                  ),
                                  onTap: () {
                                    Navigator.of(sheetContext).pop();
                                    final page = _initialPage(
                                      bookmark.location,
                                    );
                                    _goToPage(page);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addBookmark() async {
    if (!_ready || _pageCount <= 0) return;
    final location = 'p:$_currentPage';
    final db = ref.read(appDatabaseProvider);
    final existing = await db.getBookmarks(widget.book.id!);
    if (!mounted) return;
    if (existing.any((bookmark) => bookmark.location == location)) {
      _snack('Ya tienes un marcador en esta página.');
      return;
    }
    final progress = (_currentPage / _pageCount).clamp(0.0, 1.0);
    await db.insertBookmark(
      Bookmark(
        bookId: widget.book.id!,
        location: location,
        label: 'Página $_currentPage',
        progress: progress,
        createdAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    _snack('Marcador añadido.');
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.readerTheme;
    final isDark =
        ThemeData.estimateBrightnessForColor(theme.background) ==
            Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: theme.background,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: theme.background,
            ),
      child: PopScope(
        canPop: !_chromeVisible,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          setState(() => _chromeVisible = false);
        },
        child: Scaffold(
          backgroundColor: theme.background,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: PdfViewer.file(
                    widget.book.filePath,
                    controller: _controller,
                    initialPageNumber: _currentPage,
                    params: PdfViewerParams(
                      backgroundColor: theme.background,
                      margin: 10,
                      layoutPages: layoutPdfPages,
                      pageDropShadow: BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                      onViewerReady: (document, controller) {
                        if (!mounted) return;
                        setState(() {
                          _ready = true;
                          _pageCount = document.pages.length;
                          _currentPage =
                              (controller.pageNumber ?? _currentPage)
                                  .clamp(1, math.max(1, _pageCount));
                        });
                        _saveSoon();
                      },
                      onPageChanged: _onPageChanged,
                      onGeneralTap: (context, controller, details) {
                        if (details.type != PdfViewerGeneralTapType.tap) {
                          return false;
                        }
                        final width = controller.viewSize.width;
                        if (width <= 0) return false;
                        final x = details.localPosition.dx / width;
                        if (x < 0.22) {
                          _goToPage(_currentPage - 1);
                        } else if (x > 0.78) {
                          _goToPage(_currentPage + 1);
                        } else {
                          setState(() => _chromeVisible = !_chromeVisible);
                        }
                        return true;
                      },
                    ),
                  ),
                ),
                if (!_ready)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: theme.text.withValues(alpha: 0.55),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Abriendo el documento…',
                              style: TextStyle(
                                fontFamily: AppType.display,
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                                color: theme.text.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: !_chromeVisible,
                    child: AnimatedOpacity(
                      opacity: _chromeVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: _PdfTopChrome(
                        title: widget.book.title,
                        theme: theme,
                        onBack: () => context.pop(),
                        onOutline: _ready ? _showOutline : null,
                        onBookmark: _ready ? _showBookmarks : null,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: !_chromeVisible,
                    child: AnimatedOpacity(
                      opacity: _chromeVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: _PdfBottomChrome(
                        theme: theme,
                        currentPage: _currentPage,
                        pageCount: _pageCount,
                        onSlider: (value) {
                          if (_pageCount <= 1) return;
                          _goToPage(
                            (value * (_pageCount - 1)).round() + 1,
                          );
                        },
                        onPrevious: () => _goToPage(_currentPage - 1),
                        onNext: () => _goToPage(_currentPage + 1),
                        onOutline: _ready ? _showOutline : null,
                        onBookmark: _ready ? _showBookmarks : null,
                        onSettings: () => showReaderSettings(context),
                        onTheme: _cycleTheme,
                        themeLabel: theme.label,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PdfTopChrome extends StatelessWidget {
  const _PdfTopChrome({
    required this.title,
    required this.theme,
    required this.onBack,
    required this.onOutline,
    required this.onBookmark,
  });

  final String title;
  final ReaderTheme theme;
  final VoidCallback onBack;
  final VoidCallback? onOutline;
  final VoidCallback? onBookmark;

  @override
  Widget build(BuildContext context) {
    final dark =
        ThemeData.estimateBrightnessForColor(theme.background) ==
            Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.background.withValues(alpha: 0.97),
        border: Border(
          bottom: BorderSide(
            color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 21),
            color: theme.text,
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppType.ui,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.text,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Índice',
            onPressed: onOutline,
            icon: const Icon(Icons.format_list_bulleted_rounded, size: 20),
            color: theme.text,
          ),
          IconButton(
            tooltip: 'Marcadores',
            onPressed: onBookmark,
            icon: const Icon(Icons.bookmark_border_rounded, size: 21),
            color: theme.text,
          ),
        ],
      ),
    );
  }
}

class _PdfBottomChrome extends StatelessWidget {
  const _PdfBottomChrome({
    required this.theme,
    required this.currentPage,
    required this.pageCount,
    required this.onSlider,
    required this.onPrevious,
    required this.onNext,
    required this.onOutline,
    required this.onBookmark,
    required this.onSettings,
    required this.onTheme,
    required this.themeLabel,
  });

  final ReaderTheme theme;
  final int currentPage;
  final int pageCount;
  final ValueChanged<double> onSlider;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onOutline;
  final VoidCallback? onBookmark;
  final VoidCallback onSettings;
  final VoidCallback onTheme;
  final String themeLabel;

  @override
  Widget build(BuildContext context) {
    final dark =
        ThemeData.estimateBrightnessForColor(theme.background) ==
            Brightness.dark;
    final color = theme.text;
    final muted = theme.muted;
    final progress = pageCount <= 1
        ? 0.0
        : ((currentPage - 1) / (pageCount - 1)).clamp(0.0, 1.0);
    return Container(
      decoration: BoxDecoration(
        color: theme.background.withValues(alpha: 0.98),
        border: Border(
          top: BorderSide(
            color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Página anterior',
                onPressed: currentPage > 1 ? onPrevious : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                color: color,
                visualDensity: VisualDensity.compact,
              ),
              Text(
                '$currentPage',
                style: TextStyle(
                  fontFamily: AppType.ui,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                ' / $pageCount',
                style: TextStyle(
                  fontFamily: AppType.ui,
                  fontSize: 11,
                  color: muted,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(
                  fontFamily: AppType.ui,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
              IconButton(
                tooltip: 'Página siguiente',
                onPressed: currentPage < pageCount ? onNext : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                color: color,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: muted.withValues(alpha: 0.28),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.12),
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: progress,
              onChanged: onSlider,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _PdfAction(
                icon: Icons.format_list_bulleted_rounded,
                label: 'Índice',
                color: color,
                muted: muted,
                onTap: onOutline,
              ),
              _PdfAction(
                icon: Icons.bookmark_add_outlined,
                label: 'Marcador',
                color: color,
                muted: muted,
                onTap: onBookmark,
              ),
              _PdfAction(
                icon: Icons.text_fields_rounded,
                label: 'Ajustes',
                color: color,
                muted: muted,
                onTap: onSettings,
              ),
              _PdfAction(
                icon: Icons.palette_outlined,
                label: themeLabel,
                color: color,
                muted: muted,
                onTap: onTheme,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PdfAction extends StatelessWidget {
  const _PdfAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.muted,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppType.ui,
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _relativeDate(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'ahora';
  if (diff.inHours < 1) return 'hace ${diff.inMinutes} min';
  if (diff.inDays < 1) return 'hace ${diff.inHours} h';
  if (diff.inDays < 7) return 'hace ${diff.inDays} d';
  return '${date.day}/${date.month}/${date.year}';
}
