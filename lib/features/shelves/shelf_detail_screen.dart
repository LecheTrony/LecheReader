import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/book.dart';
import '../../core/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../library/widgets/book_card.dart';
import 'shelf_editor.dart';
import 'widgets/shelf_cover_art.dart';

class ShelfDetailScreen extends ConsumerWidget {
  const ShelfDetailScreen({super.key, required this.shelfId});

  final int shelfId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final shelves = ref.watch(shelvesProvider);
    final shelf = ref.watch(shelfByIdProvider(shelfId));
    final books = ref.watch(shelfBooksProvider(shelfId));

    if (shelf == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: shelves.isLoading
              ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                )
              : const Text('Esta estantería ya no existe.'),
        ),
      );
    }

    final color = shelf.colorValue;
    final dark = ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
    final foreground = dark ? Colors.white : const Color(0xFF241C16);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(shelf.name),
        actions: [
          IconButton(
            tooltip: 'Editar estantería',
            onPressed: () => showShelfEditor(context, ref, shelf: shelf),
            icon: const Icon(Icons.edit_outlined, size: 21),
          ),
          IconButton(
            tooltip: 'Eliminar estantería',
            onPressed: () async {
              final deleted = await confirmDeleteShelf(context, ref, shelf);
              if (deleted && context.mounted) context.pop();
            },
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 21,
              color: palette.danger,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900
              ? 4
              : constraints.maxWidth >= 650
                  ? 3
                  : 2;
          final items = books.value ?? const <Book>[];

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color, color.withValues(alpha: 0.76)],
                      ),
                    ),
                    child: Row(
                      children: [
                        if (shelf.hasCover)
                          ShelfCoverArt(
                            shelf: shelf,
                            width: 56,
                            height: 72,
                          )
                        else
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: foreground.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.collections_bookmark_rounded,
                              size: 27,
                              color: foreground,
                            ),
                          ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estantería',
                                style: TextStyle(
                                  fontFamily: AppType.ui,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.7,
                                  color: foreground.withValues(alpha: 0.72),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                shelf.bookCount == 1
                                    ? '1 libro guardado'
                                    : '${shelf.bookCount} libros guardados',
                                style: TextStyle(
                                  fontFamily: AppType.display,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: foreground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 14),
                sliver: SliverToBoxAdapter(
                  child: SectionTitle(
                    title: 'Libros',
                    count: items.length,
                  ),
                ),
              ),
              if (books.isLoading && !books.hasValue)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ),
                )
              else if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyShelf(
                    color: color,
                    onBrowse: () => context.go('/'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                  sliver: SliverGrid(
                    gridDelegate: bookGridDelegate(
                      width: constraints.maxWidth,
                      columns: columns,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      childCount: items.length,
                      (context, index) {
                        final book = items[index];
                        return BookCard(
                          key: ValueKey(book.id),
                          book: book,
                          onTap: () async {
                            await context.push('/book/${book.id}');
                            if (context.mounted) {
                              ref.invalidate(shelfBooksProvider(shelfId));
                              ref.invalidate(shelvesProvider);
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({required this.color, required this.onBrowse});

  final Color color;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 10, 32, 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.28)),
            ),
            child: Icon(
              Icons.library_add_outlined,
              size: 36,
              color: color,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Esta estantería está vacía.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Abre un libro desde tu biblioteca y añádelo a esta colección '
            'desde el botón «Añadir a estantería».',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.inkSoft,
                  height: 1.55,
                ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: onBrowse,
            icon: const Icon(Icons.auto_stories_outlined, size: 19),
            label: const Text('Ir a la biblioteca'),
          ),
        ],
      ),
    );
  }
}
