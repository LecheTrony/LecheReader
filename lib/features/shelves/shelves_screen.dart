import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/shelf.dart';
import '../../core/providers.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/common.dart';
import 'shelf_editor.dart';
import 'widgets/shelf_cover_art.dart';

class ShelvesScreen extends ConsumerWidget {
  const ShelvesScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    await showShelfEditor(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final shelves = ref.watch(shelvesProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Eyebrow('Colecciones a tu medida'),
                          const SizedBox(height: 5),
                          Text(
                            'Estanterías',
                            style: Theme.of(context).textTheme.displayMedium,
                          ),
                        ],
                      ),
                    ),
                    SoftIconButton(
                      icon: Icons.add_rounded,
                      tooltip: 'Nueva estantería',
                      filled: true,
                      onPressed: () => _create(context, ref),
                    ),
                  ],
                ),
              ),
            ),
            if (shelves.isLoading && !shelves.hasValue)
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
            else if (shelves.value?.isEmpty ?? true)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyShelves(
                  onCreate: () => _create(context, ref),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 32),
                sliver: SliverList.separated(
                  itemCount: shelves.value!.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final shelf = shelves.value![index];
                    return _ShelfCard(
                      shelf: shelf,
                      onTap: () => context.push('/shelf/${shelf.id}'),
                      onEdit: () => showShelfEditor(context, ref, shelf: shelf),
                      onDelete: () async {
                        final deleted = await confirmDeleteShelf(
                          context,
                          ref,
                          shelf,
                        );
                        if (deleted && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Estantería «${shelf.name}» eliminada'),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                child: Row(
                  children: [
                    Icon(
                      Icons.tips_and_updates_outlined,
                      size: 17,
                      color: palette.gold,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Crea colecciones por tema, estado de ánimo o autor. '
                        'Un libro puede estar en varias estanterías.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShelfCard extends StatelessWidget {
  const _ShelfCard({
    required this.shelf,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Shelf shelf;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: palette.outline.withValues(alpha: 0.6),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ShelfCoverArt(shelf: shelf),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shelf.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 16,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      shelf.bookCount == 1
                          ? '1 libro'
                          : '${shelf.bookCount} libros',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opciones',
                icon: Icon(
                  Icons.more_horiz_rounded,
                  size: 21,
                  color: palette.inkSoft,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 19),
                        SizedBox(width: 12),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 19,
                          color: palette.danger,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Eliminar',
                          style: TextStyle(color: palette.danger),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: palette.inkSoft.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyShelves extends StatelessWidget {
  const _EmptyShelves({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 30, 32, 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 170,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 16,
                  top: 30,
                  child: Transform.rotate(
                    angle: -0.1,
                    child: _ShelfSlab(
                      color: palette.sage,
                      width: 112,
                      height: 84,
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 18,
                  child: Transform.rotate(
                    angle: 0.08,
                    child: _ShelfSlab(
                      color: palette.gold,
                      width: 104,
                      height: 78,
                    ),
                  ),
                ),
                Positioned(
                  left: 30,
                  bottom: 10,
                  child: Transform.rotate(
                    angle: 0.04,
                    child: _ShelfSlab(
                      color: palette.primary,
                      width: 120,
                      height: 88,
                    ),
                  ),
                ),
                const Positioned(
                  left: 62,
                  bottom: 28,
                  child: Icon(
                    Icons.auto_stories_rounded,
                    size: 38,
                    color: Color(0xFFFFF7ED),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          const Eyebrow('Orden a tu manera'),
          const SizedBox(height: 10),
          Text(
            'Agrupa lo que\nquieres leer.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  height: 1.1,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Las estanterías te ayudan a separar tus lecturas por temporada, '
            'tema o cualquier criterio que se te ocurra.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.inkSoft,
                  height: 1.55,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Crear estantería'),
          ),
        ],
      ),
    );
  }
}

class _ShelfSlab extends StatelessWidget {
  const _ShelfSlab({
    required this.color,
    required this.width,
    required this.height,
  });

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
    );
  }
}
