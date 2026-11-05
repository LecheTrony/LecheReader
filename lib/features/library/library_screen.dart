import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_settings.dart';
import '../../core/models/book.dart';
import '../../core/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../import/import_sheet.dart';
import 'widgets/book_card.dart';
import 'widgets/continue_reading_card.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibraryFilter _filter = const LibraryFilter();

  Future<void> _import() async {
    await runImportFlow(context, ref);
  }

  Future<void> _openBook(Book book) async {
    await context.push('/book/${book.id}');
    if (!mounted) return;
    await ref.read(libraryProvider.notifier).softReload();
  }

  Future<void> _openReader(Book book) async {
    await ref.read(libraryProvider.notifier).markOpened(book.id!);
    if (!mounted) return;
    await context.push('/reader/${book.id}');
    if (!mounted) return;
    await ref.read(libraryProvider.notifier).refreshBook(book);
  }

  Future<void> _toggleFavorite(Book book) async {
    final willFavorite = !book.isFavorite;
    await ref.read(libraryProvider.notifier).toggleFavorite(book);
    if (!mounted) return;
    showAppSnackBar(
      context,
      willFavorite ? 'Añadido a favoritos' : 'Quitado de favoritos',
    );
  }

  List<Book> _visibleBooks(List<Book> books, AppSettings settings) {
    final filtered = books.where((book) {
      if (_filter.favoritesOnly && !book.isFavorite) return false;
      if (_filter.status != null && book.status != _filter.status) {
        return false;
      }
      return true;
    }).toList();

    switch (settings.librarySort) {
      case LibrarySort.recent:
        filtered.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case LibrarySort.title:
        filtered.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
      case LibrarySort.author:
        filtered.sort(
          (a, b) => a.displayAuthor
              .toLowerCase()
              .compareTo(b.displayAuthor.toLowerCase()),
        );
      case LibrarySort.lastOpened:
        filtered.sort(
          (a, b) => (b.lastOpenedAt ?? DateTime(0))
              .compareTo(a.lastOpenedAt ?? DateTime(0)),
        );
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final settings = ref.watch(settingsProvider);
    final library = ref.watch(libraryProvider);
    final continueReading = ref.watch(continueReadingProvider);

    return Scaffold(
      floatingActionButton: library.value?.isNotEmpty == true
          ? Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: FloatingActionButton.extended(
                onPressed: _import,
                backgroundColor: palette.primary,
                foregroundColor: palette.onPrimary,
                elevation: 0,
                highlightElevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                icon: const Icon(Icons.add_rounded, size: 22),
                label: const Text(
                  'Importar',
                  style: TextStyle(
                    fontFamily: AppType.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = settings.libraryColumns > 0
              ? settings.libraryColumns
              : autoGridColumns(constraints.maxWidth);

          return SafeArea(
            bottom: false,
            child: RefreshIndicator(
              edgeOffset: 80,
              color: palette.primary,
              onRefresh: () async {
                await ref.read(libraryProvider.notifier).softReload();
                await ref.read(shelvesProvider.notifier).refreshCounts();
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: _Header(
                        onSearch: () => context.push('/search'),
                        onContinue: continueReading == null
                            ? null
                            : () => _openReader(continueReading),
                      ),
                    ),
                  ),
                  if (library.isLoading && !library.hasValue)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      ),
                    )
                  else if (library.hasError)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ErrorState(
                        onRetry: () =>
                            ref.read(libraryProvider.notifier).reload(),
                      ),
                    )
                  else if (library.value?.isEmpty ?? true)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyLibrary(onImport: _import),
                    )
                  else
                    ..._buildContent(
                      context,
                      constraints,
                      columns,
                      library.value ?? const [],
                      settings,
                      continueReading,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildContent(
    BuildContext context,
    BoxConstraints constraints,
    int columns,
    List<Book> books,
    AppSettings settings,
    Book? continueReading,
  ) {
    final visible = _visibleBooks(books, settings);

    return [
      if (settings.showContinueReading && continueReading != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
          sliver: SliverToBoxAdapter(
            child: ContinueReadingCard(
              book: continueReading,
              onTap: () => _openReader(continueReading),
            ),
          ),
        ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(20, 30, 12, 0),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: SectionTitle(
                  title: 'Biblioteca',
                  count: visible.length,
                ),
              ),
              SoftIconButton(
                icon: settings.librarySort.icon,
                tooltip: 'Ordenar',
                size: 38,
                iconSize: 18,
                onPressed: () => _showSortSheet(context, settings),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.only(top: 14),
        sliver: SliverToBoxAdapter(
          child: _FilterRow(
            filter: _filter,
            onChanged: (filter) => setState(() => _filter = filter),
          ),
        ),
      ),
      if (visible.isEmpty)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                Icon(
                  Icons.filter_alt_off_outlined,
                  size: 36,
                  color: context.palette.inkSoft,
                ),
                const SizedBox(height: 12),
                Text(
                  'No hay libros con este filtro.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.palette.inkSoft,
                      ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      setState(() => _filter = const LibraryFilter()),
                  child: const Text('Quitar filtros'),
                ),
              ],
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 130),
          sliver: SliverGrid(
            gridDelegate: bookGridDelegate(
              width: constraints.maxWidth,
              columns: columns,
            ),
            delegate: SliverChildBuilderDelegate(
              childCount: visible.length,
              (context, index) {
                final book = visible[index];
                return BookCard(
                  key: ValueKey(book.id),
                  book: book,
                  onTap: () => _openBook(book),
                  onLongPress: () => _toggleFavorite(book),
                );
              },
            ),
          ),
        ),
    ];
  }

  Future<void> _showSortSheet(
    BuildContext context,
    AppSettings settings,
  ) async {
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
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 28),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                  child: Text(
                    'Ordenar biblioteca',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                ...LibrarySort.values.map((sort) {
                  final selected = settings.librarySort == sort;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    leading: Icon(
                      sort.icon,
                      size: 20,
                      color: selected ? palette.primary : palette.inkSoft,
                    ),
                    title: Text(
                      sort.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                            color: selected ? palette.primary : palette.ink,
                          ),
                    ),
                    trailing: selected
                        ? Icon(Icons.check_rounded,
                            size: 20, color: palette.primary)
                        : null,
                    onTap: () {
                      ref
                          .read(settingsProvider.notifier)
                          .setLibrarySort(sort);
                      Navigator.of(sheetContext).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onSearch, this.onContinue});

  final VoidCallback onSearch;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(greetingForNow()),
              const SizedBox(height: 5),
              Text(
                'Tu biblioteca',
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ],
          ),
        ),
        SoftIconButton(
          icon: Icons.search_rounded,
          tooltip: 'Buscar',
          onPressed: onSearch,
        ),
        if (onContinue != null) ...[
          const SizedBox(width: 8),
          SoftIconButton(
            icon: Icons.auto_stories_outlined,
            tooltip: 'Seguir leyendo',
            onPressed: onContinue,
          ),
        ],
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.filter, required this.onChanged});

  final LibraryFilter filter;
  final ValueChanged<LibraryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final entries = <({String label, IconData? icon, LibraryFilter filter})>[
      (label: 'Todos', icon: null, filter: const LibraryFilter()),
      (
        label: 'Leyendo',
        icon: Icons.auto_stories_outlined,
        filter: const LibraryFilter(status: ReadingStatus.reading),
      ),
      (
        label: 'Sin empezar',
        icon: Icons.bookmark_border_rounded,
        filter: const LibraryFilter(status: ReadingStatus.unread),
      ),
      (
        label: 'Terminados',
        icon: Icons.check_rounded,
        filter: const LibraryFilter(status: ReadingStatus.finished),
      ),
      (
        label: 'Favoritos',
        icon: Icons.favorite_border_rounded,
        filter: const LibraryFilter(favoritesOnly: true),
      ),
    ];

    bool isSelected(LibraryFilter entry) {
      return entry.status == filter.status &&
          entry.favoritesOnly == filter.favoritesOnly;
    }

    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final selected = isSelected(entry.filter);
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => onChanged(entry.filter),
            avatar: entry.icon == null
                ? null
                : Icon(
                    entry.icon,
                    size: 15,
                    color: selected
                        ? context.palette.onPrimary
                        : context.palette.inkSoft,
                  ),
            label: Text(entry.label),
          );
        },
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onImport});

  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 130),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 190,
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 176,
                  height: 176,
                  decoration: BoxDecoration(
                    color: palette.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: palette.outline.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                Container(
                  width: 126,
                  height: 126,
                  decoration: BoxDecoration(
                    color: palette.primarySoft,
                    shape: BoxShape.circle,
                  ),
                ),
                Icon(
                  Icons.auto_stories_rounded,
                  size: 64,
                  color: palette.primary,
                ),
                Positioned(
                  top: 22,
                  right: 20,
                  child: _Dot(size: 9, color: palette.gold),
                ),
                Positioned(
                  bottom: 34,
                  left: 18,
                  child: _Dot(
                    size: 6,
                    color: palette.sage.withValues(alpha: 0.8),
                  ),
                ),
                Positioned(
                  top: 54,
                  left: 4,
                  child: Transform.rotate(
                    angle: -0.18,
                    child: Icon(
                      Icons.bookmark_rounded,
                      size: 24,
                      color: palette.primary.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Eyebrow('Tu primera estantería'),
          const SizedBox(height: 10),
          Text(
            'Un buen libro\nempieza aquí.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  height: 1.1,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Importa tus PDF, EPUB, cómics o textos y tenlos siempre a mano. '
            'Sin cuentas, sin anuncios: todo se queda en tu dispositivo.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.inkSoft,
                  height: 1.55,
                ),
          ),
          const SizedBox(height: 26),
          FilledButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.add_rounded, size: 21),
            label: const Text('Importar libros'),
          ),
          const SizedBox(height: 18),
          Text(
            'PDF · EPUB · TXT · CBZ · FB2 · HTML',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.1,
                  color: palette.inkSoft.withValues(alpha: 0.8),
                ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 42,
              color: context.palette.inkSoft,
            ),
            const SizedBox(height: 14),
            Text(
              'No se pudo abrir la biblioteca.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
