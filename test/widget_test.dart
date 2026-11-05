import 'package:flutter_test/flutter_test.dart';
import 'package:leche_reader/core/models/book.dart';
import 'package:leche_reader/core/models/shelf.dart';
import 'package:leche_reader/core/utils/formatters.dart';

void main() {
  group('formatFileSize', () {
    test('formatea bytes, kilobytes y megabytes', () {
      expect(formatFileSize(0), '—');
      expect(formatFileSize(512), '512 B');
      expect(formatFileSize(2048), '2 KB');
      expect(formatFileSize(5 * 1024 * 1024), '5.0 MB');
    });
  });

  group('titleFromFileName', () {
    test('limpia separadores y extensiones', () {
      expect(
        titleFromFileName('cartas_desde_el_faro.epub'),
        'Cartas Desde El Faro',
      );
      expect(
        titleFromFileName('documento-de-prueba.pdf'),
        'Documento De Prueba',
      );
      expect(
        titleFromFileName('novela-grafica-2.cbr'),
        'Novela Grafica 2',
      );
      expect(titleFromFileName('[K-VT] Dungeon.cbz'), '[K-VT] Dungeon');
    });

    test('usa un título de reserva cuando el nombre está vacío', () {
      expect(titleFromFileName(''), 'Sin título');
    });
  });

  group('normalizeForSearch', () {
    test('ignora tildes y mayúsculas', () {
      expect(normalizeForSearch('El Jardín de las Horas'), 'el jardin de las horas');
      expect(normalizeForSearch('Inés Valdés'), 'ines valdes');
      expect(normalizeForSearch('CÓMIC'), 'comic');
    });
  });

  group('Shelf', () {
    test('conserva y elimina la portada de la colección', () {
      final shelf = Shelf(
        id: 1,
        name: 'Favoritos',
        color: 0xFFB4552D,
        createdAt: DateTime(2026),
        coverPath: '/covers/favoritos.png',
      );

      expect(shelf.hasCover, isTrue);
      expect(shelf.copyWith(name: 'Invierno').coverPath, shelf.coverPath);
      expect(shelf.copyWith(clearCover: true).hasCover, isFalse);
    });

    test('lee la portada desde la base de datos', () {
      final shelf = Shelf.fromMap({
        'id': 2,
        'name': 'Viajes',
        'color': 0xFF6C7A5B,
        'created_at': 0,
        'book_count': 3,
        'cover_path': '/covers/viajes.jpg',
      });

      expect(shelf.hasCover, isTrue);
      expect(shelf.coverPath, '/covers/viajes.jpg');
      expect(shelf.bookCount, 3);
    });
  });

  group('BookFormatX', () {
    test('detecta formatos de texto', () {
      expect(BookFormat.epub.isTextBased, isTrue);
      expect(BookFormat.fb2.isTextBased, isTrue);
      expect(BookFormat.pdf.isTextBased, isFalse);
      expect(BookFormat.cbz.isTextBased, isFalse);
    });

    test('resuelve extensiones conocidas', () {
      expect(BookFormatX.fromExtension('.EPUB'), BookFormat.epub);
      expect(BookFormatX.fromExtension('cbr'), BookFormat.cbz);
      expect(BookFormatX.fromExtension('rar'), BookFormat.cbz);
      expect(BookFormatX.fromExtension('mobi'), isNull);
    });
  });
}
