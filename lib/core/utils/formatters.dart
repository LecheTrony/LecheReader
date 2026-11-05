import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/book.dart';
import '../theme/app_palette.dart';

String formatFileSize(int bytes) {
  if (bytes <= 0) return '—';
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
  final mb = kb / 1024;
  if (mb < 1024) {
    return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
  }
  final gb = mb / 1024;
  return '${gb.toStringAsFixed(1)} GB';
}

const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day} de ${_months[local.month - 1]} de ${local.year}';
}

String formatShortDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day} ${_months[local.month - 1].substring(0, 3)} ${local.year}';
}

String relativeDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  if (diff < 7) return 'Hace $diff días';
  if (diff < 30) {
    final weeks = (diff / 7).floor();
    return weeks == 1 ? 'Hace 1 semana' : 'Hace $weeks semanas';
  }
  return formatShortDate(date);
}

String greetingForNow() {
  final hour = DateTime.now().hour;
  if (hour < 6) return 'Buenas noches';
  if (hour < 12) return 'Buenos días';
  if (hour < 20) return 'Buenas tardes';
  return 'Buenas noches';
}

String titleFromFileName(String fileName) {
  var name = fileName;
  final dot = name.lastIndexOf('.');
  if (dot > 0) name = name.substring(0, dot);
  name = name.replaceAll(RegExp(r'[_\s]+'), ' ').trim();
  // Convierte guiones de nombres como "documento-de-prueba" o "novela-2" en
  // espacios, pero conserva siglas tipo "K-VT".
  name = name.replaceAll(
    RegExp(r'(?<=\p{Ll})-(?=[\p{Ll}\p{Nd}])', unicode: true),
    ' ',
  );
  name = name.replaceAll(RegExp(r'\s*\((\d+)\)$'), '');
  name = name.replaceAll(RegExp(r'\s*-\s*$'), '');
  if (name.isEmpty) return 'Sin título';
  return name
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

/// Color de acento estable para portadas generadas.
Color accentForBook(Book book, AppPalette palette) {
  final stored = book.accentColor;
  if (stored != null && stored != 0) return Color(stored);
  final seed = (book.id ?? book.title.hashCode).abs();
  return palette.coverFallback[seed % palette.coverFallback.length];
}

List<Color> coverGradientFor(Book book, AppPalette palette) {
  final accent = accentForBook(book, palette);
  final hsl = HSLColor.fromColor(accent);
  final dark = hsl
      .withLightness((hsl.lightness * 0.62).clamp(0.0, 1.0))
      .withSaturation((hsl.saturation * 0.9).clamp(0.0, 1.0))
      .toColor();
  return [accent, dark];
}

Color onAccent(Color accent) {
  return ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
      ? const Color(0xFFFFFBF3)
      : const Color(0xFF241C16);
}

bool isDarkColor(Color color) =>
    ThemeData.estimateBrightnessForColor(color) == Brightness.dark;

/// Normaliza texto para búsquedas: minúsculas y sin tildes ni diéresis.
String normalizeForSearch(String value) {
  const accents = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n', 'ç': 'c',
  };
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(accents[char] ?? char);
  }
  return buffer.toString();
}

/// Iniciales para portadas sin imagen.
String initialsFor(String title, {int count = 2}) {
  final cleaned = title.replaceAll(RegExp(r'[«»"“”]'), '').trim();
  final words = cleaned
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .where((w) => !const {'de', 'del', 'la', 'las', 'el', 'los', 'y', 'en'}
          .contains(w.toLowerCase()))
      .toList();
  if (words.isEmpty) return '?';
  final take = math.min(count, words.length);
  return words
      .take(take)
      .map((w) => w.substring(0, 1).toUpperCase())
      .join();
}
