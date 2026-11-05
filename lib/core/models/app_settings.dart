import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import 'book.dart';

enum LibrarySort { recent, title, author, lastOpened }

extension LibrarySortX on LibrarySort {
  String get label => switch (this) {
        LibrarySort.recent => 'Añadidos recientemente',
        LibrarySort.title => 'Título (A-Z)',
        LibrarySort.author => 'Autor (A-Z)',
        LibrarySort.lastOpened => 'Última lectura',
      };

  IconData get icon => switch (this) {
        LibrarySort.recent => Icons.schedule_rounded,
        LibrarySort.title => Icons.sort_by_alpha_rounded,
        LibrarySort.author => Icons.person_outline_rounded,
        LibrarySort.lastOpened => Icons.auto_stories_outlined,
      };
}

enum LibraryView { grid, list }

@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.readerTheme = ReaderTheme.paper,
    this.readerSerif = true,
    this.readerFontSize = 19,
    this.readerLineHeight = 1.6,
    this.readerMargin = 26,
    this.readerJustify = true,
    this.librarySort = LibrarySort.recent,
    this.libraryView = LibraryView.grid,
    this.libraryColumns = 0,
    this.showContinueReading = true,
    this.defaultShelfId,
  });

  final ThemeMode themeMode;
  final ReaderTheme readerTheme;
  final bool readerSerif;
  final double readerFontSize;
  final double readerLineHeight;
  final double readerMargin;
  final bool readerJustify;
  final LibrarySort librarySort;
  final LibraryView libraryView;
  final int libraryColumns;
  final bool showContinueReading;
  final int? defaultShelfId;

  AppSettings copyWith({
    ThemeMode? themeMode,
    ReaderTheme? readerTheme,
    bool? readerSerif,
    double? readerFontSize,
    double? readerLineHeight,
    double? readerMargin,
    bool? readerJustify,
    LibrarySort? librarySort,
    LibraryView? libraryView,
    int? libraryColumns,
    bool? showContinueReading,
    int? defaultShelfId,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      readerTheme: readerTheme ?? this.readerTheme,
      readerSerif: readerSerif ?? this.readerSerif,
      readerFontSize: readerFontSize ?? this.readerFontSize,
      readerLineHeight: readerLineHeight ?? this.readerLineHeight,
      readerMargin: readerMargin ?? this.readerMargin,
      readerJustify: readerJustify ?? this.readerJustify,
      librarySort: librarySort ?? this.librarySort,
      libraryView: libraryView ?? this.libraryView,
      libraryColumns: libraryColumns ?? this.libraryColumns,
      showContinueReading: showContinueReading ?? this.showContinueReading,
      defaultShelfId: defaultShelfId ?? this.defaultShelfId,
    );
  }

  Map<String, Object?> toJson() => {
        'themeMode': themeMode.name,
        'readerTheme': readerTheme.name,
        'readerSerif': readerSerif,
        'readerFontSize': readerFontSize,
        'readerLineHeight': readerLineHeight,
        'readerMargin': readerMargin,
        'readerJustify': readerJustify,
        'librarySort': librarySort.name,
        'libraryView': libraryView.name,
        'libraryColumns': libraryColumns,
        'showContinueReading': showContinueReading,
        'defaultShelfId': defaultShelfId,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      readerTheme: ReaderTheme.values.firstWhere(
        (t) => t.name == json['readerTheme'],
        orElse: () => ReaderTheme.paper,
      ),
      readerSerif: (json['readerSerif'] as bool?) ?? true,
      readerFontSize: ((json['readerFontSize'] as num?) ?? 19).toDouble(),
      readerLineHeight: ((json['readerLineHeight'] as num?) ?? 1.6).toDouble(),
      readerMargin: ((json['readerMargin'] as num?) ?? 26).toDouble(),
      readerJustify: (json['readerJustify'] as bool?) ?? true,
      librarySort: LibrarySort.values.firstWhere(
        (s) => s.name == json['librarySort'],
        orElse: () => LibrarySort.recent,
      ),
      libraryView: LibraryView.values.firstWhere(
        (v) => v.name == json['libraryView'],
        orElse: () => LibraryView.grid,
      ),
      libraryColumns: (json['libraryColumns'] as int?) ?? 0,
      showContinueReading: (json['showContinueReading'] as bool?) ?? true,
      defaultShelfId: json['defaultShelfId'] as int?,
    );
  }
}

/// Estado del filtro activo en la biblioteca.
@immutable
class LibraryFilter {
  const LibraryFilter({this.status, this.favoritesOnly = false, this.shelfId});

  final ReadingStatus? status;
  final bool favoritesOnly;
  final int? shelfId;

  bool get isActive => status != null || favoritesOnly || shelfId != null;

  LibraryFilter copyWith({
    ReadingStatus? status,
    bool? favoritesOnly,
    int? shelfId,
    bool clearStatus = false,
    bool clearShelf = false,
  }) {
    return LibraryFilter(
      status: clearStatus ? null : (status ?? this.status),
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      shelfId: clearShelf ? null : (shelfId ?? this.shelfId),
    );
  }
}
