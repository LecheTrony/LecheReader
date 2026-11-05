import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:leche_reader/features/reader/pdf_page_layout.dart';

void main() {
  group('pdfReferenceWidth', () {
    test('elige el ancho que más se repite', () {
      final sizes = [
        const Size(612, 792),
        const Size(612, 792),
        const Size(1224, 792),
        const Size(612, 792),
      ];

      expect(pdfReferenceWidth(sizes), 612);
    });

    test('tolera pequeñas diferencias entre páginas escaneadas', () {
      final sizes = [
        const Size(611.5, 792),
        const Size(612, 792),
        const Size(612.4, 792),
        const Size(1224, 792),
      ];

      expect(pdfReferenceWidth(sizes), 612);
    });

    test('en un empate prefiere el ancho menor', () {
      final sizes = [
        const Size(612, 792),
        const Size(1224, 792),
      ];

      expect(pdfReferenceWidth(sizes), 612);
    });

    test('devuelve cero si no hay páginas válidas', () {
      expect(pdfReferenceWidth(const []), 0);
      expect(pdfReferenceWidth(const [Size.zero]), 0);
    });
  });

  group('normalizedPdfPageSizes', () {
    test('reduce una página doble al ancho de la página normal', () {
      final sizes = [
        const Size(612, 792),
        const Size(612, 792),
        const Size(1224, 792),
      ];

      final normalized = normalizedPdfPageSizes(sizes);

      expect(normalized[0], const Size(612, 792));
      expect(normalized[1], const Size(612, 792));
      expect(normalized[2].width, closeTo(612, 0.001));
      expect(normalized[2].height, closeTo(396, 0.001));
    });

    test('no cambia las páginas cuando todas miden lo mismo', () {
      final sizes = List<Size>.filled(5, const Size(1224, 792));

      expect(normalizedPdfPageSizes(sizes), sizes);
    });

    test('deja intactas las páginas más estrechas', () {
      final sizes = [
        const Size(600, 800),
        const Size(612, 792),
        const Size(612, 792),
      ];

      final normalized = normalizedPdfPageSizes(sizes);

      expect(normalized[0], const Size(600, 800));
      expect(normalized[1], const Size(612, 792));
      expect(normalized[2], const Size(612, 792));
    });

    test('también ajusta una portada más ancha que el interior', () {
      final sizes = [
        const Size(1200, 1600),
        const Size(612, 792),
        const Size(612, 792),
      ];

      final normalized = normalizedPdfPageSizes(sizes);

      expect(normalized[0].width, closeTo(612, 0.001));
      expect(normalized[0].height, closeTo(816, 0.001));
    });

    test('no falla con una lista vacía', () {
      expect(normalizedPdfPageSizes(const []), isEmpty);
    });
  });
}
