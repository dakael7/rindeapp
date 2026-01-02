import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ExchangeRateService {
  // API de DolarApi.com (Venezuela)
  static const String _dolarUrl = 'https://ve.dolarapi.com/v1/dolares';
  static const String _euroUrl = 'https://ve.dolarapi.com/v1/euros';

  Future<Map<String, double>?> getRates() async {
    try {
      // Ejecutar peticiones en paralelo para optimizar tiempo y evitar bloqueos
      final results = await Future.wait([
        http.get(Uri.parse(_dolarUrl)).timeout(const Duration(seconds: 10)),
        http.get(Uri.parse(_euroUrl)).timeout(const Duration(seconds: 10)),
      ]);

      // Extraemos datos primitivos (Map) para evitar pasar objetos complejos (http.Response)
      // al Isolate. Esto previene errores de serialización u ofuscación en Release.
      final rawData = results
          .map(
            (r) => <String, dynamic>{
              'statusCode': r.statusCode,
              'body': r.body,
            },
          )
          .toList();

      return await compute(_parseRates, rawData);
    } catch (e) {
      print('Error obteniendo tasas: $e');
    }
    return null;
  }

  static Map<String, double>? _parseRates(List<Map<String, dynamic>> results) {
    final responseDolar = results[0];
    final responseEuro = results[1];

    double bcv = 0.0;
    double usdt = 0.0;
    double euro = 0.0;

    if (responseDolar['statusCode'] == 200) {
      final List<dynamic> jsonList = jsonDecode(responseDolar['body']);

      for (var item in jsonList) {
        final String nombre = (item['nombre'] ?? '').toString().toLowerCase();
        final double promedio = _parseValue(item['promedio']);
        final String? fecha = item['fechaActualizacion'];

        if (nombre == 'oficial' || nombre == 'bcv') {
          if (_isEffective(fecha)) {
            bcv = promedio;
          }
        } else if (nombre == 'paralelo') {
          usdt = promedio;
        }
      }
    }

    if (responseEuro['statusCode'] == 200) {
      final List<dynamic> jsonList = jsonDecode(responseEuro['body']);

      for (var item in jsonList) {
        final String nombre = (item['nombre'] ?? '').toString().toLowerCase();
        final double promedio = _parseValue(item['promedio']);
        final String? fecha = item['fechaActualizacion'];

        if (nombre == 'oficial' || nombre == 'bcv') {
          if (_isEffective(fecha)) {
            euro = promedio;
          }
        }
      }
    }

    if (bcv > 0) {
      return {'BCV': bcv, 'USDT': usdt, 'EURO': euro};
    }
    return null;
  }

  static bool _isEffective(String? dateStr) {
    if (dateStr == null) return true;
    try {
      final date = DateTime.parse(dateStr);
      // Si la fecha de la tasa es futura respecto al momento actual, no se aplica.
      if (date.isAfter(DateTime.now())) {
        return false;
      }
    } catch (_) {}
    return true;
  }

  static double _parseValue(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      // Manejo robusto de strings (ej. comas en lugar de puntos)
      return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
    }
    return 0.0;
  }
}
