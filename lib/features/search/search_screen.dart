import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/book.dart';
import '../../core/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../library/widgets/book_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  ReadingStatus? _status;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<Book> _results(List<Book> books) {
    final query = normalizeForSearch(_query.trim());
    return books.where((book) {
      if (_status != null && book.status != _status) return false;
      if (query.isEmpty) return true;
      return normalizeForSearch(book.title).contains(query) ||
          normalizeForSearch(book.displayAuthor).contains(query) ||
          normalizeForSearch(book.description).contains(query) ||
          normalizeForSearch(book.publisher ?? '').contains(query);
    }).toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  Future<void> _open(Book book) async {
    _focusNode.unfocus();
    await context.push('/book/${book.id}');
    if (!mounted) return;
    await ref.read(libraryProvider.notifier).softReload();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final books = ref.watch(libraryProvider).value ?? const <Book>[];
    final results = _results(books);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns = autoGridColumns(constraints.maxWidth);
          return SafeArea(
            bottom: false,
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('Encuentra tu próxima lectura'),
                        const SizedBox(height: 5),
                        Text(
                          'Buscar',
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          textInputAction: TextInputAction.search,
                          onChanged: (value) =>
                              setState(() => _query = value),
                          decoration: InputDecoration(
                            hintText: 'Título, autor, editorial…',
                            prefixIcon:
                                const Icon(Icons.search_rounded, size: 21),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Borrar',
                                    onPressed: () {
                                      _controller.clear();
                                      setState(() => _query = '');
                                      _focusNode.requestFocus();
                                    },
                                    icon: const Icon(Icons.close_rounded,
                                        size: 19),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _StatusChip(
                                label: 'Todo',
                                selected: _status == null,
                                onTap: () => setState(() => _status = null),
                              ),
                              const SizedBox(width: 8),
                              _StatusChip(
                                label: 'Leyendo',
                                icon: Icons.auto_stories_outlined,
                                selected: _status == ReadingStatus.reading,
                                onTap: () => setState(
                                  () => _status = _status ==
                                          ReadingStatus.reading
                                      ? null
                                      : ReadingStatus.reading,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatusChip(
                                label: 'Sin empezar',
                                icon: Icons.bookmark_border_rounded,
                                selected: _status == ReadingStatus.unread,
                                onTap: () => setState(
                                  () => _status = _status ==
                                          ReadingStatus.unread
                                      ? null
                                      : ReadingStatus.unread,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatusChip(
                                label: 'Terminados',
                                icon: Icons.check_rounded,
                                selected: _status == ReadingStatus.finished,
                                onTap: () => setState(
                                  () => _status = _status ==
                                          ReadingStatus.finished
                                      ? null
                                      : ReadingStatus.finished,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Text(
                          _query.trim().isEmpty ? 'Toda tu biblioteca' : 'Resultados',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: palette.surfaceAlt,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${results.length}',
                            style:
                                Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: palette.inkSoft,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (books.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptySearch(
                      icon: Icons.auto_stories_outlined,
                      title: 'Tu biblioteca está vacía',
                      message:
                          'Importa tus primeros libros para poder buscarlos aquí.',
                    ),
                  )
                else if (results.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptySearch(
                      icon: Icons.search_off_rounded,
                      title: 'Sin coincidencias',
                      message:
                          'No encontramos libros que coincidan con «${_query.trim()}». '
                          'Prueba con otro título, autor o quita los filtros.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    sliver: SliverGrid(
                      gridDelegate: bookGridDelegate(
                        width: constraints.maxWidth,
                        columns: columns,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        childCount: results.length,
                        (context, index) {
                          final book = results[index];
                          return BookCard(
                            key: ValueKey(book.id),
                            book: book,
                            onTap: () => _open(book),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 15,
              color: selected ? palette.onPrimary : palette.inkSoft,
            ),
      label: Text(label),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: palette.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: palette.outline.withValues(alpha: 0.7),
              ),
            ),
            child: Icon(icon, size: 34, color: palette.inkSoft),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.inkSoft,
                  height: 1.55,
                ),
          ),
        ],
      ),
    );
  }
}
