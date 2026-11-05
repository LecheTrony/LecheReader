import 'package:flutter/material.dart';

/// Formatos que LecheReader sabe abrir hoy.
enum BookFormat { pdf, epub, txt, cbz, fb2, html }

extension BookFormatX on BookFormat {
  String get label => switch (this) {
        BookFormat.pdf => 'PDF',
        BookFormat.epub => 'EPUB',
        BookFormat.txt => 'TXT',
        BookFormat.cbz => 'Cómic',
        BookFormat.fb2 => 'FB2',
        BookFormat.html => 'HTML',
      };

  String get description => switch (this) {
        BookFormat.pdf => 'Documento PDF',
        BookFormat.epub => 'Libro electrónico',
        BookFormat.txt => 'Texto plano',
        BookFormat.cbz => 'Cómic o álbum ilustrado',
        BookFormat.fb2 => 'FictionBook',
        BookFormat.html => 'Página web',
      };

  bool get isTextBased => switch (this) {
        BookFormat.epub || BookFormat.txt || BookFormat.fb2 || BookFormat.html => true,
        BookFormat.pdf || BookFormat.cbz => false,
      };

  bool get isFixedLayout => !isTextBased;

  IconData get icon => switch (this) {
        BookFormat.pdf => Icons.picture_as_pdf_outlined,
        BookFormat.epub => Icons.auto_stories_outlined,
        BookFormat.txt => Icons.notes_rounded,
        BookFormat.cbz => Icons.photo_library_outlined,
        BookFormat.fb2 => Icons.menu_book_outlined,
        BookFormat.html => Icons.language_rounded,
      };

  String get unitLabel => switch (this) {
        BookFormat.pdf => 'páginas',
        BookFormat.cbz => 'páginas',
        _ => 'capítulos',
      };

  static BookFormat? fromExtension(String? extension) {
    final ext = (extension ?? '').toLowerCase().replaceAll('.', '');
    return switch (ext) {
      'pdf' => BookFormat.pdf,
      'epub' => BookFormat.epub,
      'txt' => BookFormat.txt,
      'cbz' || 'cbr' || 'rar' => BookFormat.cbz,
      'fb2' => BookFormat.fb2,
      'html' || 'htm' || 'xhtml' => BookFormat.html,
      _ => null,
    };
  }

  static const supportedExtensions = [
    'pdf',
    'epub',
    'txt',
    'cbz',
    'cbr',
    'rar',
    'fb2',
    'html',
    'htm',
  ];
}

enum ReadingStatus { unread, reading, finished }

extension ReadingStatusX on ReadingStatus {
  String get label => switch (this) {
        ReadingStatus.unread => 'Sin empezar',
        ReadingStatus.reading => 'Leyendo',
        ReadingStatus.finished => 'Terminado',
      };

  static ReadingStatus fromString(String? value) {
    return switch (value) {
      'reading' => ReadingStatus.reading,
      'finished' => ReadingStatus.finished,
      _ => ReadingStatus.unread,
    };
  }
}

@immutable
class Book {
  const Book({
    this.id,
    required this.title,
    this.author = '',
    this.description = '',
    required this.filePath,
    this.coverPath,
    required this.format,
    this.fileSize = 0,
    this.pageCount,
    required this.addedAt,
    this.lastOpenedAt,
    this.progress = 0,
    this.location,
    this.isFavorite = false,
    this.language,
    this.publisher,
    this.publishedDate,
    this.hash,
    this.status = ReadingStatus.unread,
    this.accentColor,
  });

  final int? id;
  final String title;
  final String author;
  final String description;
  final String filePath;
  final String? coverPath;
  final BookFormat format;
  final int fileSize;
  final int? pageCount;
  final DateTime addedAt;
  final DateTime? lastOpenedAt;
  final double progress;
  final String? location;
  final bool isFavorite;
  final String? language;
  final String? publisher;
  final String? publishedDate;
  final String? hash;
  final ReadingStatus status;
  final int? accentColor;

  bool get hasCover => coverPath != null && coverPath!.isNotEmpty;
  bool get isStarted => progress > 0.001;
  bool get isFinished => status == ReadingStatus.finished || progress >= 0.985;

  String get displayAuthor => author.trim().isEmpty ? 'Autor desconocido' : author.trim();

  String get progressLabel {
    if (isFinished) return 'Terminado';
    if (!isStarted) return 'Sin empezar';
    return '${(progress * 100).round()}% leído';
  }

  Book copyWith({
    int? id,
    String? title,
    String? author,
    String? description,
    String? filePath,
    String? coverPath,
    BookFormat? format,
    int? fileSize,
    int? pageCount,
    DateTime? addedAt,
    DateTime? lastOpenedAt,
    double? progress,
    String? location,
    bool? isFavorite,
    String? language,
    String? publisher,
    String? publishedDate,
    String? hash,
    ReadingStatus? status,
    int? accentColor,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      filePath: filePath ?? this.filePath,
      coverPath: coverPath ?? this.coverPath,
      format: format ?? this.format,
      fileSize: fileSize ?? this.fileSize,
      pageCount: pageCount ?? this.pageCount,
      addedAt: addedAt ?? this.addedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      progress: progress ?? this.progress,
      location: location ?? this.location,
      isFavorite: isFavorite ?? this.isFavorite,
      language: language ?? this.language,
      publisher: publisher ?? this.publisher,
      publishedDate: publishedDate ?? this.publishedDate,
      hash: hash ?? this.hash,
      status: status ?? this.status,
      accentColor: accentColor ?? this.accentColor,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'author': author,
      'description': description,
      'file_path': filePath,
      'cover_path': coverPath,
      'format': format.name,
      'file_size': fileSize,
      'page_count': pageCount,
      'added_at': addedAt.millisecondsSinceEpoch,
      'last_opened_at': lastOpenedAt?.millisecondsSinceEpoch,
      'progress': progress,
      'location': location,
      'is_favorite': isFavorite ? 1 : 0,
      'language': language,
      'publisher': publisher,
      'published_date': publishedDate,
      'hash': hash,
      'status': status.name,
      'accent_color': accentColor,
    };
  }

  factory Book.fromMap(Map<String, Object?> map) {
    return Book(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? 'Sin título',
      author: (map['author'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      filePath: (map['file_path'] as String?) ?? '',
      coverPath: map['cover_path'] as String?,
      format: BookFormat.values.firstWhere(
        (f) => f.name == map['format'],
        orElse: () => BookFormat.epub,
      ),
      fileSize: (map['file_size'] as int?) ?? 0,
      pageCount: map['page_count'] as int?,
      addedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['added_at'] as int?) ?? 0,
      ),
      lastOpenedAt: map['last_opened_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['last_opened_at'] as int),
      progress: ((map['progress'] as num?) ?? 0).toDouble().clamp(0.0, 1.0),
      location: map['location'] as String?,
      isFavorite: ((map['is_favorite'] as int?) ?? 0) == 1,
      language: map['language'] as String?,
      publisher: map['publisher'] as String?,
      publishedDate: map['published_date'] as String?,
      hash: map['hash'] as String?,
      status: ReadingStatusX.fromString(map['status'] as String?),
      accentColor: map['accent_color'] as int?,
    );
  }
}
