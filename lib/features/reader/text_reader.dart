import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_settings.dart';
import '../../core/models/book.dart';
import '../../core/models/shelf.dart';
import '../../core/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import 'paginator.dart';
import 'reader_models.dart';
import 'widgets/reader_settings_panel.dart';

class TextReaderView extends ConsumerStatefulWidget {
  const TextReaderView({
    super.key,
    required this.book,
    required this.content,
  });

  final Book book;
  final ReaderBook content;

  @override
  ConsumerState<TextReaderView> createState() => _TextReaderViewState();
}

class _TextReaderViewState extends ConsumerState<TextReaderView> {
  static const _footerHeight = 34.0;

  BookPagination? _pagination;
  PageController? _controller;
  _PaginationKey? _paginationKey;
  int _pageIndex = 0;
  bool _chromeVisible = true;
  bool _paginating = false;
  Timer? _saveTimer;
  int _lastSavedPage = -1;

  int _restoreChapter = 0;
  int _restoreOffset = 0;
  bool _restorePending = true;

  @override
  void initState() {
    super.initState();
    _restoreChapter = widget.book.location?.startsWith('p:') == true
        ? 0
        : _parseLocation(widget.book.location)?.$1 ?? 0;
    _restoreOffset = _parseLocation(widget.book.location)?.$2 ?? 0;
  }

  (int, int)? _parseLocation(String? value) {
    if (value == null || value.isEmpty || value.startsWith('p:')) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final chapter = int.tryParse(parts[0]);
    final offset = int.tryParse(parts[1]);
    if (chapter == null || offset == null) return null;
    return (chapter, offset);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveNow();
    _controller?.dispose();
    super.dispose();
  }

  AppSettings get _settings => ref.read(settingsProvider);

  void _ensurePagination(AppSettings settings, BoxConstraints constraints) {
    final textScaler = MediaQuery.textScalerOf(context);
    final width =
        (constraints.maxWidth - settings.readerMargin * 2).clamp(120.0, 1400.0);
    final height = constraints.maxHeight - 20 - _footerHeight;
    if (height < 120) return;

    final key = _PaginationKey(
      width: width,
      height: height,
      fontSize: settings.readerFontSize,
      lineHeight: settings.readerLineHeight,
      serif: settings.readerSerif,
      justify: settings.readerJustify,
      scale: textScaler.scale(10),
    );
    if (_paginationKey == key) return;
    _paginationKey = key;

    final old = _pagination;
    final restore = old == null
        ? (_restorePending ? (_restoreChapter, _restoreOffset) : null)
        : _locationForPage(_pageIndex);
    _paginating = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // Cede un frame para que se vea el indicador de carga.
      await Future<void>.delayed(Duration.zero);
      if (!mounted) return;

      final paginator = BookPaginator(
        fontSize: settings.readerFontSize,
        lineHeight: settings.readerLineHeight,
        serif: settings.readerSerif,
        justify: settings.readerJustify,
        textScaler: textScaler,
      );
      final result = paginator.paginate(
        book: widget.content,
        width: width,
        height: height,
      );

      var target = 0;
      if (restore != null) {
        target = result.pageForLocation(restore.$1, restore.$2);
      } else if (_pagination != null) {
        target = _pageIndex.clamp(0, result.pageCount - 1);
      }

      final oldController = _controller;
      final controller = PageController(initialPage: target);
      setState(() {
        _pagination = result;
        _controller = controller;
        _pageIndex = target;
        _paginating = false;
        _restorePending = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldController?.dispose();
      });
      _saveSoon();
    });
  }

  (int, int)? _locationForPage(int pageIndex) {
    final pagination = _pagination;
    if (pagination == null || pagination.pages.isEmpty) return null;
    final page = pagination.pages[pageIndex.clamp(0, pagination.pages.length - 1)];
    return (page.chapterIndex, page.startOffset);
  }

  void _saveSoon() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _saveNow);
  }

  void _saveNow() {
    final pagination = _pagination;
    if (pagination == null || pagination.pages.isEmpty) return;
    if (_lastSavedPage == _pageIndex) return;
    _lastSavedPage = _pageIndex;
    final page = pagination.pages[_pageIndex.clamp(0, pagination.pages.length - 1)];
    final progress = _pageIndex >= pagination.pageCount - 1
        ? 1.0
        : pagination.progressForPage(_pageIndex);
    final status = progress >= 0.985
        ? ReadingStatus.finished
        : ReadingStatus.reading;
    ref.read(libraryProvider.notifier).applyProgress(
          bookId: widget.book.id!,
          progress: progress,
          location: '${page.chapterIndex}:${page.startOffset}',
          status: status,
        );
  }

  void _onPageChanged(int index) {
    setState(() => _pageIndex = index);
    _saveSoon();
  }

  void _goToPage(int page) {
    final pagination = _pagination;
    if (pagination == null) return;
    final target = page.clamp(0, pagination.pageCount - 1);
    if (!(_controller?.hasClients ?? false)) return;
    _controller!.animateToPage(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _turnPage(int direction) {
    _goToPage(_pageIndex + direction);
  }

  void _handleTap(Offset localPosition, Size size) {
    final x = localPosition.dx / size.width;
    if (x < 0.28) {
      _turnPage(-1);
    } else if (x > 0.72) {
      _turnPage(1);
    } else {
      setState(() => _chromeVisible = !_chromeVisible);
    }
  }

  void _jumpToChapter(int chapterIndex) {
    final pagination = _pagination;
    if (pagination == null) return;
    final page = pagination.chapterFirstPage[
        chapterIndex.clamp(0, pagination.chapterFirstPage.length - 1)];
    _goToPage(page);
    Navigator.of(context).pop();
  }

  void _cycleTheme() {
    final themes = ReaderTheme.values;
    final current = _settings.readerTheme;
    final next = themes[(current.index + 1) % themes.length];
    ref.read(settingsProvider.notifier).setReaderTheme(next);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final theme = settings.readerTheme;
    final isDark =
        ThemeData.estimateBrightnessForColor(theme.background) == Brightness.dark;

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
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                    _turnPage(1),
                const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                    _turnPage(-1),
                const SingleActivator(LogicalKeyboardKey.escape): () {
                  if (_chromeVisible) {
                    setState(() => _chromeVisible = false);
                  } else {
                    context.pop();
                  }
                },
              },
              child: Focus(
                autofocus: true,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _ensurePagination(settings, constraints);
                    final pagination = _pagination;
                    final controller = _controller;

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: pagination == null || controller == null
                              ? _LoadingView(theme: theme)
                              : GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapUp: (details) => _handleTap(
                                    details.localPosition,
                                    constraints.biggest,
                                  ),
                                  child: PageView.builder(
                                    controller: controller,
                                    itemCount: pagination.pageCount,
                                    onPageChanged: _onPageChanged,
                                    physics: const PageScrollPhysics(),
                                    itemBuilder: (context, index) {
                                      return _PageView(
                                        page: pagination.pages[index],
                                        settings: settings,
                                        pageNumber: index + 1,
                                        pageCount: pagination.pageCount,
                                        footerHeight: _footerHeight,
                                      );
                                    },
                                  ),
                                ),
                        ),
                        if (_paginating && pagination != null)
                          Positioned(
                            top: 8,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: _PaginatingPill(theme: theme),
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
                              child: _TopChrome(
                                title: widget.book.title,
                                theme: theme,
                                onBack: () => context.pop(),
                                onToc: pagination == null
                                    ? null
                                    : () => _showToc(pagination),
                                onBookmark: pagination == null
                                    ? null
                                    : () => _showBookmarks(),
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
                              child: _BottomChrome(
                                theme: theme,
                                pageIndex: _pageIndex,
                                pageCount: pagination?.pageCount ?? 1,
                                chapterTitle: pagination != null &&
                                        pagination.pages.isNotEmpty
                                    ? pagination.pages[_pageIndex.clamp(
                                        0, pagination.pages.length - 1)]
                                        .chapterTitle
                                    : widget.content.chapters.isNotEmpty
                                        ? widget.content.chapters.first.title
                                        : '',
                                onSlider: (value) {
                                  if (pagination == null) return;
                                  _goToPage((value * (pagination.pageCount - 1))
                                      .round());
                                },
                                onToc: pagination == null
                                    ? null
                                    : () => _showToc(pagination),
                                onBookmark: () => _showBookmarks(),
                                onSettings: () => showReaderSettings(context),
                                onTheme: _cycleTheme,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showToc(BookPagination pagination) async {
    final currentChapter = pagination.pages.isEmpty
        ? 0
        : pagination.pages[_pageIndex.clamp(0, pagination.pages.length - 1)]
            .chapterIndex;
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
                              '${widget.content.chapters.length} capítulos',
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
                  child: ListView.builder(
                    itemCount: widget.content.chapters.length,
                    itemBuilder: (context, index) {
                      final chapter = widget.content.chapters[index];
                      final selected = index == currentChapter;
                      final title = chapter.showTitle
                          ? chapter.title
                          : 'Inicio del libro';
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 22),
                        leading: SizedBox(
                          width: 24,
                          child: Text(
                            '${index + 1}',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: selected
                                      ? palette.primary
                                      : palette.inkSoft,
                                ),
                          ),
                        ),
                        title: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: selected ? palette.primary : palette.ink,
                              ),
                        ),
                        trailing: selected
                            ? Icon(
                                Icons.auto_stories_rounded,
                                size: 18,
                                color: palette.primary,
                              )
                            : null,
                        onTap: () => _jumpToChapter(index),
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
                                      style:
                                          Theme.of(context).textTheme.bodyMedium,
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
                                    '· ${RelativeDateLabel.of(bookmark.createdAt)}',
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
                                    final location =
                                        _parseLocation(bookmark.location);
                                    final pagination = _pagination;
                                    if (location == null || pagination == null) {
                                      return;
                                    }
                                    _goToPage(
                                      pagination.pageForLocation(
                                        location.$1,
                                        location.$2,
                                      ),
                                    );
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
    final pagination = _pagination;
    if (pagination == null || pagination.pages.isEmpty) return;
    final page = pagination.pages[_pageIndex.clamp(0, pagination.pages.length - 1)];
    final location = '${page.chapterIndex}:${page.startOffset}';
    final db = ref.read(appDatabaseProvider);
    final existing = await db.getBookmarks(widget.book.id!);
    if (!mounted) return;
    if (existing.any((bookmark) => bookmark.location == location)) {
      _snack('Ya tienes un marcador en esta página.');
      return;
    }
    final progress = _pageIndex >= pagination.pageCount - 1
        ? 1.0
        : pagination.progressForPage(_pageIndex);
    await db.insertBookmark(
      Bookmark(
        bookId: widget.book.id!,
        location: location,
        label: page.chapterTitle.trim().isEmpty
            ? 'Página ${_pageIndex + 1}'
            : page.chapterTitle,
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
}

class _PaginationKey {
  const _PaginationKey({
    required this.width,
    required this.height,
    required this.fontSize,
    required this.lineHeight,
    required this.serif,
    required this.justify,
    required this.scale,
  });

  final double width;
  final double height;
  final double fontSize;
  final double lineHeight;
  final bool serif;
  final bool justify;
  final double scale;

  @override
  bool operator ==(Object other) {
    return other is _PaginationKey &&
        other.width == width &&
        other.height == height &&
        other.fontSize == fontSize &&
        other.lineHeight == lineHeight &&
        other.serif == serif &&
        other.justify == justify &&
        other.scale == scale;
  }

  @override
  int get hashCode =>
      Object.hash(width, height, fontSize, lineHeight, serif, justify, scale);
}

class _PageView extends StatelessWidget {
  const _PageView({
    required this.page,
    required this.settings,
    required this.pageNumber,
    required this.pageCount,
    required this.footerHeight,
  });

  final ReaderPage page;
  final AppSettings settings;
  final int pageNumber;
  final int pageCount;
  final double footerHeight;

  @override
  Widget build(BuildContext context) {
    final theme = settings.readerTheme;
    final paginator = BookPaginator(
      fontSize: settings.readerFontSize,
      lineHeight: settings.readerLineHeight,
      serif: settings.readerSerif,
      justify: settings.readerJustify,
      textScaler: MediaQuery.textScalerOf(context),
    );
    final textColor = theme.text;
    final muted = theme.muted;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: settings.readerMargin),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(
            child: ClipRect(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final block in page.blocks)
                    ..._blockWidgets(
                      context,
                      block,
                      paginator,
                      textColor,
                      muted,
                      firstBlock: identical(block, page.blocks.first),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: footerHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      page.chapterTitle.trim().toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppType.ui,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        color: muted.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, left: 8),
                  child: Text(
                    '$pageNumber / $pageCount',
                    style: TextStyle(
                      fontFamily: AppType.ui,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.4,
                      color: muted.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  List<Widget> _blockWidgets(
    BuildContext context,
    PagedBlock block,
    BookPaginator paginator,
    Color textColor,
    Color muted, {
    required bool firstBlock,
  }) {
    if (block.type == ReaderBlockType.divider) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: OrnamentDivider(width: 110),
        ),
      ];
    }
    final isChapterTitle = firstBlock && block.type == ReaderBlockType.heading;
    final style = paginator
        .styleFor(block.type, chapterTitle: isChapterTitle)
        .copyWith(
          color: block.type == ReaderBlockType.quote
              ? textColor.withValues(alpha: 0.82)
              : textColor,
        );
    final content = Text(
      block.text,
      style: style,
      textAlign: isChapterTitle
          ? TextAlign.left
          : (settings.readerJustify ? TextAlign.justify : TextAlign.left),
    );
    final spacing = isChapterTitle
        ? BookPaginator.titleSpacing
        : BookPaginator.spacingAfter(block.type);
    return [
      content,
      SizedBox(height: math.max(0, spacing - 1)),
    ];
  }
}

class _TopChrome extends StatelessWidget {
  const _TopChrome({
    required this.title,
    required this.theme,
    required this.onBack,
    required this.onToc,
    required this.onBookmark,
  });

  final String title;
  final ReaderTheme theme;
  final VoidCallback onBack;
  final VoidCallback? onToc;
  final VoidCallback? onBookmark;

  @override
  Widget build(BuildContext context) {
    final dark =
        ThemeData.estimateBrightnessForColor(theme.background) == Brightness.dark;
    final color = theme.text;
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
            color: color,
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
                letterSpacing: -0.1,
                color: color,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Índice',
            onPressed: onToc,
            icon: const Icon(Icons.format_list_bulleted_rounded, size: 20),
            color: color,
          ),
          IconButton(
            tooltip: 'Marcadores',
            onPressed: onBookmark,
            icon: const Icon(Icons.bookmark_border_rounded, size: 21),
            color: color,
          ),
        ],
      ),
    );
  }
}

class _BottomChrome extends StatelessWidget {
  const _BottomChrome({
    required this.theme,
    required this.pageIndex,
    required this.pageCount,
    required this.chapterTitle,
    required this.onSlider,
    required this.onToc,
    required this.onBookmark,
    required this.onSettings,
    required this.onTheme,
  });

  final ReaderTheme theme;
  final int pageIndex;
  final int pageCount;
  final String chapterTitle;
  final ValueChanged<double> onSlider;
  final VoidCallback? onToc;
  final VoidCallback onBookmark;
  final VoidCallback onSettings;
  final VoidCallback onTheme;

  @override
  Widget build(BuildContext context) {
    final dark =
        ThemeData.estimateBrightnessForColor(theme.background) == Brightness.dark;
    final color = theme.text;
    final muted = theme.muted;
    final progress = pageCount <= 1 ? 0.0 : pageIndex / (pageCount - 1);
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
              Text(
                '${pageIndex + 1}',
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
                chapterTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppType.ui,
                  fontSize: 10,
                  letterSpacing: 0.3,
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
              value: progress.clamp(0.0, 1.0),
              onChanged: onSlider,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ChromeAction(
                icon: Icons.format_list_bulleted_rounded,
                label: 'Índice',
                color: color,
                muted: muted,
                onTap: onToc,
              ),
              _ChromeAction(
                icon: Icons.bookmark_add_outlined,
                label: 'Marcador',
                color: color,
                muted: muted,
                onTap: onBookmark,
              ),
              _ChromeAction(
                icon: Icons.text_fields_rounded,
                label: 'Ajustes',
                color: color,
                muted: muted,
                onTap: onSettings,
              ),
              _ChromeAction(
                icon: Icons.palette_outlined,
                label: theme.label,
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

class _ChromeAction extends StatelessWidget {
  const _ChromeAction({
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

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.theme});

  final ReaderTheme theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: theme.text.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Componiendo las páginas…',
            style: TextStyle(
              fontFamily: AppType.display,
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: theme.text.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaginatingPill extends StatelessWidget {
  const _PaginatingPill({required this.theme});

  final ReaderTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.background.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: theme.text.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: theme.text.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Ajustando',
            style: TextStyle(
              fontFamily: AppType.ui,
              fontSize: 10,
              color: theme.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fecha relativa compacta para los marcadores.
class RelativeDateLabel {
  const RelativeDateLabel._();

  static String of(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inHours < 1) return 'hace ${diff.inMinutes} min';
    if (diff.inDays < 1) return 'hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'hace ${diff.inDays} d';
    return '${date.day}/${date.month}/${date.year}';
  }
}
