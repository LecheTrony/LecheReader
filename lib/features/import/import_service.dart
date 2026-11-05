import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:xml/xml.dart';

import '../../core/data/app_database.dart';
import '../../core/models/book.dart';
import '../../core/providers.dart';
import '../../core/utils/formatters.dart';

final importServiceProvider = Provider<ImportService>((ref) {
  return ImportService(ref.read(appDatabaseProvider));
});

class ImportProgress {
  const ImportProgress({
    required this.current,
    required this.total,
    required this.fileName,
    this.done = false,
  });

  final int current;
  final int total;
  final String fileName;
  final bool done;

  double get fraction => total == 0 ? 0 : current / total;
}

class ImportSummary {
  ImportSummary({
    required this.imported,
    required this.duplicates,
    required this.failed,
    List<String>? errors,
  }) : errors = errors ?? const [];

  final List<Book> imported;
  final List<String> duplicates;
  final int failed;
  final List<String> errors;
}

class ImportService {
  ImportService(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  Future<ImportSummary> pickAndImport({
    void Function(ImportProgress progress)? onProgress,
  }) async {
    // En Android, el selector de SAF filtra por MIME y los formatos sin MIME
    // registrado (CBZ, FB2...) quedarían deshabilitados. Pedimos todos los
    // archivos y validamos la extensión después.
    final files = await FilePicker.pickFiles(
      type: Platform.isAndroid ? FileType.any : FileType.custom,
      allowedExtensions:
          Platform.isAndroid ? null : BookFormatX.supportedExtensions,
    );
    if (files.isEmpty) {
      return ImportSummary(imported: const [], duplicates: const [], failed: 0);
    }
    final paths = files
        .map((file) => file.path)
        .whereType<String>()
        .toList(growable: false);
    return importPaths(paths, onProgress: onProgress);
  }

  Future<ImportSummary> importPaths(
    List<String> paths, {
    void Function(ImportProgress progress)? onProgress,
  }) async {
    final imported = <Book>[];
    final duplicates = <String>[];
    final errors = <String>[];
    var failed = 0;

    final support = await getApplicationSupportDirectory();
    final booksDir = Directory(p.join(support.path, 'books'));
    final coversDir = Directory(p.join(support.path, 'covers'));
    await booksDir.create(recursive: true);
    await coversDir.create(recursive: true);

    for (var i = 0; i < paths.length; i++) {
      final sourcePath = paths[i];
      final source = File(sourcePath);
      final name = p.basename(sourcePath);
      onProgress?.call(
        ImportProgress(current: i, total: paths.length, fileName: name),
      );

      final format = BookFormatX.fromExtension(p.extension(sourcePath));
      if (format == null) {
        failed++;
        errors.add('$name: formato no compatible');
        continue;
      }

      try {
        final hash = await _hashFile(sourcePath);
        final existing = await _db.findBookByHash(hash);
        if (existing != null) {
          duplicates.add(name);
          continue;
        }

        final id = _uuid.v4();
        final destination = p.join(
          booksDir.path,
          '$id.${p.extension(sourcePath).replaceAll('.', '').toLowerCase()}',
        );
        await source.copy(destination);

        ParsedMetadata metadata;
        Uint8List? coverBytes;
        int? pageCount;
        try {
          final parsed = await _parseFile(destination, format);
          metadata = parsed.metadata;
          coverBytes = parsed.coverBytes;
          pageCount = parsed.pageCount;
        } catch (error) {
          await _silentDelete(destination);
          rethrow;
        }

        String? coverPath;
        int? accentColor;
        if (coverBytes != null && coverBytes.isNotEmpty) {
          final cover = await _writeCover(
            coverBytes,
            p.join(coversDir.path, '$id.jpg'),
          );
          coverPath = cover.path;
          accentColor = cover.accent;
        }

        final title = metadata.title?.trim();
        final author = metadata.author?.trim();
        final book = Book(
          title: (title == null || title.isEmpty)
              ? titleFromFileName(name)
              : title,
          author: author ?? '',
          description: metadata.description?.trim() ?? '',
          filePath: destination,
          coverPath: coverPath,
          format: format,
          fileSize: await File(destination).length(),
          pageCount: pageCount,
          addedAt: DateTime.now(),
          language: metadata.language,
          publisher: metadata.publisher,
          publishedDate: metadata.publishedDate,
          hash: hash,
          accentColor: accentColor,
        );

        final insertedId = await _db.insertBook(book);
        if (insertedId == 0) {
          duplicates.add(name);
          await _silentDelete(destination);
          if (coverPath != null) await _silentDelete(coverPath);
          continue;
        }
        imported.add(book.copyWith(id: insertedId));
      } catch (error) {
        failed++;
        errors.add('$name: ${_friendlyError(error)}');
      }
    }

    onProgress?.call(
      ImportProgress(
        current: paths.length,
        total: paths.length,
        fileName: '',
        done: true,
      ),
    );

    return ImportSummary(
      imported: imported,
      duplicates: duplicates,
      failed: failed,
      errors: errors,
    );
  }

  Future<ParsedFile> _parseFile(String path, BookFormat format) {
    // Los cómics RAR/CBR todavía no se pueden descomprimir en la app. Los
    // importamos con metadatos básicos para que el lector explique cómo
    // convertirlos a CBZ.
    final extension = p.extension(path).toLowerCase();
    if (extension == '.cbr' || extension == '.rar') {
      return Future.value(
        const ParsedFile(metadata: ParsedMetadata()),
      );
    }

    return switch (format) {
      BookFormat.pdf => _parsePdf(path),
      BookFormat.epub => _parseEpub(path),
      BookFormat.cbz => _parseCbz(path),
      BookFormat.fb2 => _parseFb2(path),
      BookFormat.txt => _parseTxt(path),
      BookFormat.html => _parseHtml(path),
    };
  }

  Future<ParsedFile> _parsePdf(String path) async {
    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(path);
      return ParsedFile(
        metadata: const ParsedMetadata(),
        pageCount: document.pages.length,
        coverBytes: await _renderPdfCover(document),
      );
    } finally {
      await document?.dispose();
    }
  }

  /// Renderiza la primera página del PDF como portada.
  ///
  /// En pdfrx `width` y `height` son el tamaño del lienzo final, mientras que
  /// `fullWidth` y `fullHeight` son el tamaño al que se escala la página. Si
  /// solo se cambian los dos primeros, el PDF queda dibujado en la esquina
  /// superior izquierda y el resto del lienzo aparece en blanco.
  Future<Uint8List?> _renderPdfCover(PdfDocument document) async {
    if (document.pages.isEmpty) return null;

    final page = document.pages.first;
    const targetWidth = 900;
    final targetHeight =
        (page.height / page.width * targetWidth).round().clamp(1, 1400);
    final rendered = await page.render(
      width: targetWidth,
      height: targetHeight,
      fullWidth: targetWidth.toDouble(),
      fullHeight: targetHeight.toDouble(),
    );
    if (rendered == null) return null;

    try {
      final image = img.Image.fromBytes(
        width: rendered.width,
        height: rendered.height,
        bytes: Uint8List.fromList(rendered.pixels).buffer,
        numChannels: 4,
        order: img.ChannelOrder.bgra,
      );
      return Uint8List.fromList(img.encodeJpg(image, quality: 88));
    } finally {
      rendered.dispose();
    }
  }

  /// Vuelve a generar la portada de un PDF ya importado. Se usa para reparar
  /// portadas creadas por versiones anteriores con el renderizado incorrecto.
  Future<Book?> refreshPdfCover(Book book) async {
    if (book.format != BookFormat.pdf) return null;
    if (!await File(book.filePath).exists()) return null;

    PdfDocument? document;
    try {
      document = await PdfDocument.openFile(book.filePath);
      final coverBytes = await _renderPdfCover(document);
      if (coverBytes == null) return null;

      final support = await getApplicationSupportDirectory();
      final coversDir = Directory(p.join(support.path, 'covers'));
      await coversDir.create(recursive: true);

      // Nombre nuevo para que Flutter no reutilice la imagen anterior en caché.
      final newCoverPath = p.join(coversDir.path, '${_uuid.v4()}.jpg');
      final cover = await _writeCover(coverBytes, newCoverPath);
      final updated = book.copyWith(
        coverPath: cover.path,
        accentColor: cover.accent,
      );
      await _db.updateBook(updated);

      final oldCover = book.coverPath;
      if (oldCover != null && oldCover != cover.path) {
        await _silentDelete(oldCover);
      }
      return updated;
    } finally {
      await document?.dispose();
    }
  }

  Future<ParsedFile> _parseEpub(String path) async {
    final parsed = await Isolate.run(() => _epubWorker(path));
    return parsed;
  }

  Future<ParsedFile> _parseCbz(String path) async {
    final parsed = await Isolate.run(() => _cbzWorker(path));
    return parsed;
  }

  Future<ParsedFile> _parseFb2(String path) async {
    final parsed = await Isolate.run(() => _fb2Worker(path));
    return parsed;
  }

  Future<ParsedFile> _parseTxt(String path) async {
    final bytes = await File(path).readAsBytes();
    final text = _decodeText(bytes);
    final flattened = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final preview = flattened.substring(0, math.min(700, flattened.length));
    return ParsedFile(
      metadata: ParsedMetadata(
        description: preview,
      ),
    );
  }

  Future<ParsedFile> _parseHtml(String path) async {
    final bytes = await File(path).readAsBytes();
    final document = html_parser.parse(_decodeText(bytes));
    final title = document.querySelector('title')?.text.trim();
    final author = document
        .querySelector('meta[name="author"]')
        ?.attributes['content']
        ?.trim();
    final description = document
        .querySelector('meta[name="description"]')
        ?.attributes['content']
        ?.trim();
    return ParsedFile(
      metadata: ParsedMetadata(
        title: title,
        author: author,
        description: description,
      ),
    );
  }

  Future<String> _hashFile(String path) {
    return Isolate.run(() async {
      final digest = await sha256.bind(File(path).openRead()).first;
      return digest.toString();
    });
  }

  Future<_CoverResult> _writeCover(Uint8List bytes, String outputPath) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('La portada no tiene un formato compatible');
    }
    final resized = decoded.width > 1000
        ? img.copyResize(decoded, width: 1000, interpolation: img.Interpolation.linear)
        : decoded;
    final encoded = img.encodeJpg(resized, quality: 86);
    final file = File(outputPath);
    await file.writeAsBytes(encoded, flush: true);

    final tiny = img.copyResize(
      resized,
      width: 1,
      height: 1,
      interpolation: img.Interpolation.average,
    );
    final pixel = tiny.getPixel(0, 0);
    final raw = Color.fromARGB(
      255,
      pixel.r.toInt(),
      pixel.g.toInt(),
      pixel.b.toInt(),
    );
    final hsl = HSLColor.fromColor(raw);
    final accent = hsl
        .withSaturation(hsl.saturation.clamp(0.28, 0.72))
        .withLightness(hsl.lightness.clamp(0.34, 0.58))
        .toColor();
    return _CoverResult(file.path, accent.toARGB32());
  }
}

class _CoverResult {
  const _CoverResult(this.path, this.accent);

  final String path;
  final int accent;
}

const _pdfCoverRepairKey = 'pdf_cover_render_v2';

/// Repara una sola vez las portadas de PDF importadas antes de corregir el
/// escalado de pdfrx. Devuelve true si cambió alguna portada.
Future<bool> repairPdfCovers(
  AppDatabase database,
  SharedPreferences preferences,
) async {
  if (preferences.getBool(_pdfCoverRepairKey) ?? false) return false;

  final service = ImportService(database);
  var changed = false;
  try {
    final books = await database.getBooks();
    for (final book in books) {
      if (book.format != BookFormat.pdf) continue;
      try {
        final updated = await service.refreshPdfCover(book);
        if (updated != null) changed = true;
      } catch (_) {
        // Una portada dañada no debe impedir que se abra la biblioteca.
      }
    }
    await preferences.setBool(_pdfCoverRepairKey, true);
  } catch (_) {
    // Si falla la consulta, se vuelve a intentar en el siguiente inicio.
  }
  return changed;
}

String _friendlyError(Object error) {
  final text = error.toString();
  if (text.contains('FormatException')) return 'archivo dañado o no válido';
  if (text.contains('FileSystemException')) return 'no se pudo leer el archivo';
  return 'error al importar';
}

// -----------------------------------------------------------------------------
// Metadatos
// -----------------------------------------------------------------------------

class ParsedMetadata {
  const ParsedMetadata({
    this.title,
    this.author,
    this.description,
    this.language,
    this.publisher,
    this.publishedDate,
  });

  final String? title;
  final String? author;
  final String? description;
  final String? language;
  final String? publisher;
  final String? publishedDate;
}

class ParsedFile {
  const ParsedFile({
    required this.metadata,
    this.pageCount,
    this.coverBytes,
  });

  final ParsedMetadata metadata;
  final int? pageCount;
  final Uint8List? coverBytes;
}

String _decodeText(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes, allowInvalid: true);
  }
}

// -----------------------------------------------------------------------------
// Trabajadores en isolate
// -----------------------------------------------------------------------------

ParsedFile _epubWorker(String path) {
  final archive = ZipDecoder().decodeBytes(File(path).readAsBytesSync());
  final files = <String, ArchiveFile>{};
  for (final file in archive.files) {
    if (file.isFile) {
      files[_normalize(file.name)] = file;
    }
  }

  final containerFile = files['META-INF/container.xml'];
  if (containerFile == null) {
    throw const FormatException('EPUB sin container.xml');
  }
  final container = XmlDocument.parse(utf8.decode(containerFile.content));
  final rootFile = container.descendants
      .whereType<XmlElement>()
      .where((e) => e.name.local == 'rootfile')
      .firstOrNull;
  final opfPath = rootFile?.getAttribute('full-path');
  if (opfPath == null) throw const FormatException('EPUB sin OPF');

  final opfFile = files[_normalize(opfPath)];
  if (opfFile == null) throw const FormatException('EPUB sin OPF');
  final opf = XmlDocument.parse(utf8.decode(opfFile.content));
  final opfDir = p.posix.dirname(_normalize(opfPath));

  String? dc(String name) {
    for (final element in opf.descendants.whereType<XmlElement>()) {
      if (element.name.local == name) {
        final text = element.innerText.trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  final manifest = <String, _ManifestItem>{};
  for (final element in opf.descendants.whereType<XmlElement>()) {
    if (element.name.local != 'item') continue;
    final id = element.getAttribute('id');
    final href = element.getAttribute('href');
    if (id == null || href == null) continue;
    manifest[id] = _ManifestItem(
      id: id,
      href: href,
      mediaType: element.getAttribute('media-type') ?? '',
      properties: element.getAttribute('properties') ?? '',
    );
  }

  String? coverId;
  for (final element in opf.descendants.whereType<XmlElement>()) {
    if (element.name.local == 'meta' &&
        element.getAttribute('name') == 'cover') {
      coverId = element.getAttribute('content');
    }
  }

  _ManifestItem? coverItem;
  if (coverId != null) coverItem = manifest[coverId];
  coverItem ??= manifest.values
      .where((item) => item.properties.split(' ').contains('cover-image'))
      .firstOrNull;
  coverItem ??= manifest.values
      .where((item) =>
          item.mediaType.startsWith('image/') &&
          item.href.toLowerCase().contains('cover'))
      .firstOrNull;

  Uint8List? coverBytes;
  if (coverItem != null) {
    final resolved = _resolve(opfDir, coverItem.href);
    final file = files[resolved];
    if (file != null && file.size < 12 * 1024 * 1024) {
      coverBytes = Uint8List.fromList(file.content);
    }
  }

  var spineCount = 0;
  for (final element in opf.descendants.whereType<XmlElement>()) {
    if (element.name.local == 'itemref') spineCount++;
  }

  return ParsedFile(
    metadata: ParsedMetadata(
      title: dc('title'),
      author: dc('creator'),
      description: _stripHtml(dc('description')),
      language: dc('language'),
      publisher: dc('publisher'),
      publishedDate: dc('date'),
    ),
    pageCount: spineCount,
    coverBytes: coverBytes,
  );
}

String _stripHtml(String? value) {
  if (value == null || value.isEmpty) return '';
  try {
    return html_parser.parseFragment(value).text?.trim() ?? '';
  } catch (_) {
    return value.replaceAll(RegExp('<[^>]*>'), '').trim();
  }
}

ParsedFile _cbzWorker(String path) {
  final bytes = File(path).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  final images = archive.files
      .where((file) => file.isFile && _isImage(file.name))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  Uint8List? cover;
  if (images.isNotEmpty && images.first.size < 20 * 1024 * 1024) {
    cover = Uint8List.fromList(images.first.content);
  }
  return ParsedFile(
    metadata: const ParsedMetadata(),
    pageCount: images.length,
    coverBytes: cover,
  );
}

ParsedFile _fb2Worker(String path) {
  final bytes = File(path).readAsBytesSync();
  final document = XmlDocument.parse(_decodeText(bytes));

  String? textOf(String localName) {
    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local == localName) {
        final text = element.innerText.trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  final title = textOf('book-title');
  final firstName = textOf('first-name') ?? '';
  final lastName = textOf('last-name') ?? '';
  final author = '$firstName $lastName'.trim();
  final annotation = textOf('annotation');
  final language = textOf('lang');

  Uint8List? cover;
  String? coverRef;
  for (final element in document.descendants.whereType<XmlElement>()) {
    if (element.name.local == 'image') {
      final href = element.getAttribute('l:href') ??
          element.getAttribute('xlink:href') ??
          element.attributes
              .where((a) => a.name.local == 'href')
              .map((a) => a.value)
              .firstOrNull;
      if (href != null && href.startsWith('#')) {
        coverRef = href.substring(1);
        break;
      }
    }
  }
  if (coverRef != null) {
    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local == 'binary' &&
          element.getAttribute('id') == coverRef) {
        try {
          cover = base64Decode(element.innerText.replaceAll(RegExp(r'\s'), ''));
        } catch (_) {
          cover = null;
        }
        break;
      }
    }
  }

  return ParsedFile(
    metadata: ParsedMetadata(
      title: title,
      author: author,
      description: annotation,
      language: language,
    ),
    coverBytes: cover,
  );
}

class _ManifestItem {
  const _ManifestItem({
    required this.id,
    required this.href,
    required this.mediaType,
    required this.properties,
  });

  final String id;
  final String href;
  final String mediaType;
  final String properties;
}

String _normalize(String path) {
  return p.posix.normalize(path.replaceAll('\\', '/'));
}

String _resolve(String baseDir, String href) {
  final clean = Uri.decodeComponent(href.split('#').first);
  return _normalize(p.posix.join(baseDir, clean));
}

bool _isImage(String name) {
  final ext = p.extension(name).toLowerCase();
  return const {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'}
      .contains(ext);
}

Future<void> _silentDelete(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {
    // Ignorar: limpieza best-effort.
  }
}
