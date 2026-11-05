import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Guarda las imágenes elegidas como portada de una estantería dentro del
/// almacenamiento privado de la app, para que sigan disponibles aunque el
/// archivo original se mueva o se borre.
class ShelfCoverStore {
  const ShelfCoverStore._();

  static const _uuid = Uuid();

  static Future<String?> import(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) return null;

    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'shelf_covers'));
    await directory.create(recursive: true);

    final extension = p.extension(sourcePath).toLowerCase();
    final fileName = '${_uuid.v4()}${extension.isEmpty ? '.jpg' : extension}';
    final target = File(p.join(directory.path, fileName));
    await source.copy(target.path);
    return target.path;
  }

  static Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Un archivo huérfano no debe impedir borrar o cambiar la portada.
    }
  }
}
