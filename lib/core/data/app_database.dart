import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_settings.dart';
import '../models/book.dart';
import '../models/shelf.dart';

/// Almacenamiento local de la biblioteca. Todo vive en el dispositivo.
class AppDatabase {
  Database? _db;

  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('La base de datos no está inicializada.');
    }
    return database;
  }

  Future<void> init() async {
    final support = await getApplicationSupportDirectory();
    await Directory(support.path).create(recursive: true);
    final path = p.join(support.path, 'leche_reader.db');
    _db = await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE books (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            author TEXT NOT NULL DEFAULT '',
            description TEXT NOT NULL DEFAULT '',
            file_path TEXT NOT NULL,
            cover_path TEXT,
            format TEXT NOT NULL,
            file_size INTEGER NOT NULL DEFAULT 0,
            page_count INTEGER,
            added_at INTEGER NOT NULL,
            last_opened_at INTEGER,
            progress REAL NOT NULL DEFAULT 0,
            location TEXT,
            is_favorite INTEGER NOT NULL DEFAULT 0,
            language TEXT,
            publisher TEXT,
            published_date TEXT,
            hash TEXT,
            status TEXT NOT NULL DEFAULT 'unread',
            accent_color INTEGER
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_books_last_opened ON books(last_opened_at)',
        );
        await db.execute('CREATE INDEX idx_books_added ON books(added_at)');
        await db.execute(
          'CREATE UNIQUE INDEX idx_books_hash ON books(hash) WHERE hash IS NOT NULL',
        );
        await db.execute('''
          CREATE TABLE shelves (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            color INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            cover_path TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE book_shelves (
            book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
            shelf_id INTEGER NOT NULL REFERENCES shelves(id) ON DELETE CASCADE,
            PRIMARY KEY (book_id, shelf_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE bookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_id INTEGER NOT NULL REFERENCES books(id) ON DELETE CASCADE,
            location TEXT NOT NULL,
            label TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT '',
            progress REAL NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_bookmarks_book ON bookmarks(book_id)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE shelves ADD COLUMN cover_path TEXT');
        }
      },
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ---------------------------------------------------------------------------
  // Libros
  // ---------------------------------------------------------------------------

  Future<List<Book>> getBooks({
    String? query,
    LibraryFilter filter = const LibraryFilter(),
    LibrarySort sort = LibrarySort.recent,
  }) {
    final where = <String>[];
    final args = <Object?>[];

    if (filter.status != null) {
      where.add('b.status = ?');
      args.add(filter.status!.name);
    }
    if (filter.favoritesOnly) {
      where.add('b.is_favorite = 1');
    }
    if (filter.shelfId != null) {
      where.add(
        'b.id IN (SELECT book_id FROM book_shelves WHERE shelf_id = ?)',
      );
      args.add(filter.shelfId);
    }
    final trimmed = query?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      where.add('(b.title LIKE ? OR b.author LIKE ?)');
      final like = '%$trimmed%';
      args.addAll([like, like]);
    }

    final orderBy = switch (sort) {
      LibrarySort.recent => 'b.added_at DESC',
      LibrarySort.title => 'b.title COLLATE NOCASE ASC',
      LibrarySort.author => 'b.author COLLATE NOCASE ASC',
      LibrarySort.lastOpened => 'COALESCE(b.last_opened_at, 0) DESC',
    };

    return db.query(
      'books b',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: orderBy,
    ).then((rows) => rows.map(Book.fromMap).toList());
  }

  Future<Book?> getBook(int id) async {
    final rows = await db.query('books', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Book.fromMap(rows.first);
  }

  Future<Book?> findBookByHash(String hash) async {
    final rows = await db.query(
      'books',
      where: 'hash = ?',
      whereArgs: [hash],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Book.fromMap(rows.first);
  }

  Future<Book?> getContinueReading() async {
    final rows = await db.query(
      'books',
      where: 'status = ? AND progress > 0 AND progress < 0.985',
      whereArgs: [ReadingStatus.reading.name],
      orderBy: 'COALESCE(last_opened_at, 0) DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Book.fromMap(rows.first);
  }

  Future<int> insertBook(Book book) {
    return db.insert(
      'books',
      book.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> updateBook(Book book) async {
    if (book.id == null) return;
    await db.update(
      'books',
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<void> updateProgress({
    required int bookId,
    required double progress,
    required String location,
    required ReadingStatus status,
  }) async {
    await db.update(
      'books',
      {
        'progress': progress.clamp(0.0, 1.0),
        'location': location,
        'last_opened_at': DateTime.now().millisecondsSinceEpoch,
        'status': status.name,
      },
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> markOpened(int bookId) async {
    await db.rawUpdate(
      '''
      UPDATE books
      SET last_opened_at = ?,
          status = CASE WHEN status = ? THEN ? ELSE status END
      WHERE id = ?
      ''',
      [
        DateTime.now().millisecondsSinceEpoch,
        ReadingStatus.unread.name,
        ReadingStatus.reading.name,
        bookId,
      ],
    );
  }

  Future<void> toggleFavorite(int bookId, bool value) async {
    await db.update(
      'books',
      {'is_favorite': value ? 1 : 0},
      where: 'id = ?',
      whereArgs: [bookId],
    );
  }

  Future<void> deleteBook(int bookId) async {
    await db.delete('books', where: 'id = ?', whereArgs: [bookId]);
  }

  Future<int> countBooks() async {
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM books');
    return (result.first['c'] as int?) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Estanterías
  // ---------------------------------------------------------------------------

  Future<List<Shelf>> getShelves() async {
    final rows = await db.rawQuery('''
      SELECT s.*, (
        SELECT COUNT(*) FROM book_shelves bs WHERE bs.shelf_id = s.id
      ) AS book_count
      FROM shelves s
      ORDER BY s.created_at DESC
    ''');
    return rows.map(Shelf.fromMap).toList();
  }

  Future<Shelf?> getShelf(int id) async {
    final rows = await db.rawQuery('''
      SELECT s.*, (
        SELECT COUNT(*) FROM book_shelves bs WHERE bs.shelf_id = s.id
      ) AS book_count
      FROM shelves s
      WHERE s.id = ?
    ''', [id]);
    if (rows.isEmpty) return null;
    return Shelf.fromMap(rows.first);
  }

  Future<int> insertShelf(Shelf shelf) {
    return db.insert('shelves', shelf.toMap());
  }

  Future<void> renameShelf(int id, String name) async {
    await db.update(
      'shelves',
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateShelfColor(int id, int color) async {
    await db.update(
      'shelves',
      {'color': color},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateShelfCover(int id, String? coverPath) async {
    await db.update(
      'shelves',
      {'cover_path': coverPath},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteShelf(int id) async {
    await db.delete('shelves', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Shelf>> getShelvesForBook(int bookId) async {
    final rows = await db.rawQuery('''
      SELECT s.*, (
        SELECT COUNT(*) FROM book_shelves bs2 WHERE bs2.shelf_id = s.id
      ) AS book_count
      FROM shelves s
      INNER JOIN book_shelves bs ON bs.shelf_id = s.id
      WHERE bs.book_id = ?
      ORDER BY s.name COLLATE NOCASE ASC
    ''', [bookId]);
    return rows.map(Shelf.fromMap).toList();
  }

  Future<void> addBookToShelf(int bookId, int shelfId) async {
    await db.insert(
      'book_shelves',
      {'book_id': bookId, 'shelf_id': shelfId},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeBookFromShelf(int bookId, int shelfId) async {
    await db.delete(
      'book_shelves',
      where: 'book_id = ? AND shelf_id = ?',
      whereArgs: [bookId, shelfId],
    );
  }

  Future<void> setBookShelves(int bookId, Iterable<int> shelfIds) async {
    await db.transaction((txn) async {
      await txn.delete(
        'book_shelves',
        where: 'book_id = ?',
        whereArgs: [bookId],
      );
      for (final shelfId in shelfIds) {
        await txn.insert(
          'book_shelves',
          {'book_id': bookId, 'shelf_id': shelfId},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Marcadores
  // ---------------------------------------------------------------------------

  Future<List<Bookmark>> getBookmarks(int bookId) async {
    final rows = await db.query(
      'bookmarks',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'created_at DESC',
    );
    return rows.map(Bookmark.fromMap).toList();
  }

  Future<int> insertBookmark(Bookmark bookmark) {
    return db.insert('bookmarks', bookmark.toMap());
  }

  Future<void> deleteBookmark(int id) async {
    await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }
}
