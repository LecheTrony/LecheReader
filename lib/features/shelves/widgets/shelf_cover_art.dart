import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/models/shelf.dart';

/// Miniatura de portada de una colección. Si la estantería todavía no tiene
/// imagen, dibuja una cubierta generada con su color de acento.
class ShelfCoverArt extends StatelessWidget {
  const ShelfCoverArt({
    super.key,
    required this.shelf,
    this.width = 58,
    this.height = 72,
    this.borderRadius = 14,
    this.showShadow = true,
  });

  final Shelf shelf;
  final double width;
  final double height;
  final double borderRadius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final color = shelf.colorValue;
    final radius = BorderRadius.circular(borderRadius);

    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.72)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.collections_bookmark_rounded,
          size: height * 0.35,
          color: onAccentColor(color).withValues(alpha: 0.9),
        ),
      ),
    );

    final cover = ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (shelf.hasCover)
              Image.file(
                File(shelf.coverPath!),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stack) => fallback,
              )
            else
              fallback,
            // Lomo sutil, como en las portadas de los libros.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0, 0.05, 0.1],
                    colors: [
                      Colors.black.withValues(alpha: 0.22),
                      Colors.black.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                  spreadRadius: -3,
                ),
              ]
            : null,
      ),
      child: cover,
    );
  }
}

/// Blanco o tinta según el brillo del color de fondo.
Color onAccentColor(Color color) {
  final dark = ThemeData.estimateBrightnessForColor(color) == Brightness.dark;
  return dark ? Colors.white : const Color(0xFF241C16);
}
