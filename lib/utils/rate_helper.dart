import 'package:shared_preferences/shared_preferences.dart';

class RateHelper {
  static const String KEY_BCV = 'BCV';
  static const String KEY_EURO = 'EURO';
  static const String KEY_USDT = 'USDT';
  static const String KEY_CUSTOM = 'CUSTOM';

  static String _getCurrentKey(String currency) =>
      'rate_${currency.toLowerCase()}_current';
  static String _getPendingKey(String currency) =>
      'rate_${currency.toLowerCase()}_pending';
  static String _getValidFromKey(String currency) =>
      'rate_${currency.toLowerCase()}_valid_from';

  /// Guarda una tasa aplicando la lógica de horario:
  /// - USDT/CUSTOM: Se actualiza inmediatamente.
  /// - BCV/EURO (Primera vez): Se actualiza inmediatamente.
  /// - BCV/EURO (Después de las 12 PM): Se guarda como pendiente para mañana.
  /// - BCV/EURO (Antes de las 12 PM): Se actualiza inmediatamente.
  static Future<void> saveRate(String currency, double rate) async {
    final prefs = await SharedPreferences.getInstance();

    // USDT y Custom siempre son inmediatos
    if (currency == KEY_USDT || currency == KEY_CUSTOM) {
      await prefs.setDouble('rate_${currency.toLowerCase()}', rate);
      return;
    }

    final currentKey = _getCurrentKey(currency);
    final pendingKey = _getPendingKey(currency);
    final validFromKey = _getValidFromKey(currency);
    final legacyKey = 'rate_${currency.toLowerCase()}'; // Para compatibilidad

    // Verificar si es primera vez (no existe current ni legacy)
    bool isFirstTime =
        !prefs.containsKey(currentKey) && !prefs.containsKey(legacyKey);

    final now = DateTime.now();

    if (isFirstTime || now.hour < 12) {
      // Primera vez o antes del mediodía: Actualización inmediata
      await prefs.setDouble(currentKey, rate);
      await prefs.setDouble(legacyKey, rate); // Mantener sync con legacy
      // Limpiar pendientes si existen para evitar conflictos
      await prefs.remove(pendingKey);
      await prefs.remove(validFromKey);
    } else {
      // Después del mediodía: Validez a partir de mañana a las 00:00
      final tomorrow = now.add(const Duration(days: 1));
      final validFrom = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);

      await prefs.setDouble(pendingKey, rate);
      await prefs.setInt(validFromKey, validFrom.millisecondsSinceEpoch);
    }
  }

  /// Obtiene la información de la tasa, promoviendo la pendiente si ya es válida.
  static Future<Map<String, dynamic>> getRateInfo(String currency) async {
    final prefs = await SharedPreferences.getInstance();
    final legacyKey = 'rate_${currency.toLowerCase()}';

    if (currency == KEY_USDT || currency == KEY_CUSTOM) {
      return {
        'current': prefs.getDouble(legacyKey) ?? 0.0,
        'pending': null,
        'validFrom': null
      };
    }

    final currentKey = _getCurrentKey(currency);
    final pendingKey = _getPendingKey(currency);
    final validFromKey = _getValidFromKey(currency);

    // Verificar si hay una tasa pendiente que ya entró en vigencia
    if (prefs.containsKey(pendingKey) && prefs.containsKey(validFromKey)) {
      final validFrom =
          DateTime.fromMillisecondsSinceEpoch(prefs.getInt(validFromKey)!);
      if (DateTime.now().isAfter(validFrom)) {
        // Promover pendiente a actual
        final newRate = prefs.getDouble(pendingKey)!;
        await prefs.setDouble(currentKey, newRate);
        await prefs.setDouble(legacyKey, newRate);

        // Limpiar pendiente
        await prefs.remove(pendingKey);
        await prefs.remove(validFromKey);
      }
    }

    // Obtener valores finales
    double current =
        prefs.getDouble(currentKey) ?? prefs.getDouble(legacyKey) ?? 0.0;
    double? pending = prefs.getDouble(pendingKey);
    DateTime? validFrom = prefs.containsKey(validFromKey)
        ? DateTime.fromMillisecondsSinceEpoch(prefs.getInt(validFromKey)!)
        : null;

    return {'current': current, 'pending': pending, 'validFrom': validFrom};
  }
}
