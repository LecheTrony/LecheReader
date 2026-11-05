import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../../core/models/book.dart';
import '../../core/utils/formatters.dart';
import 'reader_models.dart';

/// Extrae el contenido legible de cualquiera de los formatos soportados.
class BookContentParser {
  const BookContentParser();

  Future<ReaderBook> parse({
    required String filePath,
    required BookFormat format,
    required String fallbackTitle,
    String author = '',
  }) async {
    try {
      final book = await Isolate.run(
        () => _parseSync(
          filePath: filePath,
          format: format,
          fallbackTitle: fallbackTitle,
          author: author,
        ),
      );
      if (book.isEmpty) {
        return ReaderBook(
          title: fallbackTitle,
          author: author,
          chapters: [
            ReaderChapter(
              title: fallbackTitle,
              showTitle: false,
              blocks: const [
                ReaderBlock(
                  ReaderBlockType.paragraph,
                  'No se ha encontrado texto legible en este archivo.',
                ),
              ],
            ),
          ],
        );
      }
      return book;
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException(
        'No pudimos abrir este archivo. Es posible que esté dañado.',
        error.toString(),
      );
    }
  }
}

ReaderBook _parseSync({
  required String filePath,
  required BookFormat format,
  required String fallbackTitle,
  required String author,
}) {
  return switch (format) {
    BookFormat.epub => _parseEpub(filePath, fallbackTitle, author),
    BookFormat.txt => _parseTxt(filePath, fallbackTitle, author),
    BookFormat.fb2 => _parseFb2(filePath, fallbackTitle, author),
    BookFormat.html => _parseHtml(filePath, fallbackTitle, author),
    _ => throw const FormatException('Formato no válido para lectura de texto'),
  };
}

// -----------------------------------------------------------------------------
// EPUB
// -----------------------------------------------------------------------------

ReaderBook _parseEpub(String path, String fallbackTitle, String author) {
  final archive = ZipDecoder().decodeBytes(File(path).readAsBytesSync());
  final files = <String, ArchiveFile>{};
  for (final file in archive.files) {
    if (file.isFile) files[_normalize(file.name)] = file;
  }

  final containerFile = files['META-INF/container.xml'];
  if (containerFile == null) {
    throw const FormatException('El EPUB no contiene container.xml');
  }
  final container = XmlDocument.parse(_decodeBytes(containerFile.content));
  final rootFile = container.descendants
      .whereType<XmlElement>()
      .firstWhereOrNull((element) => element.name.local == 'rootfile');
  final opfPath = rootFile?.getAttribute('full-path');
  if (opfPath == null) throw const FormatException('El EPUB no tiene OPF');

  final opfFile = files[_normalize(opfPath)];
  if (opfFile == null) throw const FormatException('El EPUB no tiene OPF');
  final opf = XmlDocument.parse(_decodeBytes(opfFile.content));
  final opfDir = p.posix.dirname(_normalize(opfPath));
  final chapters = <ReaderChapter>[];
  final seenHrefs = <String>{};

  final manifest = <String, _ManifestItem>{};
  for (final element in opf.descendants.whereType<XmlElement>()) {
    if (element.name.local == 'item') {
      final id = element.getAttribute('id');
      final href = element.getAttribute('href');
      if (id == null || href == null) continue;
      manifest[id] = _ManifestItem(
        href: href,
        mediaType: element.getAttribute('media-type') ?? '',
        properties: element.getAttribute('properties') ?? '',
      );
    }
  }

  for (final element in opf.descendants.whereType<XmlElement>()) {
    if (element.name.local != 'itemref') continue;
    final idref = element.getAttribute('idref');
    final item = manifest[idref];
    if (item == null) continue;
    if (item.properties.split(' ').contains('nav')) continue;
    final resolved = _resolve(opfDir, item.href);
    if (!seenHrefs.add(resolved)) continue;
    final file = files[resolved];
    if (file == null) continue;
    final isHtml = item.mediaType.contains('html') ||
        resolved.endsWith('.xhtml') ||
        resolved.endsWith('.html') ||
        resolved.endsWith('.htm');
    if (!isHtml) continue;

    final chapter = _epubChapter(_decodeBytes(file.content), resolved);
    if (chapter.isEmpty) continue;
    chapters.add(chapter);
  }

  if (chapters.isEmpty) {
    // Algunos EPUB antiguos no declaran bien el spine; recorremos los XHTML.
    for (final entry in files.entries) {
      if (!entry.key.endsWith('.xhtml') && !entry.key.endsWith('.html')) {
        continue;
      }
      final chapter = _epubChapter(_decodeBytes(entry.value.content), entry.key);
      if (!chapter.isEmpty) chapters.add(chapter);
    }
  }
  if (chapters.isEmpty) {
    throw const FormatException('Este EPUB no contiene capítulos legibles');
  }

  String? dc(String name) {
    for (final element in opf.descendants.whereType<XmlElement>()) {
      if (element.name.local == name) {
        final text = element.innerText.trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  return ReaderBook(
    title: dc('title') ?? fallbackTitle,
    author: dc('creator')?.trim().isNotEmpty == true
        ? dc('creator')!.trim()
        : author,
    chapters: chapters,
  );
}

ReaderChapter _epubChapter(String html, String href) {
  final document = html_parser.parse(html);
  final title = _firstHeadingText(document);
  final blocks = _blocksFromHtml(document);
  final cleaned = _stripLeadingTitle(blocks, title);
  return ReaderChapter(
    title: title ?? '',
    blocks: cleaned,
    showTitle: title != null && title.trim().isNotEmpty,
    href: href,
  );
}

String? _firstHeadingText(dom.Document document) {
  for (final tag in const ['h1', 'h2', 'h3', 'title']) {
    final element = document.querySelector(tag);
    final text = _cleanText(element?.text);
    if (text.isNotEmpty && text.length <= 140) return text;
  }
  return null;
}

List<ReaderBlock> _blocksFromHtml(dom.Document document) {
  final blocks = <ReaderBlock>[];
  final body = document.body;
  if (body == null) return blocks;

  void addText(ReaderBlockType type, String text) {
    final cleaned = _cleanInline(text);
    if (cleaned.isEmpty) return;
    blocks.add(ReaderBlock(type, cleaned));
  }

  void walk(dom.Element element) {
    for (final child in element.children) {
      final tag = child.localName;
      switch (tag) {
        case 'h1':
        case 'h2':
        case 'h3':
          addText(ReaderBlockType.heading, child.text);
        case 'h4':
        case 'h5':
        case 'h6':
          addText(ReaderBlockType.subheading, child.text);
        case 'p':
          addText(ReaderBlockType.paragraph, child.text);
        case 'blockquote':
          addText(ReaderBlockType.quote, child.text);
        case 'pre':
          addText(ReaderBlockType.paragraph, child.text);
        case 'li':
          addText(ReaderBlockType.paragraph, '· ${child.text}');
        case 'ul':
        case 'ol':
        case 'div':
        case 'section':
        case 'article':
        case 'main':
        case 'body':
        case 'header':
        case 'footer':
        case 'figure':
        case 'table':
          walk(child);
      }
    }
  }

  walk(body);

  if (blocks.isEmpty) {
    final text = _cleanInline(body.text);
    if (text.isNotEmpty) {
      blocks.add(ReaderBlock(ReaderBlockType.paragraph, text));
    }
  }
  return blocks;
}

List<ReaderBlock> _stripLeadingTitle(
  List<ReaderBlock> blocks,
  String? title,
) {
  if (title == null || blocks.isEmpty) return blocks;
  final first = blocks.first;
  if (first.type == ReaderBlockType.heading &&
      first.text.trim().toLowerCase() == title.trim().toLowerCase()) {
    return blocks.skip(1).toList(growable: false);
  }
  return blocks;
}

// -----------------------------------------------------------------------------
// FB2
// -----------------------------------------------------------------------------

ReaderBook _parseFb2(String path, String fallbackTitle, String author) {
  final document = XmlDocument.parse(
    _decodeBytes(File(path).readAsBytesSync()),
  );

  String? textOf(String name) {
    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local == name) {
        final text = _cleanInline(element.innerText);
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  final title = textOf('book-title') ?? fallbackTitle;
  final first = textOf('first-name') ?? '';
  final last = textOf('last-name') ?? '';
  final parsedAuthor = '$first $last'.trim();

  final body = document.descendants
      .whereType<XmlElement>()
      .firstWhereOrNull((element) => element.name.local == 'body');
  if (body == null) {
    throw const FormatException('El archivo FB2 no tiene cuerpo');
  }

  final chapters = <ReaderChapter>[];
  final topSections = body.children
      .whereType<XmlElement>()
      .where((element) => element.name.local == 'section')
      .toList();

  if (topSections.isEmpty) {
    final blocks = _fb2Blocks(body);
    return ReaderBook(
      title: title,
      author: parsedAuthor.isNotEmpty ? parsedAuthor : author,
      chapters: [
        ReaderChapter(
          title: title,
          blocks: blocks,
          showTitle: false,
        ),
      ],
    );
  }

  for (final section in topSections) {
    final sectionTitle = _fb2SectionTitle(section);
    final blocks = _fb2Blocks(section, includeOwnTitle: false);
    chapters.add(
      ReaderChapter(
        title: sectionTitle ?? '',
        blocks: blocks,
        showTitle: sectionTitle != null && sectionTitle.isNotEmpty,
      ),
    );
  }

  return ReaderBook(
    title: title,
    author: parsedAuthor.isNotEmpty ? parsedAuthor : author,
    chapters: chapters,
  );
}

String? _fb2SectionTitle(XmlElement section) {
  final titleElement = section.children
      .whereType<XmlElement>()
      .firstWhereOrNull((element) => element.name.local == 'title');
  if (titleElement == null) return null;
  final parts = titleElement.descendants
      .whereType<XmlElement>()
      .where((element) => element.name.local == 'p')
      .map((element) => _cleanInline(element.innerText))
      .where((text) => text.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    final text = _cleanInline(titleElement.innerText);
    return text.isEmpty ? null : text;
  }
  return parts.join(' · ');
}

List<ReaderBlock> _fb2Blocks(XmlElement element, {bool includeOwnTitle = true}) {
  final blocks = <ReaderBlock>[];

  void walk(XmlElement node, bool isRoot) {
    for (final child in node.children.whereType<XmlElement>()) {
      switch (child.name.local) {
        case 'title':
          if (!isRoot || includeOwnTitle) {
            final text = _cleanInline(child.innerText);
            if (text.isNotEmpty) {
              blocks.add(ReaderBlock(ReaderBlockType.heading, text));
            }
          }
        case 'subtitle':
          final text = _cleanInline(child.innerText);
          if (text.isNotEmpty) {
            blocks.add(ReaderBlock(ReaderBlockType.subheading, text));
          }
        case 'p':
          final text = _cleanInline(child.innerText);
          if (text.isNotEmpty) {
            blocks.add(ReaderBlock(ReaderBlockType.paragraph, text));
          }
        case 'v':
          final text = _cleanInline(child.innerText);
          if (text.isNotEmpty) {
            blocks.add(ReaderBlock(ReaderBlockType.paragraph, text));
          }
        case 'cite':
        case 'epigraph':
        case 'annotation':
          final text = _cleanInline(child.innerText);
          if (text.isNotEmpty) {
            blocks.add(ReaderBlock(ReaderBlockType.quote, text));
          }
        case 'poem':
        case 'stanza':
        case 'section':
          walk(child, false);
      }
    }
  }

  walk(element, true);
  return blocks;
}

// -----------------------------------------------------------------------------
// TXT
// -----------------------------------------------------------------------------

final _chapterHeading = RegExp(
  r'^(cap[ií]tulo|chapter|parte|part|libro|book|acto|escena|pr[oó]logo|prologue|ep[ií]logo|epilogue|introducci[oó]n|introduction)\b',
  caseSensitive: false,
);

ReaderBook _parseTxt(String path, String fallbackTitle, String author) {
  var text = _decodeBytes(File(path).readAsBytesSync());
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (text.trim().isEmpty) {
    throw const FormatException('El archivo de texto está vacío');
  }

  final lines = text.split('\n');
  final chapters = <ReaderChapter>[];
  var currentTitle = fallbackTitle;
  var currentShowTitle = false;
  var blocks = <ReaderBlock>[];
  final paragraph = StringBuffer();

  void flushParagraph() {
    final value = _cleanInline(paragraph.toString());
    paragraph.clear();
    if (value.isEmpty) return;
    blocks.add(ReaderBlock(ReaderBlockType.paragraph, value));
  }

  void flushChapter() {
    flushParagraph();
    if (blocks.isEmpty) return;
    chapters.add(
      ReaderChapter(
        title: currentTitle,
        blocks: blocks,
        showTitle: currentShowTitle,
      ),
    );
    blocks = <ReaderBlock>[];
  }

  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      flushParagraph();
      continue;
    }
    if (_looksLikeHeading(line)) {
      flushChapter();
      currentTitle = line;
      currentShowTitle = true;
      continue;
    }
    if (paragraph.isNotEmpty) paragraph.write(' ');
    paragraph.write(line);
  }
  flushChapter();

  if (chapters.isEmpty) {
    chapters.add(
      ReaderChapter(
        title: fallbackTitle,
        showTitle: false,
        blocks: [
          ReaderBlock(ReaderBlockType.paragraph, _cleanInline(text)),
        ],
      ),
    );
  }

  return ReaderBook(
    title: fallbackTitle,
    author: author,
    chapters: chapters,
  );
}

bool _looksLikeHeading(String line) {
  if (line.length > 90) return false;
  if (_chapterHeading.hasMatch(line)) return true;
  // Líneas cortas en mayúsculas que parecen títulos.
  final letters = line.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÜÑáéíóúüñ]'), '');
  if (letters.length < 4 || line.length > 60) return false;
  final isUpper = letters == letters.toUpperCase() &&
      letters != letters.toLowerCase();
  return isUpper && line.split(RegExp(r'\s+')).length <= 10;
}

// -----------------------------------------------------------------------------
// HTML
// -----------------------------------------------------------------------------

ReaderBook _parseHtml(String path, String fallbackTitle, String author) {
  final document = html_parser.parse(
    _decodeBytes(File(path).readAsBytesSync()),
  );
  final title = _cleanInline(document.querySelector('title')?.text);
  final metaAuthor = document
      .querySelector('meta[name="author"]')
      ?.attributes['content'];
  final body = document.body;
  if (body == null) throw const FormatException('El HTML no tiene cuerpo');

  final chapters = <ReaderChapter>[];
  var currentTitle = title.isEmpty ? fallbackTitle : title;
  var blocks = <ReaderBlock>[];
  var currentShowTitle = false;

  void flush() {
    if (blocks.isEmpty) return;
    chapters.add(
      ReaderChapter(
        title: currentTitle,
        blocks: blocks,
        showTitle: currentShowTitle,
      ),
    );
    blocks = <ReaderBlock>[];
  }

  void add(ReaderBlockType type, String text) {
    final cleaned = _cleanInline(text);
    if (cleaned.isEmpty) return;
    blocks.add(ReaderBlock(type, cleaned));
  }

  void walk(dom.Element element) {
    for (final child in element.children) {
      final tag = child.localName;
      switch (tag) {
        case 'h1':
        case 'h2':
          final heading = _cleanInline(child.text);
          if (heading.isNotEmpty) {
            flush();
            currentTitle = heading;
            currentShowTitle = true;
          }
        case 'h3':
        case 'h4':
        case 'h5':
        case 'h6':
          add(ReaderBlockType.subheading, child.text);
        case 'p':
          add(ReaderBlockType.paragraph, child.text);
        case 'blockquote':
          add(ReaderBlockType.quote, child.text);
        case 'li':
          add(ReaderBlockType.paragraph, '· ${child.text}');
        case 'pre':
          add(ReaderBlockType.paragraph, child.text);
        case 'ul':
        case 'ol':
        case 'div':
        case 'section':
        case 'article':
        case 'main':
        case 'header':
        case 'footer':
        case 'figure':
        case 'table':
        case 'body':
          walk(child);
      }
    }
  }

  walk(body);
  flush();

  if (chapters.isEmpty) {
    chapters.add(
      ReaderChapter(
        title: currentTitle,
        showTitle: false,
        blocks: [
          ReaderBlock(ReaderBlockType.paragraph, _cleanInline(body.text)),
        ],
      ),
    );
  }

  return ReaderBook(
    title: title.isEmpty ? fallbackTitle : title,
    author: (metaAuthor == null || metaAuthor.trim().isEmpty)
        ? author
        : metaAuthor.trim(),
    chapters: chapters,
  );
}

// -----------------------------------------------------------------------------
// Utilidades
// -----------------------------------------------------------------------------

String _normalize(String path) =>
    p.posix.normalize(path.replaceAll('\\', '/'));

String _resolve(String baseDir, String href) {
  final clean = Uri.decodeComponent(href.split('#').first);
  return _normalize(p.posix.join(baseDir, clean));
}

String _decodeBytes(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes, allowInvalid: true);
  }
}

String _cleanText(String? value) {
  if (value == null) return '';
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _cleanInline(String? value) {
  if (value == null) return '';
  var text = value.replaceAll('\u00AD', '');
  text = text.replaceAll(RegExp(r'[ \t\f\v]+'), ' ');
  text = text.replaceAll(RegExp(r' *\n *'), '\n');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}

class _ManifestItem {
  const _ManifestItem({
    required this.href,
    required this.mediaType,
    required this.properties,
  });

  final String href;
  final String mediaType;
  final String properties;
}

/// Utilidad para partir títulos muy largos en la portada del lector.
String shortChapterTitle(String title, {int max = 90}) {
  if (title.length <= max) return title;
  return '${title.substring(0, max).trimRight()}…';
}

/// Texto de muestra para la pantalla de carga.
String readerFallbackTitle(String path) => titleFromFileName(path);

/// Cuenta de palabras aproximada de un libro.
int estimateWordCount(ReaderBook book) {
  var count = 0;
  for (final chapter in book.chapters) {
    for (final block in chapter.blocks) {
      count += block.text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    }
  }
  return count;
}

/// Tiempo de lectura aproximado a 230 palabras por minuto.
Duration estimateReadingTime(ReaderBook book) {
  final minutes = math.max(1, estimateWordCount(book) ~/ 230);
  return Duration(minutes: minutes);
}
