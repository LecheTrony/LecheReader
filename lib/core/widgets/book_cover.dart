import 'dart:io';

import 'package:flutter/material.dart';

import '../models/book.dart';
import '../theme/app_palette.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Portada de un libro: imagen real o una cubierta editorial generada.
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.book,
    this.width,
    this.height,
    this.borderRadius = 14,
    this.showProgress = true,
    this.showShadow = true,
    this.hero = true,
    this.quality = FilterQuality.medium,
  });

  final Book book;
  final double? width;
  final double? height;
  final double borderRadius;
  final bool showProgress;
  final bool showShadow;
  final bool hero;
  final FilterQuality quality;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(borderRadius);
    final cover = ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (book.hasCover)
              Image.file(
                File(book.coverPath!),
                fit: BoxFit.cover,
                filterQuality: quality,
                errorBuilder: (context, error, stack) =>
                    _GeneratedCover(book: book),
              )
            else
              _GeneratedCover(book: book),
            // Lomo sutil para dar volumen.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0, 0.035, 0.07],
                    colors: [
                      Colors.black.withValues(alpha: 0.22),
                      Colors.black.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            if (showProgress && book.isStarted)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.34),
                      ],
                    ),
                  ),
                ),
              ),
            if (showProgress && book.isStarted)
              Positioned(
                left: 6,
                right: 6,
                bottom: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: book.progress,
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.28),
                    valueColor: AlwaysStoppedAnimation(
                      book.isFinished ? palette.gold : Colors.white,
                    ),
                  ),
                ),
              ),
            if (book.isFinished)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: palette.gold,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: Color(0xFF2A1B08),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: palette.shadow.withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: palette.shadow.withValues(alpha: 0.08),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: cover,
    );

    if (!hero) return decorated;
    return Hero(
      tag: 'book-cover-${book.id}',
      child: decorated,
    );
  }
}

class _GeneratedCover extends StatelessWidget {
  const _GeneratedCover({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colors = coverGradientFor(book, palette);
    final foreground = onAccent(colors.first);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _CoverOrnamentPainter(
              color: foreground.withValues(alpha: 0.16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    book.format.label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: AppType.ui,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.2,
                      color: foreground.withValues(alpha: 0.72),
                    ),
                  ),
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    initialsFor(book.title),
                    style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: 54,
                      height: 1,
                      fontWeight: FontWeight.w500,
                      color: foreground,
                      letterSpacing: -1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 26,
                  height: 1.4,
                  color: foreground.withValues(alpha: 0.5),
                ),
                const Spacer(),
                Text(
                  book.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppType.display,
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: foreground.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverOrnamentPainter extends CustomPainter {
  const _CoverOrnamentPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.1),
      size.width * 0.42,
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.1),
      size.width * 0.29,
      paint,
    );
    final path = Path()
      ..moveTo(-size.width * 0.1, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.64,
        size.width * 1.15,
        size.height * 0.84,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CoverOrnamentPainter oldDelegate) =>
      oldDelegate.color != color;
}
