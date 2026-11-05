import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/shelf.dart';
import '../../core/providers.dart';
import '../../core/theme/app_palette.dart';
import 'shelf_cover_store.dart';

const shelfColors = <Color>[
  Color(0xFFB4552D), // terracota
  Color(0xFF6C7A5B), // salvia
  Color(0xFFC99A3F), // oro
  Color(0xFF4E6070), // azul pizarra
  Color(0xFF7A4E6B), // ciruela
  Color(0xFF8A6A3B), // cuero
];

const shelfColorNames = <String>[
  'Terracota',
  'Salvia',
  'Oro',
  'Azul pizarra',
  'Ciruela',
  'Cuero',
];

/// Abre un diálogo para crear o editar una estantería.
Future<bool> showShelfEditor(
  BuildContext context,
  WidgetRef ref, {
  Shelf? shelf,
}) async {
  final nameController = TextEditingController(text: shelf?.name ?? '');
  var selectedColor = shelf == null
      ? shelfColors.first
      : Color(shelf.color);
  String? selectedCoverPath = shelf?.coverPath;
  var coverChanged = false;

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final palette = context.palette;
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickCover() async {
            final files = await FilePicker.pickFiles(type: FileType.image);
            final path = files.isEmpty ? null : files.first.path;
            if (path == null) return;
            setDialogState(() {
              selectedCoverPath = path;
              coverChanged = true;
            });
          }

          return AlertDialog(
            scrollable: true,
            title: Text(
              shelf == null ? 'Nueva estantería' : 'Editar estantería',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _ShelfCoverPreview(
                      path: selectedCoverPath,
                      color: selectedColor,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Portada de la colección',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: pickCover,
                            icon: const Icon(
                              Icons.image_outlined,
                              size: 18,
                            ),
                            label: Text(
                              selectedCoverPath == null
                                  ? 'Elegir imagen'
                                  : 'Cambiar imagen',
                            ),
                          ),
                          if (selectedCoverPath != null)
                            TextButton(
                              onPressed: () {
                                setDialogState(() {
                                  selectedCoverPath = null;
                                  coverChanged = true;
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: palette.inkSoft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                minimumSize: const Size(0, 32),
                              ),
                              child: const Text('Quitar portada'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (nameController.text.trim().isNotEmpty) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Lecturas de invierno',
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Color',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(shelfColors.length, (index) {
                    final color = shelfColors[index];
                    final selected =
                        color.toARGB32() == selectedColor.toARGB32();
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: 'Color ${shelfColorNames[index]}',
                      child: GestureDetector(
                        onTap: () =>
                            setDialogState(() => selectedColor = color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  selected ? palette.ink : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 17,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  if (nameController.text.trim().isEmpty) return;
                  Navigator.of(dialogContext).pop(true);
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                ),
                child: Text(shelf == null ? 'Crear' : 'Guardar'),
              ),
            ],
          );
        },
      );
    },
  );

  if (saved == true && context.mounted) {
    final name = nameController.text.trim();
    final notifier = ref.read(shelvesProvider.notifier);
    final previousCover = shelf?.coverPath;
    Shelf? target = shelf;

    if (target == null) {
      target = await notifier.create(name, selectedColor);
    } else {
      if (target.name != name) await notifier.rename(target, name);
      if (target.colorValue.toARGB32() != selectedColor.toARGB32()) {
        await notifier.setColor(target, selectedColor);
      }
    }

    if (coverChanged) {
      final coverPath = selectedCoverPath;
      if (coverPath == null) {
        await notifier.setCover(target, null);
        await ShelfCoverStore.delete(previousCover);
      } else if (coverPath != previousCover) {
        final stored = await ShelfCoverStore.import(coverPath);
        if (stored != null) {
          await notifier.setCover(target, stored);
          await ShelfCoverStore.delete(previousCover);
        }
      }
    }
  }

  nameController.dispose();
  return saved == true;
}

/// Vista previa de la portada elegida; si no hay imagen usa el color de la
/// estantería para mantener la identidad visual.
class _ShelfCoverPreview extends StatelessWidget {
  const _ShelfCoverPreview({required this.path, required this.color});

  final String? path;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.72)],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.collections_bookmark_rounded,
          size: 28,
          color: Colors.white,
        ),
      ),
    );

    return Container(
      width: 68,
      height: 88,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(0, 5),
            spreadRadius: -3,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: path == null
            ? fallback
            : Image.file(
                File(path!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => fallback,
              ),
      ),
    );
  }
}

/// Confirma y elimina una estantería.
Future<bool> confirmDeleteShelf(
  BuildContext context,
  WidgetRef ref,
  Shelf shelf,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final palette = context.palette;
      return AlertDialog(
        title: const Text('Eliminar estantería'),
        content: Text(
          '¿Seguro que quieres eliminar «${shelf.name}»?\n\n'
          'Los libros seguirán en tu biblioteca; solo se borra esta colección.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: palette.danger),
            child: const Text('Eliminar'),
          ),
        ],
      );
    },
  );

  if (confirmed == true) {
    await ref.read(shelvesProvider.notifier).delete(shelf);
    return true;
  }
  return false;
}
