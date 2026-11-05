import 'package:flutter/material.dart';

@immutable
class Shelf {
  const Shelf({
    this.id,
    required this.name,
    required this.color,
    required this.createdAt,
    this.bookCount = 0,
    this.coverPath,
  });

  final int? id;
  final String name;
  final int color;
  final DateTime createdAt;
  final int bookCount;

  /// Ruta local de la imagen elegida como portada de la colección.
  final String? coverPath;

  Color get colorValue => Color(color);

  bool get hasCover => coverPath != null && coverPath!.isNotEmpty;

  Shelf copyWith({
    int? id,
    String? name,
    int? color,
    DateTime? createdAt,
    int? bookCount,
    String? coverPath,
    bool clearCover = false,
  }) {
    return Shelf(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      bookCount: bookCount ?? this.bookCount,
      coverPath: clearCover ? null : (coverPath ?? this.coverPath),
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'color': color,
        'created_at': createdAt.millisecondsSinceEpoch,
        'cover_path': coverPath,
      };

  factory Shelf.fromMap(Map<String, Object?> map) {
    return Shelf(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? 'Estantería',
      color: (map['color'] as int?) ?? 0xFFB4552D,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int?) ?? 0,
      ),
      bookCount: (map['book_count'] as int?) ?? 0,
      coverPath: map['cover_path'] as String?,
    );
  }
}

@immutable
class Bookmark {
  const Bookmark({
    this.id,
    required this.bookId,
    required this.location,
    required this.label,
    this.note = '',
    required this.progress,
    required this.createdAt,
  });

  final int? id;
  final int bookId;
  final String location;
  final String label;
  final String note;
  final double progress;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'book_id': bookId,
        'location': location,
        'label': label,
        'note': note,
        'progress': progress,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Bookmark.fromMap(Map<String, Object?> map) {
    return Bookmark(
      id: map['id'] as int?,
      bookId: (map['book_id'] as int?) ?? 0,
      location: (map['location'] as String?) ?? '',
      label: (map['label'] as String?) ?? 'Marcador',
      note: (map['note'] as String?) ?? '',
      progress: ((map['progress'] as num?) ?? 0).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int?) ?? 0,
      ),
    );
  }
}
