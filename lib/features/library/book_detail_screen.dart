import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/book.dart';
import '../../core/models/shelf.dart';
import '../../core/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/book_cover.dart';
import '../../core/widgets/common.dart';

class BookDetailScreen extends ConsumerStatefulWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final int bookId;

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  Future<void> _read(Book book) async {
    await ref.read(libraryProvider.notifier).markOpened(book.id!);
    if (!mounted) return;
    await context.push('/reader/${book.id}');
    if (!mounted) return;
    await ref.read(libraryProvider.notifier).softReload();
  }

  Future<void> _toggleFavorite(Book book) async {
    await ref.read(libraryProvider.notifier).toggleFavorite(book);
  }

  Future<void> _delete(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar libro'),
        content: Text(
          '¿Seguro que quieres eliminar «${book.title}»?\n\n'
          'Se borrarán el archivo y la portada de este dispositivo. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.palette.danger,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _silentDelete(book.filePath);
    if (book.coverPath != null) await _silentDelete(book.coverPath!);
    await ref.read(libraryProvider.notifier).deleteBook(book);
    await ref.read(shelvesProvider.notifier).refreshCounts();
    if (!mounted) return;
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Libro eliminado')),
    );
  }

  Future<void> _silentDelete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // La limpieza de archivos es best-effort.
    }
  }

  Future<void> _showActions(Book book) async {
    final palette = context.palette;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 28),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: const Icon(Icons.edit_outlined, size: 21),
                  title: const Text('Editar información'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _editMetadata(book);
                  },
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Icon(
                    book.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 21,
                    color: book.isFavorite ? palette.primary : null,
                  ),
                  title: Text(
                    book.isFavorite
                        ? 'Quitar de favoritos'
                        : 'Añadir a favoritos',
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _toggleFavorite(book);
                  },
                ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    size: 21,
                    color: palette.danger,
                  ),
                  title: Text(
                    'Eliminar de la biblioteca',
                    style: TextStyle(color: palette.danger),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _delete(book);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editMetadata(Book book) async {
    final titleController = TextEditingController(text: book.title);
    final authorController = TextEditingController(text: book.author);
    final descriptionController = TextEditingController(text: book.description);

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final palette = context.palette;
        return AlertDialog(
          title: const Text('Editar información'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: authorController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Autor'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Sinopsis'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: palette.primary,
              ),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (saved == true) {
      final updated = book.copyWith(
        title: titleController.text.trim().isEmpty
            ? book.title
            : titleController.text.trim(),
        author: authorController.text.trim(),
        description: descriptionController.text.trim(),
      );
      await ref.read(libraryProvider.notifier).updateMetadata(updated);
    }
    titleController.dispose();
    authorController.dispose();
    descriptionController.dispose();
  }

  Future<void> _showShelves(Book book) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ShelfPickerSheet(book: book),
    );
    if (!mounted) return;
    ref.invalidate(bookShelvesProvider(book.id!));
    await ref.read(shelvesProvider.notifier).refreshCounts();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final book = ref.watch(bookByIdProvider(widget.bookId));

    if (book == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Este libro ya no está en tu biblioteca.')),
      );
    }

    final accent = accentForBook(book, palette);
    final accentGradient = coverGradientFor(book, palette);
    final onAccentColor = onAccent(accent);
    final isDarkAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 360,
            backgroundColor: palette.background,
            surfaceTintColor: Colors.transparent,
            systemOverlayStyle:
                isDarkAccent ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            leadingWidth: 66,
            leading: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Center(
                child: SoftIconButton(
                  icon: Icons.arrow_back_rounded,
                  size: 40,
                  iconSize: 20,
                  onPressed: () => context.pop(),
                ),
              ),
            ),
            actions: [
              SoftIconButton(
                icon: book.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: 40,
                iconSize: 20,
                foreground: book.isFavorite ? palette.primary : palette.ink,
                onPressed: () => _toggleFavorite(book),
              ),
              const SizedBox(width: 8),
              SoftIconButton(
                icon: Icons.more_horiz_rounded,
                size: 40,
                iconSize: 20,
                onPressed: () => _showActions(book),
              ),
              const SizedBox(width: 14),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          accentGradient.first,
                          accentGradient.last,
                          palette.background,
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -60,
                    top: -30,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: onAccentColor.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -40,
                    top: 160,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: onAccentColor.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 26,
                    child: Center(
                      child: BookCover(
                        book: book,
                        width: 164,
                        height: 246,
                        borderRadius: 12,
                        showProgress: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        book.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        book.displayAuthor,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: palette.inkSoft,
                            ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetaPill(
                            icon: book.format.icon,
                            label: book.format.label,
                          ),
                          if (book.pageCount != null && book.pageCount! > 0)
                            _MetaPill(
                              icon: Icons.layers_outlined,
                              label:
                                  '${book.pageCount} ${book.format.unitLabel}',
                            ),
                          _MetaPill(
                            icon: Icons.data_usage_rounded,
                            label: formatFileSize(book.fileSize),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      if (book.isStarted) _ProgressBlock(book: book),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _read(book),
                          icon: Icon(
                            book.isStarted
                                ? Icons.play_arrow_rounded
                                : Icons.auto_stories_rounded,
                            size: 21,
                          ),
                          label: Text(
                            book.isFinished
                                ? 'Volver a leer'
                                : book.isStarted
                                    ? 'Continuar leyendo'
                                    : 'Empezar a leer',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showShelves(book),
                          icon: const Icon(Icons.collections_bookmark_outlined,
                              size: 19),
                          label: const Text('Añadir a estantería'),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const OrnamentDivider(width: 100),
                      const SizedBox(height: 26),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Sinopsis',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          book.description.trim().isEmpty
                              ? 'Este libro todavía no tiene sinopsis. Puedes añadir una desde «Editar información».'
                              : book.description.trim(),
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                height: 1.65,
                                color: book.description.trim().isEmpty
                                    ? palette.inkSoft
                                    : palette.ink,
                              ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Detalles',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _DetailRow(label: 'Formato', value: book.format.label),
                      if (book.pageCount != null)
                        _DetailRow(
                          label: book.format.isFixedLayout
                              ? 'Páginas'
                              : 'Capítulos',
                          value: '${book.pageCount}',
                        ),
                      _DetailRow(
                        label: 'Tamaño',
                        value: formatFileSize(book.fileSize),
                      ),
                      _DetailRow(
                        label: 'Añadido',
                        value: formatDate(book.addedAt),
                      ),
                      if (book.publisher?.isNotEmpty == true)
                        _DetailRow(
                          label: 'Editorial',
                          value: book.publisher!,
                        ),
                      if (book.publishedDate?.isNotEmpty == true)
                        _DetailRow(
                          label: 'Publicado',
                          value: book.publishedDate!,
                        ),
                      if (book.language?.isNotEmpty == true)
                        _DetailRow(
                          label: 'Idioma',
                          value: book.language!,
                        ),
                      if (book.lastOpenedAt != null)
                        _DetailRow(
                          label: 'Última lectura',
                          value: relativeDate(book.lastOpenedAt!),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: palette.outline.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.inkSoft),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: palette.inkSoft,
                  letterSpacing: 0.2,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Progreso',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const Spacer(),
              Text(
                '${(book.progress * 100).round()}%',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: palette.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: book.progress,
              minHeight: 6,
              backgroundColor: palette.outline.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.inkSoft,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelfPickerSheet extends ConsumerStatefulWidget {
  const _ShelfPickerSheet({required this.book});

  final Book book;

  @override
  ConsumerState<_ShelfPickerSheet> createState() => _ShelfPickerSheetState();
}

class _ShelfPickerSheetState extends ConsumerState<_ShelfPickerSheet> {
  final Set<int> _selected = {};
  bool _initialized = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shelves = ref.watch(shelvesProvider).value ?? const <Shelf>[];
    final current = ref.watch(bookShelvesProvider(widget.book.id!));

    if (!_initialized && current.hasValue) {
      _selected
        ..clear()
        ..addAll(current.value!.map((shelf) => shelf.id!));
      _initialized = true;
    }

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Estanterías',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await context.push('/shelves');
                  },
                  child: const Text('Gestionar'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Guarda «${widget.book.title}» en una o varias colecciones.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (shelves.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.collections_bookmark_outlined,
                        size: 34,
                        color: palette.inkSoft,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Todavía no tienes estanterías.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Crea una desde la pestaña Estanterías.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: shelves.map((shelf) {
                    return CheckboxListTile(
                      value: _selected.contains(shelf.id),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selected.add(shelf.id!);
                          } else {
                            _selected.remove(shelf.id);
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: palette.primary,
                      title: Text(shelf.name),
                      subtitle: Text(
                        '${shelf.bookCount} '
                        '${shelf.bookCount == 1 ? 'libro' : 'libros'}',
                      ),
                      secondary: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: shelf.colorValue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected.isEmpty && shelves.isEmpty
                    ? null
                    : _saving
                        ? null
                        : () async {
                            setState(() => _saving = true);
                            await ref
                                .read(shelvesProvider.notifier)
                                .setBookShelves(
                                  widget.book.id!,
                                  _selected.toList(),
                                );
                            if (context.mounted) Navigator.of(context).pop();
                          },
                child: Text(_saving ? 'Guardando…' : 'Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
