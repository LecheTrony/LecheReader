import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/book.dart';
import '../../core/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import 'book_parser.dart';
import 'comic_reader.dart';
import 'immersive_mode.dart';
import 'pdf_reader.dart';
import 'reader_models.dart';
import 'text_reader.dart';

/// Carga el contenido del libro y deriva al lector adecuado según el formato.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.bookId});

  final int bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  Book? _book;
  ReaderBook? _content;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(ImmersiveMode.enter());
    _load();
  }

  @override
  void dispose() {
    unawaited(ImmersiveMode.exit());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final book = await db.getBook(widget.bookId);
      if (book == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Este libro ya no está en tu biblioteca.';
        });
        return;
      }

      ReaderBook? content;
      if (book.format.isTextBased) {
        content = await const BookContentParser().parse(
          filePath: book.filePath,
          format: book.format,
          fallbackTitle: book.title,
          author: book.author,
        );
      }

      if (!mounted) return;
      setState(() {
        _book = book;
        _content = content;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is FormatException
            ? error.message
            : 'No pudimos abrir este archivo. Comprueba que no esté dañado.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(settingsProvider).readerTheme;
    final fallbackTitle = ref
            .watch(bookByIdProvider(widget.bookId))
            ?.title ??
        'Leyendo';

    if (_loading) {
      return _ReaderLoadingScaffold(
        title: fallbackTitle,
        theme: theme,
      );
    }

    if (_error != null || _book == null) {
      return _ReaderErrorScaffold(
        title: fallbackTitle,
        message: _error ?? 'No encontramos este libro.',
        theme: theme,
      );
    }

    final book = _book!;
    return switch (book.format) {
      BookFormat.pdf => PdfReaderView(book: book),
      BookFormat.cbz => ComicReaderView(book: book),
      _ => TextReaderView(
          book: book,
          content: _content!,
        ),
    };
  }
}

class _ReaderLoadingScaffold extends StatelessWidget {
  const _ReaderLoadingScaffold({
    required this.title,
    required this.theme,
  });

  final String title;
  final ReaderTheme theme;

  @override
  Widget build(BuildContext context) {
    final dark =
        ThemeData.estimateBrightnessForColor(theme.background) ==
            Brightness.dark;
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: theme.text,
        systemOverlayStyle:
            dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: AppType.ui,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.text,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: theme.text.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Preparando la lectura…',
              style: TextStyle(
                fontFamily: AppType.display,
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: theme.text.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppType.ui,
                fontSize: 12,
                color: theme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderErrorScaffold extends StatelessWidget {
  const _ReaderErrorScaffold({
    required this.title,
    required this.message,
    required this.theme,
  });

  final String title;
  final String message;
  final ReaderTheme theme;

  @override
  Widget build(BuildContext context) {
    final dark =
        ThemeData.estimateBrightnessForColor(theme.background) ==
            Brightness.dark;
    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: theme.text,
        systemOverlayStyle:
            dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: theme.text.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.menu_book_outlined,
                  size: 36,
                  color: theme.text.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'No se pudo abrir el libro',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppType.display,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: theme.text,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppType.ui,
                  fontSize: 13,
                  color: theme.muted,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppType.ui,
                  fontSize: 13.5,
                  height: 1.55,
                  color: theme.text.withValues(alpha: 0.76),
                ),
              ),
              const SizedBox(height: 26),
              OutlinedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Volver'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.text,
                  side: BorderSide(
                    color: theme.text.withValues(alpha: 0.24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
