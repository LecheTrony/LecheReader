import 'package:flutter/services.dart';

/// Controla el modo inmersivo mientras se está dentro del lector.
///
/// En Android se usa un canal nativo basado en `WindowInsetsController`,
/// porque Flutter ignora `SystemUiMode.immersiveSticky` a partir de Android 16.
/// En el resto de plataformas se recurre al modo inmersivo de Flutter.
class ImmersiveMode {
  ImmersiveMode._();

  static const _channel =
      MethodChannel('com.lechereader.leche_reader/immersive');

  static int _depth = 0;

  static Future<void> enter() async {
    _depth++;
    if (_depth > 1) return;
    await _apply(hidden: true);
  }

  static Future<void> exit() async {
    if (_depth == 0) return;
    _depth--;
    if (_depth > 0) return;
    await _apply(hidden: false);
  }

  static Future<void> _apply({required bool hidden}) async {
    try {
      await _channel.invokeMethod<void>(hidden ? 'enter' : 'exit');
    } on MissingPluginException {
      await _fallback(hidden);
    } on PlatformException {
      await _fallback(hidden);
    }
  }

  static Future<void> _fallback(bool hidden) async {
    try {
      await SystemChrome.setEnabledSystemUIMode(
        hidden ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    } on MissingPluginException {
      // La plataforma no ofrece control de barras del sistema.
    } on PlatformException {
      // La plataforma no ofrece control de barras del sistema.
    }
  }
}
