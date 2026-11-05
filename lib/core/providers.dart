import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/app_database.dart';
import 'models/app_settings.dart';
import 'models/book.dart';
import 'models/shelf.dart';
import 'theme/app_palette.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('appDatabaseProvider debe sobrescribirse en main');
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider debe sobrescribirse en main',
  );
});

// -----------------------------------------------------------------------------
// Ajustes
// -----------------------------------------------------------------------------

class SettingsNotifier extends Notifier<AppSettings> {
  static const _key = 'app_settings_v1';

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> update(AppSettings settings) async {
    state = settings;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_key, jsonEncode(settings.toJson()));
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      update(state.copyWith(themeMode: mode));

  Future<void> setReaderTheme(ReaderTheme theme) =>
      update(state.copyWith(readerTheme: theme));

  Future<void> setReaderType({required bool serif}) =>
      update(state.copyWith(readerSerif: serif));

  Future<void> setReaderFontSize(double size) =>
      update(state.copyWith(readerFontSize: size));

  Future<void> setReaderLineHeight(double height) =>
      update(state.copyWith(readerLineHeight: height));

  Future<void> setReaderMargin(double margin) =>
      update(state.copyWith(readerMargin: margin));

  Future<void> setReaderJustify(bool justify) =>
      update(state.copyWith(readerJustify: justify));

  Future<void> setLibrarySort(LibrarySort sort) =>
      update(state.copyWith(librarySort: sort));

  Future<void> setLibraryView(LibraryView view) =>
      update(state.copyWith(libraryView: view));

  Future<void> setLibraryColumns(int columns) =>
      update(state.copyWith(libraryColumns: columns));

  Future<void> setShowContinueReading(bool value) =>
      update(state.copyWith(showContinueReading: value));
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

// -----------------------------------------------------------------------------
// Biblioteca
// -----------------------------------------------------------------------------

class LibraryNotifier extends AsyncNotifier<List<Book>> {
  AppDatabase get _db => ref.read(appDatabaseProvider);

  @override
  Future<List<Book>> build() async {
    final books = await _db.getBooks();
    books.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return books;
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final books = await _db.getBooks();
      books.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      return books;
    });
  }

  Future<void> softReload() async {
    final books = await _db.getBooks();
    books.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    state = AsyncValue.data(books);
  }

  Future<void> toggleFavorite(Book book) async {
    final newValue = !book.isFavorite;
    await _db.toggleFavorite(book.id!, newValue);
    _replace(book.copyWith(isFavorite: newValue));
  }

  Future<void> refreshBook(Book book) async {
    final updated = await _db.getBook(book.id!);
    if (updated != null) _replace(updated);
  }

  Future<void> applyProgress({
    required int bookId,
    required double progress,
    required String location,
    required ReadingStatus status,
  }) async {
    await _db.updateProgress(
      bookId: bookId,
      progress: progress,
      location: location,
      status: status,
    );
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((b) => b.id == bookId);
    if (index < 0) return;
    final updated = current[index].copyWith(
      progress: progress.clamp(0.0, 1.0),
      location: location,
      status: status,
      lastOpenedAt: DateTime.now(),
    );
    final next = [...current]..[index] = updated;
    state = AsyncValue.data(next);
  }

  Future<void> markOpened(int bookId) async {
    await _db.markOpened(bookId);
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((b) => b.id == bookId);
    if (index < 0) return;
    final book = current[index];
    final next = [...current]
      ..[index] = book.copyWith(
        lastOpenedAt: DateTime.now(),
        status: book.status == ReadingStatus.unread
            ? ReadingStatus.reading
            : book.status,
      );
    state = AsyncValue.data(next);
  }

  Future<void> deleteBook(Book book) async {
    await _db.deleteBook(book.id!);
    final current = state.value ?? const <Book>[];
    state = AsyncValue.data(
      current.where((b) => b.id != book.id).toList(growable: false),
    );
  }

  Future<void> updateMetadata(Book book) async {
    await _db.updateBook(book);
    _replace(book);
  }

  void _replace(Book book) {
    final current = state.value;
    if (current == null) return;
    final index = current.indexWhere((b) => b.id == book.id);
    if (index < 0) return;
    final next = [...current]..[index] = book;
    state = AsyncValue.data(next);
  }
}

final libraryProvider = AsyncNotifierProvider<LibraryNotifier, List<Book>>(
  LibraryNotifier.new,
);

/// El libro que se está leyendo ahora mismo (el abierto más recientemente).
final continueReadingProvider = Provider<Book?>((ref) {
  final books = ref.watch(libraryProvider).value ?? const <Book>[];
  Book? best;
  for (final book in books) {
    if (book.progress <= 0.001 || book.progress >= 0.985) continue;
    if (book.lastOpenedAt == null) continue;
    if (best == null || book.lastOpenedAt!.isAfter(best.lastOpenedAt!)) {
      best = book;
    }
  }
  return best;
});

final bookByIdProvider = Provider.family<Book?, int>((ref, id) {
  final books = ref.watch(libraryProvider).value ?? const <Book>[];
  for (final book in books) {
    if (book.id == id) return book;
  }
  return null;
});

// -----------------------------------------------------------------------------
// Estanterías
// -----------------------------------------------------------------------------

class ShelvesNotifier extends AsyncNotifier<List<Shelf>> {
  AppDatabase get _db => ref.read(appDatabaseProvider);

  @override
  Future<List<Shelf>> build() => _db.getShelves();

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_db.getShelves);
  }

  Future<Shelf> create(String name, Color color) async {
    final shelf = Shelf(
      name: name.trim(),
      color: color.toARGB32(),
      createdAt: DateTime.now(),
    );
    final id = await _db.insertShelf(shelf);
    final created = shelf.copyWith(id: id);
    state = AsyncValue.data([created, ...state.value ?? const []]);
    return created;
  }

  Future<void> rename(Shelf shelf, String name) async {
    await _db.renameShelf(shelf.id!, name.trim());
    _update(shelf.id!, (current) => current.copyWith(name: name.trim()));
  }

  Future<void> setColor(Shelf shelf, Color color) async {
    await _db.updateShelfColor(shelf.id!, color.toARGB32());
    _update(
      shelf.id!,
      (current) => current.copyWith(color: color.toARGB32()),
    );
  }

  Future<void> setCover(Shelf shelf, String? coverPath) async {
    await _db.updateShelfCover(shelf.id!, coverPath);
    _update(
      shelf.id!,
      (current) => coverPath == null
          ? current.copyWith(clearCover: true)
          : current.copyWith(coverPath: coverPath),
    );
  }

  Future<void> delete(Shelf shelf) async {
    await _db.deleteShelf(shelf.id!);
    final coverPath = shelf.coverPath;
    if (coverPath != null) {
      try {
        final cover = File(coverPath);
        if (await cover.exists()) await cover.delete();
      } catch (_) {
        // La colección ya no existe aunque el archivo no se pueda borrar.
      }
    }
    state = AsyncValue.data(
      (state.value ?? const <Shelf>[])
          .where((s) => s.id != shelf.id)
          .toList(growable: false),
    );
  }

  Future<void> refreshCounts() async {
    final shelves = await _db.getShelves();
    state = AsyncValue.data(shelves);
  }

  Future<void> setBookShelves(int bookId, Iterable<int> shelfIds) async {
    await _db.setBookShelves(bookId, shelfIds);
    ref.invalidate(bookShelvesProvider(bookId));
    await refreshCounts();
  }

  /// Aplica un cambio sobre el estado actual para no pisar otras ediciones
  /// hechas en la misma sesión (por ejemplo, nombre y color a la vez).
  void _update(int id, Shelf Function(Shelf current) transform) {
    final current = state.value ?? const <Shelf>[];
    final index = current.indexWhere((s) => s.id == id);
    if (index < 0) return;
    final next = [...current]..[index] = transform(current[index]);
    state = AsyncValue.data(next);
  }
}

final shelvesProvider = AsyncNotifierProvider<ShelvesNotifier, List<Shelf>>(
  ShelvesNotifier.new,
);

final shelfByIdProvider = Provider.family<Shelf?, int>((ref, id) {
  final shelves = ref.watch(shelvesProvider).value ?? const <Shelf>[];
  for (final shelf in shelves) {
    if (shelf.id == id) return shelf;
  }
  return null;
});

final bookShelvesProvider = FutureProvider.family<List<Shelf>, int>((
  ref,
  bookId,
) {
  return ref.watch(appDatabaseProvider).getShelvesForBook(bookId);
});

final bookmarksProvider = FutureProvider.family<List<Bookmark>, int>((
  ref,
  bookId,
) {
  return ref.watch(appDatabaseProvider).getBookmarks(bookId);
});

final shelfBooksProvider = FutureProvider.family<List<Book>, int>((
  ref,
  shelfId,
) async {
  final sort = ref.read(settingsProvider).librarySort;
  return ref.watch(appDatabaseProvider).getBooks(
    filter: LibraryFilter(shelfId: shelfId),
    sort: sort,
  );
});
