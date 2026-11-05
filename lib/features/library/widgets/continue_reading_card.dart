import 'package:flutter/material.dart';

import '../../../core/models/book.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/book_cover.dart';
import '../../../core/widgets/common.dart';

class ContinueReadingCard extends StatelessWidget {
  const ContinueReadingCard({
    super.key,
    required this.book,
    required this.onTap,
  });

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final colors = coverGradientFor(book, palette);
    final foreground = onAccent(colors.first);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          height: 174,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.first, colors.last],
            ),
            boxShadow: [
              BoxShadow(
                color: colors.last.withValues(alpha: 0.34),
                blurRadius: 24,
                offset: const Offset(0, 12),
                spreadRadius: -6,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -40,
                top: -60,
                child: _GlowCircle(
                  size: 190,
                  color: foreground.withValues(alpha: 0.08),
                ),
              ),
              Positioned(
                right: 40,
                bottom: -90,
                child: _GlowCircle(
                  size: 150,
                  color: foreground.withValues(alpha: 0.06),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    BookCover(
                      book: book,
                      width: 92,
                      height: 138,
                      borderRadius: 10,
                      hero: false,
                      showProgress: false,
                      showShadow: true,
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Eyebrow(
                            'Continuar leyendo',
                            color: foreground.withValues(alpha: 0.72),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            book.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppType.display,
                              fontSize: 21,
                              height: 1.18,
                              fontWeight: FontWeight.w600,
                              color: foreground,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            book.displayAuthor,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppType.ui,
                              fontSize: 12,
                              color: foreground.withValues(alpha: 0.78),
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: book.progress,
                                    minHeight: 4,
                                    backgroundColor:
                                        foreground.withValues(alpha: 0.22),
                                    valueColor:
                                        AlwaysStoppedAnimation(foreground),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${(book.progress * 100).round()}%',
                                style: TextStyle(
                                  fontFamily: AppType.ui,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: foreground.withValues(alpha: 0.85),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: foreground.withValues(alpha: 0.16),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: foreground.withValues(alpha: 0.22),
                                  ),
                                ),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                  color: foreground,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
