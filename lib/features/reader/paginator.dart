import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'reader_models.dart';

class PagedBlock {
  const PagedBlock({required this.type, required this.text});

  final ReaderBlockType type;
  final String text;
}

class ReaderPage {
  const ReaderPage({
    required this.chapterIndex,
    required this.chapterTitle,
    required this.blocks,
    required this.startOffset,
    required this.endOffset,
  });

  final int chapterIndex;
  final String chapterTitle;
  final List<PagedBlock> blocks;
  final int startOffset;
  final int endOffset;
}

class BookPagination {
  const BookPagination({
    required this.pages,
    required this.chapterFirstPage,
    required this.chapterStartCharacters,
    required this.totalCharacters,
  });

  final List<ReaderPage> pages;
  final List<int> chapterFirstPage;
  final List<int> chapterStartCharacters;
  final int totalCharacters;

  int get pageCount => pages.length;

  double progressForPage(int pageIndex) {
    if (pages.isEmpty) return 0;
    final index = pageIndex.clamp(0, pages.length - 1);
    final page = pages[index];
    if (totalCharacters == 0) return index / pages.length;
    final global = (chapterStartCharacters[page.chapterIndex] + page.startOffset)
        .clamp(0, totalCharacters);
    return (global / totalCharacters).clamp(0.0, 1.0);
  }

  /// Busca la página que contiene una posición guardada.
  int pageForLocation(int chapterIndex, int offset) {
    if (pages.isEmpty) return 0;
    final first = chapterIndex.clamp(0, chapterFirstPage.length - 1);
    final start = chapterFirstPage[first];
    final end = first + 1 < chapterFirstPage.length
        ? chapterFirstPage[first + 1]
        : pages.length;
    for (var i = start; i < end; i++) {
      final page = pages[i];
      if (page.startOffset <= offset && offset <= page.endOffset) return i;
    }
    return start;
  }
}

class BookPaginator {
  const BookPaginator({
    required this.fontSize,
    required this.lineHeight,
    required this.serif,
    required this.justify,
    required this.textScaler,
  });

  final double fontSize;
  final double lineHeight;
  final bool serif;
  final bool justify;
  final TextScaler textScaler;

  static const titleSpacing = 26.0;
  static const headingSpacing = 18.0;
  static const subheadingSpacing = 12.0;
  static const paragraphSpacing = 11.0;
  static const quoteSpacing = 14.0;
  static const dividerSpacing = 20.0;

  static double spacingAfter(ReaderBlockType type) => switch (type) {
        ReaderBlockType.heading => headingSpacing,
        ReaderBlockType.subheading => subheadingSpacing,
        ReaderBlockType.paragraph => paragraphSpacing,
        ReaderBlockType.quote => quoteSpacing,
        ReaderBlockType.divider => dividerSpacing,
      };

  TextStyle styleFor(ReaderBlockType type, {bool chapterTitle = false}) {
    switch (type) {
      case ReaderBlockType.heading:
        return TextStyle(
          fontFamily: AppType.display,
          fontSize: fontSize * (chapterTitle ? 1.5 : 1.18),
          height: chapterTitle ? 1.2 : 1.3,
          fontWeight: FontWeight.w600,
          letterSpacing: chapterTitle ? -0.4 : -0.1,
        );
      case ReaderBlockType.subheading:
        return TextStyle(
          fontFamily: AppType.display,
          fontSize: fontSize * 1.04,
          height: 1.3,
          fontWeight: FontWeight.w600,
        );
      case ReaderBlockType.paragraph:
        return TextStyle(
          fontFamily: serif ? AppType.reading : AppType.ui,
          fontSize: fontSize,
          height: lineHeight,
          fontWeight: FontWeight.w400,
          letterSpacing: serif ? 0.05 : -0.05,
        );
      case ReaderBlockType.quote:
        return TextStyle(
          fontFamily: serif ? AppType.reading : AppType.ui,
          fontSize: fontSize * 0.98,
          height: lineHeight,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w400,
        );
      case ReaderBlockType.divider:
        return const TextStyle(fontSize: 1, height: 1);
    }
  }

  BookPagination paginate({
    required ReaderBook book,
    required double width,
    required double height,
  }) {
    final pages = <ReaderPage>[];
    final chapterFirstPage = <int>[];
    final chapterStartCharacters = <int>[];
    var runningCharacters = 0;

    for (var chapterIndex = 0;
        chapterIndex < book.chapters.length;
        chapterIndex++) {
      final chapter = book.chapters[chapterIndex];
      chapterFirstPage.add(pages.length);
      chapterStartCharacters.add(runningCharacters);

      final blocks = <ReaderBlock>[];
      if (chapter.showTitle && chapter.title.trim().isNotEmpty) {
        blocks.add(ReaderBlock(ReaderBlockType.heading, chapter.title.trim()));
      }
      blocks.addAll(chapter.blocks);

      // Offset de cada bloque dentro del capítulo, para guardar la posición.
      final blockStarts = <int>[];
      var offset = 0;
      for (final block in blocks) {
        blockStarts.add(offset);
        offset += block.text.length + 2;
      }

      var pageBlocks = <PagedBlock>[];
      var pageStart = -1;
      var pageEnd = 0;
      var usedHeight = 0.0;

      void flushPage() {
        if (pageBlocks.isEmpty) return;
        pages.add(
          ReaderPage(
            chapterIndex: chapterIndex,
            chapterTitle: chapter.title,
            blocks: pageBlocks,
            startOffset: pageStart < 0 ? 0 : pageStart,
            endOffset: pageEnd,
          ),
        );
        pageBlocks = <PagedBlock>[];
        pageStart = -1;
        pageEnd = 0;
        usedHeight = 0;
      }

      void appendChunk(String text, ReaderBlockType type, int start, int end) {
        if (type != ReaderBlockType.divider && text.trim().isEmpty) return;
        pageBlocks.add(PagedBlock(type: type, text: text));
        if (pageStart < 0 || start < pageStart) pageStart = start;
        if (end > pageEnd) pageEnd = end;
      }

      for (var blockIndex = 0;
          blockIndex < blocks.length;
          blockIndex++) {
        final block = blocks[blockIndex];
        final blockStart = blockStarts[blockIndex];
        final type = block.type;
        final isChapterTitle = chapter.showTitle && blockIndex == 0;

        if (type == ReaderBlockType.divider) {
          if (usedHeight + 18 > height && pageBlocks.isNotEmpty) {
            flushPage();
          }
          appendChunk('', type, blockStart, blockStart);
          usedHeight += 18 + dividerSpacing;
          continue;
        }

        var remaining = block.text.trim();
        var consumed = 0;

        while (remaining.isNotEmpty) {
          final style = styleFor(type, chapterTitle: isChapterTitle);
          final painter = _layout(remaining, style, width);
          final available = height - usedHeight;
          final spacing = isChapterTitle ? titleSpacing : spacingAfter(type);

          if (painter.height <= available + 0.5) {
            if (type == ReaderBlockType.heading &&
                !isChapterTitle &&
                pageBlocks.isNotEmpty &&
                available < painter.height + 62) {
              flushPage();
              continue;
            }
            appendChunk(
              remaining,
              type,
              blockStart + consumed,
              blockStart + consumed + remaining.length,
            );
            usedHeight += painter.height + spacing;
            break;
          }

          var fitLines = 0;
          var acc = 0.0;
          final metrics = painter.computeLineMetrics();
          for (final metric in metrics) {
            if (acc + metric.height > available + 0.5) break;
            acc += metric.height;
            fitLines++;
          }

          if (fitLines <= 0) {
            if (pageBlocks.isNotEmpty) {
              flushPage();
              continue;
            }
            // El bloque es más alto que la página: lo mostramos igualmente.
            appendChunk(
              remaining,
              type,
              blockStart + consumed,
              blockStart + consumed + remaining.length,
            );
            usedHeight += painter.height + spacing;
            break;
          }

          var lineTop = 0.0;
          for (var i = 0; i < fitLines; i++) {
            lineTop += metrics[i].height;
          }
          final nextLineHeight = fitLines < metrics.length
              ? metrics[fitLines].height
              : metrics.last.height;
          final probeY = (lineTop + nextLineHeight * 0.5)
              .clamp(0.0, painter.height - 0.5);
          final position = painter.getPositionForOffset(Offset(0, probeY));
          var split = position.offset;
          if (split <= 0) split = _fallbackSplit(remaining);
          if (split <= 0) {
            split = remaining.length;
          }
          if (split > remaining.length) split = remaining.length;

          final chunk = remaining.substring(0, split).trimRight();
          var nextStart = split;
          while (nextStart < remaining.length &&
              _isWhitespace(remaining.codeUnitAt(nextStart))) {
            nextStart++;
          }

          final chunkStart = blockStart + consumed;
          if (chunk.isNotEmpty) {
            appendChunk(
              chunk,
              type,
              chunkStart,
              chunkStart + chunk.length,
            );
          }
          flushPage();

          consumed += nextStart;
          remaining = remaining.substring(nextStart);
          if (nextStart == 0) break;
        }
      }

      flushPage();
      runningCharacters += chapter.characterCount;
    }

    if (pages.isEmpty) {
      pages.add(
        ReaderPage(
          chapterIndex: 0,
          chapterTitle: book.chapters.isEmpty ? book.title : book.chapters.first.title,
          blocks: [
            PagedBlock(
              type: ReaderBlockType.paragraph,
              text: 'Este libro no tiene texto para mostrar.',
            ),
          ],
          startOffset: 0,
          endOffset: 0,
        ),
      );
      if (chapterFirstPage.isEmpty) {
        chapterFirstPage.add(0);
        chapterStartCharacters.add(0);
      }
    }

    return BookPagination(
      pages: pages,
      chapterFirstPage: chapterFirstPage,
      chapterStartCharacters: chapterStartCharacters,
      totalCharacters: runningCharacters == 0 ? 1 : runningCharacters,
    );
  }

  TextPainter _layout(String text, TextStyle style, double width) {
    return TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: justify ? TextAlign.justify : TextAlign.left,
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      textWidthBasis: TextWidthBasis.parent,
    )..layout(maxWidth: width);
  }

  int _fallbackSplit(String text) {
    final target = (text.length * 0.45).floor();
    if (target <= 0) return 0;
    final windowStart = (target - 120).clamp(0, text.length);
    final windowEnd = (target + 120).clamp(0, text.length);
    final window = text.substring(windowStart, windowEnd);
    final breakAt = window.lastIndexOf(RegExp(r'[\s.,;:!?»")]'));
    if (breakAt > 0) return windowStart + breakAt + 1;
    return target;
  }

  bool _isWhitespace(int codeUnit) =>
      codeUnit == 0x20 || codeUnit == 0x0A || codeUnit == 0x09;
}
