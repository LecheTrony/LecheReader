import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'core/data/app_database.dart';
import 'core/providers.dart';
import 'features/import/import_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // En escritorio usamos SQLite nativo mediante FFI.
  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Necesario para renderizar portadas de PDF antes de montar la interfaz.
  pdfrxFlutterInitialize();

  final preferences = await SharedPreferences.getInstance();
  final database = AppDatabase();
  await database.init();

  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      sharedPreferencesProvider.overrideWithValue(preferences),
    ],
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const LecheReaderApp(),
    ),
  );

  // Las portadas de PDF antiguas se regeneran en segundo plano para no
  // retrasar el arranque. Al terminar se recarga la biblioteca.
  unawaited(() async {
    final changed = await repairPdfCovers(database, preferences);
    if (changed) container.invalidate(libraryProvider);
  }());
}
