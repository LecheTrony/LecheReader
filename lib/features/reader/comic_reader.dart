import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/models/book.dart';
import '../../core/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import 'widgets/reader_settings_panel.dart';

/// Lector de cómics CBZ: extrae las imágenes a caché y las muestra página a
/// página con zoom.
class ComicReaderView extends ConsumerStatefulWidget {
  const ComicReaderView({super.key, required this.book});

  final Book book;

  @override
  ConsumerState<ComicReaderView> createState() => _ComicReaderViewState();
}

class _ComicReaderViewState extends ConsumerState<ComicReaderView> {
  late int _currentPage;
  List<String> _pages = const [];
  PageController? _controller;
  bool _loading = true;
  String? _error;
  bool _chromeVisible = true;
  bool _zoomed = false;
  Timer? _saveTimer;
  int _lastSavedPage = -1;

  @override
  void initState() {
    super.initState();
    _currentPage = _initialPage(widget.book.location);
    _load();
  }

  int _initialPage(String? location) {
    if (location == null || !location.startsWith('p:')) return 1;
    return math.max(1, int.tryParse(location.substring(2)) ?? 1);
  }

  Future<void> _load() async {
    try {
      final extension = p.extension(widget.book.filePath).toLowerCase();
      if (extension == '.cbr' || extension == '.rar') {
        throw const FormatException(
          'Los cómics CBR todavía no se pueden abrir. '
          'Convierte el archivo a CBZ para leerlo aquí.',
        );
      }

      final cache = await getTemporaryDirectory();
      final bookKey = widget.book.id ?? widget.book.hash ?? widget.book.title.hashCode;
      final target = Directory(p.join(cache.path, 'comics', 'comic_$bookKey'));
      final manifest = File(p.join(target.path, 'pages.txt'));

      List<String> pages;
      if (await manifest.exists()) {
        pages = (await manifest.readAsLines())
            .map((name) => p.join(target.path, name))
            .where((path) => File(path).existsSync())
            .toList();
      } else {
        if (await target.exists()) await target.delete(recursive: true);
        await target.create(recursive: true);
        final sourcePath = widget.book.filePath;
        final outputPath = target.path;
        pages = await _extractInIsolate(sourcePath, outputPath);
        if (pages.isEmpty) {
          throw const FormatException(
            'Este cómic no contiene imágenes que podamos mostrar.',
          );
        }
        await manifest.writeAsString(
          pages.map((path) => p.basename(path)).join('\n'),
        );
      }

      if (!mounted) return;
      final start = _currentPage.clamp(1, pages.length);
      final controller = PageController(initialPage: start - 1);
      setState(() {
        _pages = pages;
        _controller = controller;
        _currentPage = start;
        _loading = false;
      });
      _saveSoon();
    } catch (error, stackTrace) {
      debugPrint('ComicReader: no se pudo abrir ${widget.book.filePath}: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is FormatException
            ? error.message
            : 'No pudimos abrir este cómic. Comprueba que el archivo no esté dañado.';
      });
    }
  }

  /// Extrae las páginas fuera del hilo principal. La función es estática y
  /// síncrona para que el cierre no capture el contexto async del widget.
  static Future<List<String>> _extractInIsolate(
    String sourcePath,
    String outputPath,
  ) {
    return Isolate.run(() => _extractComic(sourcePath, outputPath));
  }

  @override
  void dispose() {
    _saveTimer?.cancel();    _saveNow();
    _controller?.dispose();
    super.dispose();
  }

  void _saveSoon() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _saveNow);
  }

  void _saveNow() {
    if (_pages.isEmpty) return;
    if (_lastSavedPage == _currentPage) return;
    _lastSavedPage = _currentPage;
    final progress = (_currentPage / _pages.length).clamp(0.0, 1.0);
    ref.read(libraryProvider.notifier).applyProgress(
          bookId: widget.book.id!,
          progress: progress,
          location: 'p:$_currentPage',
          status: progress >= 0.999
              ? ReadingStatus.finished
              : ReadingStatus.reading,
        );
  }

  void _onPageChanged(int index) {
    if (_zoomed) {
      setState(() => _zoomed = false);
    }
    setState(() => _currentPage = index + 1);
    _saveSoon();
  }

  void _goToPage(int page) {
    if (_pages.isEmpty || _controller == null) return;
    final target = page.clamp(1, _pages.length);
    if (!_controller!.hasClients) return;
    _controller!.animateToPage(
      target - 1,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleTap(Offset position, Size size) {
    final x = position.dx / size.width;
    if (_zoomed) {
      setState(() => _chromeVisible = !_chromeVisible);
      return;
    }
    if (x < 0.28) {
      _goToPage(_currentPage - 1);
    } else if (x > 0.72) {
      _goToPage(_currentPage + 1);
    } else {
      setState(() => _chromeVisible = !_chromeVisible);
    }
  }

  void _cycleTheme() {
    final themes = ReaderTheme.values;
    final current = ref.read(settingsProvider).readerTheme;
    ref
        .read(settingsProvider.notifier)
        .setReaderTheme(themes[(current.index + 1) % themes.length]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(settingsProvider).readerTheme;
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
                Positioned.fill(child: _buildBody(theme)),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    ignoring: !_chromeVisible,
                    child: AnimatedOpacity(
                      opacity: _chromeVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: _ComicTopChrome(
                        title: widget.book.title,
                        theme: theme,
                        onBack: () => context.pop(),
                      ),
                    ),
                  ),
                ),
                if (!_loading && _error == null && _pages.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: !_chromeVisible,
                      child: AnimatedOpacity(
                        opacity: _chromeVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: _ComicBottomChrome(
                          theme: theme,
                          currentPage: _currentPage,
                          pageCount: _pages.length,
                          onSlider: (value) {
                            if (_pages.length <= 1) return;
                            _goToPage(
                              (value * (_pages.length - 1)).round() + 1,
                            );
                          },
                          onPrevious: () => _goToPage(_currentPage - 1),
                          onNext: () => _goToPage(_currentPage + 1),
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

  Widget _buildBody(ReaderTheme theme) {
    if (_loading) {
      return Center(
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
              'Preparando las viñetas…',
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

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: theme.text.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  size: 34,
                  color: theme.text.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No se pudo abrir el cómic',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppType.display,
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  color: theme.text,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppType.ui,
                  fontSize: 13.5,
                  height: 1.55,
                  color: theme.muted,
                ),
              ),
              const SizedBox(height: 22),
              OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.text,
                  side: BorderSide(color: theme.text.withValues(alpha: 0.25)),
                ),
                child: const Text('Volver a la biblioteca'),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || _pages.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return PageView.builder(
          controller: controller,
          physics: _zoomed
              ? const NeverScrollableScrollPhysics()
              : const PageScrollPhysics(),
          onPageChanged: _onPageChanged,
          itemCount: _pages.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) =>
                  _handleTap(details.localPosition, constraints.biggest),
              child: _ComicPage(
                key: ValueKey(_pages[index]),
                path: _pages[index],
                onZoomChanged: (zoomed) {
                  if (_zoomed == zoomed) return;
                  setState(() => _zoomed = zoomed);
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _ComicPage extends StatefulWidget {
  const _ComicPage({
    super.key,
    required this.path,
    required this.onZoomChanged,
  });

  final String path;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ComicPage> createState() => _ComicPageState();
}

class _ComicPageState extends State<_ComicPage> {
  late final TransformationController _controller;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _controller = TransformationController()..addListener(_onTransform);
  }

  void _onTransform() {
    final zoomed = _controller.value.getMaxScaleOnAxis() > 1.02;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged(zoomed);
    setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTransform)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _controller,
      minScale: 1,
      maxScale: 4.5,
      panEnabled: _zoomed,
      scaleEnabled: true,
      clipBehavior: Clip.none,
      child: Center(
        child: Image.file(
          File(widget.path),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          cacheWidth: 2000,
          errorBuilder: (context, error, stack) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 40,
                  color: context.palette.inkSoft,
                ),
                const SizedBox(height: 10),
                Text(
                  'No se pudo mostrar esta página.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComicTopChrome extends StatelessWidget {
  const _ComicTopChrome({
    required this.title,
    required this.theme,
    required this.onBack,
  });

  final String title;
  final ReaderTheme theme;
  final VoidCallback onBack;

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
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
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
        ],
      ),
    );
  }
}

class _ComicBottomChrome extends StatelessWidget {
  const _ComicBottomChrome({
    required this.theme,
    required this.currentPage,
    required this.pageCount,
    required this.onSlider,
    required this.onPrevious,
    required this.onNext,
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
        : (currentPage / pageCount).clamp(0.0, 1.0);
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
              _ComicAction(
                icon: Icons.text_fields_rounded,
                label: 'Ajustes',
                color: color,
                muted: muted,
                onTap: onSettings,
              ),
              _ComicAction(
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

class _ComicAction extends StatelessWidget {
  const _ComicAction({
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
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

/// Extrae las imágenes del CBZ en un isolate, para no bloquear la interfaz.
List<String> _extractComic(String filePath, String outputDir) {
  const extensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.bmp',
    '.avif',
  };
  final archive = ZipDecoder().decodeBytes(File(filePath).readAsBytesSync());
  final entries = archive.files
      .where((file) => file.isFile)
      .where((file) => extensions.contains(p.extension(file.name).toLowerCase()))
      .where((file) => !p.basename(file.name).startsWith('.'))
      .toList()
    ..sort(
      (a, b) => compareNatural(
        p.basename(a.name).toLowerCase(),
        p.basename(b.name).toLowerCase(),
      ),
    );

  final paths = <String>[];
  var index = 0;
  for (final entry in entries) {
    index++;
    final extension = p.extension(entry.name).toLowerCase();
    final name = 'page_${index.toString().padLeft(4, '0')}$extension';
    final output = File(p.join(outputDir, name));
    output.writeAsBytesSync(entry.content as List<int>);
    paths.add(output.path);
  }
  return paths;
}
