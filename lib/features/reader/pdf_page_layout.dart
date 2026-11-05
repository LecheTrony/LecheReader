import 'dart:math' as math;
import 'dart:ui';

import 'package:pdfrx/pdfrx.dart';

/// Calcula la disposición vertical de las páginas de un PDF.
///
/// A diferencia de la disposición por defecto de pdfrx, el ancho del documento
/// no lo decide la página más ancha. Se toma el ancho habitual del libro y las
/// páginas dobles (o cualquier página más ancha) se reducen a ese ancho
/// conservando su proporción. Así las páginas normales no quedan con franjas
/// laterales cuando el documento contiene un desplegable.
PdfPageLayout layoutPdfPages(
  List<PdfPage> pages,
  PdfViewerParams params,
) {
  final sizes = normalizedPdfPageSizes([
    for (final page in pages) Size(page.width, page.height),
  ]);

  var documentWidth = 0.0;
  for (final size in sizes) {
    documentWidth = math.max(documentWidth, size.width);
  }
  documentWidth += params.margin * 2;

  final pageLayouts = <Rect>[];
  var y = params.margin;
  for (final size in sizes) {
    pageLayouts.add(
      Rect.fromLTWH(
        (documentWidth - size.width) / 2,
        y,
        size.width,
        size.height,
      ),
    );
    y += size.height + params.margin;
  }

  return PdfPageLayout(
    pageLayouts: pageLayouts,
    documentSize: Size(documentWidth, y),
  );
}

/// Ancho de referencia del libro: el que aparece con más frecuencia.
///
/// Los anchos se agrupan en intervalos de 10 puntos para tolerar pequeñas
/// diferencias entre páginas escaneadas. Si hay un empate se prefiere el ancho
/// menor, que suele ser el de una página normal frente al de una doble.
double pdfReferenceWidth(Iterable<Size> sizes) {
  const bucketSize = 10.0;
  final buckets = <int, List<double>>{};

  for (final size in sizes) {
    if (size.width <= 0) continue;
    final key = (size.width / bucketSize).round();
    buckets.putIfAbsent(key, () => <double>[]).add(size.width);
  }

  if (buckets.isEmpty) return 0;

  final keys = buckets.keys.toList()..sort();
  var bestKey = keys.first;
  var bestCount = -1;
  for (final key in keys) {
    final count = buckets[key]!.length;
    if (count > bestCount) {
      bestKey = key;
      bestCount = count;
    }
  }

  final widths = buckets[bestKey]!..sort();
  return widths[widths.length ~/ 2];
}

/// Iguala las páginas más anchas que el ancho de referencia.
///
/// Las páginas más estrechas se dejan intactas; las más anchas se escalan
/// manteniendo la proporción para que todas compartan el mismo ancho útil.
List<Size> normalizedPdfPageSizes(List<Size> sizes) {
  final reference = pdfReferenceWidth(sizes);
  if (reference <= 0) return List<Size>.of(sizes);

  return [
    for (final size in sizes)
      if (size.width > reference && size.height > 0)
        Size(reference, size.height * reference / size.width)
      else
        size,
  ];
}
