import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bloquea o permite capturas de pantalla (Android: FLAG_SECURE).
///
/// Nota: en Android, con FLAG_SECURE **no se pueden detectar** intentos de captura
/// desde Flutter de forma fiable (el sistema simplemente bloquea la captura).
/// Por eso este servicio se centra en activar/desactivar el bloqueo.
class ScreenshotProtectionService {
  static const MethodChannel _channel =
      MethodChannel('kryptos/screenshot_protection');

  Future<void> setEnabled(bool enabled) async {
    // Solo Android soporta FLAG_SECURE vía este canal.
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('setSecure', {'enabled': enabled});
    } catch (_) {
      // Si algo falla (por ejemplo, en tests), no hacemos crash.
    }
  }
}
