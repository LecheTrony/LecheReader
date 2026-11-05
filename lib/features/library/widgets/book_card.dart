import 'package:flutter/material.dart';

import '../../../core/models/book.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/book_cover.dart';

int autoGridColumns(double width) {
  if (width >= 1200) return 5;
  if (width >= 900) return 4;
  if (width >= 650) return 3;
  return 2;
}

SliverGridDelegate bookGridDelegate({
  required double width,
  required int columns,
  double horizontalPadding = 20,
  double crossAxisSpacing = 14,
  double mainAxisSpacing = 24,
}) {
  final available = width - horizontalPadding * 2;
  final itemWidth =
      (available - crossAxisSpacing * (columns - 1)) / columns;
  final itemHeight = itemWidth / (2 / 3) + 60;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    crossAxisSpacing: crossAxisSpacing,
    mainAxisSpacing: mainAxisSpacing,
    childAspectRatio: itemWidth / itemHeight,
  );
}

class BookCard extends StatefulWidget {
  const BookCard({
    super.key,
    required this.book,
    required this.onTap,
    this.onLongPress,
    this.showAuthor = true,
  });

  final Book book;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showAuthor;

  @override
  State<BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<BookCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '${book.title}. ${book.displayAuthor}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onLongPress: widget.onLongPress,
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: BookCover(book: book),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontSize: 13.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
                if (widget.showAuthor) ...[
                  const SizedBox(height: 2),
                  Text(
                    book.displayAuthor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                      color: palette.inkSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
