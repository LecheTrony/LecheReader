/// Tipos de bloque que puede contener un capítulo.
enum ReaderBlockType { heading, subheading, paragraph, quote, divider }

class ReaderBlock {
  const ReaderBlock(this.type, this.text);

  final ReaderBlockType type;
  final String text;
}

class ReaderChapter {
  const ReaderChapter({
    required this.title,
    required this.blocks,
    this.showTitle = true,
    this.href,
  });

  final String title;
  final List<ReaderBlock> blocks;
  final bool showTitle;
  final String? href;

  bool get isEmpty => blocks.isEmpty;

  Iterable<ReaderBlock> get textBlocks =>
      blocks.where((block) => block.text.trim().isNotEmpty);

  /// Longitud del texto del capítulo. Se usa para calcular el progreso de
  /// forma estable aunque cambie el tamaño de letra.
  int get characterCount {
    var total = 0;
    for (final block in textBlocks) {
      total += block.text.length + 2;
    }
    return total;
  }
}

class ReaderBook {
  const ReaderBook({
    required this.title,
    required this.author,
    required this.chapters,
  });

  final String title;
  final String author;
  final List<ReaderChapter> chapters;

  int get totalCharacters {
    var total = 0;
    for (final chapter in chapters) {
      total += chapter.characterCount;
    }
    return total;
  }

  bool get isEmpty => chapters.every((chapter) => chapter.isEmpty);
}

class ReaderLoadResult {
  const ReaderLoadResult({
    this.book,
    this.error,
  });

  final ReaderBook? book;
  final String? error;
}
