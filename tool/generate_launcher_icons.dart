import 'dart:io';

import 'package:image/image.dart' as img;

/// Genera los iconos de Android a partir de `tool/icon_source.jpg`.
///
/// Uso:
///   dart run tool/generate_launcher_icons.dart
///
/// Produce los iconos clásicos (`ic_launcher.png`) y las capas del icono
/// adaptativo de Android 8+ (`ic_launcher_foreground.png`), además del color
/// de fondo y el XML de `mipmap-anydpi-v26`.
void main() {
  final sourceFile = File('tool/icon_source.jpg');
  if (!sourceFile.existsSync()) {
    stderr.writeln('No se encontró ${sourceFile.path}');
    exit(1);
  }

  final source = img.decodeJpg(sourceFile.readAsBytesSync());
  if (source == null) {
    stderr.writeln('No se pudo leer ${sourceFile.path}');
    exit(1);
  }

  final background = _sampleBackground(source);
  _cleanRoundedCorners(source, background);
  stdout.writeln(
    'Fondo: #${_hex(background.$1)}${_hex(background.$2)}${_hex(background.$3)}',
  );

  const legacySizes = <String, int>{
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };

  for (final entry in legacySizes.entries) {
    final icon = img.copyResize(
      source,
      width: entry.value,
      height: entry.value,
      interpolation: img.Interpolation.cubic,
    );
    final path = 'android/app/src/main/res/mipmap-${entry.key}/ic_launcher.png';
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(icon));
    stdout.writeln('$path (${entry.value}x${entry.value})');
  }

  // El icono adaptativo tiene un lienzo de 108 dp. El diseño se escala al 80 %
  // para que el texto y el libro queden dentro de la zona segura de la máscara
  // circular o squircle que aplica el lanzador.
  const adaptiveSizes = <String, int>{
    'mdpi': 108,
    'hdpi': 162,
    'xhdpi': 216,
    'xxhdpi': 324,
    'xxxhdpi': 432,
  };

  for (final entry in adaptiveSizes.entries) {
    final size = entry.value;
    final canvas = img.Image(width: size, height: size, numChannels: 4);
    img.fill(canvas, color: img.ColorRgba8(0, 0, 0, 0));

    final contentSize = (size * 0.8).round();
    final content = img.copyResize(
      source,
      width: contentSize,
      height: contentSize,
      interpolation: img.Interpolation.cubic,
    );
    final offset = ((size - contentSize) / 2).round();
    img.compositeImage(
      canvas,
      content,
      dstX: offset,
      dstY: offset,
      blend: img.BlendMode.alpha,
    );

    final path =
        'android/app/src/main/res/mipmap-${entry.key}/ic_launcher_foreground.png';
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(img.encodePng(canvas));
    stdout.writeln('$path (${size}x$size)');
  }

  final backgroundHex =
      '#${_hex(background.$1)}${_hex(background.$2)}${_hex(background.$3)}';
  File('android/app/src/main/res/values/colors.xml')
      .writeAsStringSync(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<resources>\n'
    '    <color name="ic_launcher_background">$backgroundHex</color>\n'
    '</resources>\n',
  );

  const adaptiveXml = '<?xml version="1.0" encoding="utf-8"?>\n'
      '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
      '    <background android:drawable="@color/ic_launcher_background" />\n'
      '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
      '</adaptive-icon>\n';

  Directory('android/app/src/main/res/mipmap-anydpi-v26')
      .createSync(recursive: true);
  File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml')
      .writeAsStringSync(adaptiveXml);

  stdout.writeln('Iconos generados correctamente.');
}

/// Toma el color dominante de los bordes (evitando las esquinas blancas).
(int, int, int) _sampleBackground(img.Image image) {
  var r = 0;
  var g = 0;
  var b = 0;
  var count = 0;

  final margin = (image.width * 0.15).round();
  final band = (image.height * 0.03).round().clamp(1, 20);

  void add(int x, int y) {
    final pixel = image.getPixel(x, y);
    r += pixel.r.toInt();
    g += pixel.g.toInt();
    b += pixel.b.toInt();
    count++;
  }

  // Franjas superior e inferior, sin acercarse a las esquinas.
  for (var x = margin; x < image.width - margin; x += 4) {
    for (var y = 0; y < band; y += 2) {
      add(x, y);
      add(x, image.height - 1 - y);
    }
  }

  // Laterales, sin acercarse a las esquinas.
  for (var y = margin; y < image.height - margin; y += 4) {
    for (var x = 0; x < band; x += 2) {
      add(x, y);
      add(image.width - 1 - x, y);
    }
  }

  return (r ~/ count, g ~/ count, b ~/ count);
}

/// El JPG trae las esquinas redondeadas en blanco. Las rellenamos con el color
/// de fondo para que no aparezcan destellos blancos al escalar el icono.
void _cleanRoundedCorners(img.Image image, (int, int, int) background) {
  final radius = (image.width * 0.06).round();
  final (bgR, bgG, bgB) = background;

  bool nearWhite(img.Pixel pixel) =>
      pixel.r > 235 && pixel.g > 235 && pixel.b > 235;

  for (final pixel in image) {
    final x = pixel.x;
    final y = pixel.y;
    final inCorner = (x < radius || x >= image.width - radius) &&
        (y < radius || y >= image.height - radius);
    if (inCorner && nearWhite(pixel)) {
      pixel
        ..r = bgR
        ..g = bgG
        ..b = bgB;
    }
  }
}

String _hex(int value) => value.toRadixString(16).padLeft(2, '0');
