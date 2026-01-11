import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ExchangeRateService {
  // Headers para simular un navegador y evitar bloqueos de seguridad (Cloudflare/Vercel)
  static const Map<String, String> _headers = {
    "User-Agent":
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "application/json",
  };

  // URL de tu backend propio (API).
  // IMPORTANTE: Reemplaza 'https://TU-APP.onrender.com' con la URL real que te dio Render.
  // Mantén '/rates' al final.
  static const String _customBackendUrl =
      'https://rinde-api.onrender.com/rates';

  // Para desarrollo local puedes descomentar esta línea:
  // static const String _customBackendUrl = 'http://127.0.0.1:8000/rates';

  Future<Map<String, double>?> getRates() async {
    // 0. PRIORIDAD MÁXIMA: Backend Propio (Alta Disponibilidad)
    try {
      final rates = await _fetchCustomBackend();
      if (rates != null) return rates;
    } catch (e) {
      // Si el backend propio falla, continuamos silenciosamente a los fallbacks públicos
      debugPrint('Backend propio no disponible, usando fallback público: $e');
    }

    // 1. Fallback: PyDolarVenezuela (API Pública)
    try {
      final rates = await _fetchPyDolarVenezuela();
      if (rates != null) return rates;
    } catch (e) {
      debugPrint('Error PyDolarVenezuela: $e');
    }

    // 2. Fallback a DolarApi (Si falla la primera)
    try {
      final rates = await _fetchDolarApi();
      if (rates != null) return rates;
    } catch (e) {
      debugPrint('Error DolarApi: $e');
    }

    return null;
  }

  Future<Map<String, double>?> _fetchCustomBackend() async {
    // Al ser backend propio, no necesitamos proxies ni headers complejos
    final response = await http.get(Uri.parse(_customBackendUrl));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['status'] == 'error') throw Exception(data['error']);

      return {
        'BCV': (data['BCV'] ?? 0).toDouble(),
        'EURO': (data['EURO'] ?? 0).toDouble(),
        'USDT': (data['USDT'] ?? 0).toDouble(),
      };
    }
    return null;
  }

  Future<Map<String, double>?> _fetchPyDolarVenezuela() async {
    String getUrl(String page) {
      const String base =
          'https://pydolarvenezuela-api.vercel.app/api/v1/dollar';
      final String target = '$base?page=$page';

      if (kIsWeb) {
        // Usamos corsproxy.io que suele ser más estable y rápido para JSON
        return 'https://corsproxy.io/?$target';
      }
      return target;
    }

    final url = Uri.parse(getUrl('bcv'));
    final response = await http.get(url, headers: _headers);

    if (response.statusCode == 200) {
      String body = response.body;

      // Si estamos en web con AllOrigins, desempaquetamos la respuesta
      // Nota: corsproxy.io devuelve el cuerpo directamente, no necesitamos desempaquetar 'contents'
      // como hacíamos con allorigins.

      final data = jsonDecode(body);
      final monitors = data['monitors'];

      final double bcv = (monitors['usd']['price'] ?? 0).toDouble();
      final double euro = (monitors['eur']['price'] ?? 0).toDouble();
      double usdt = bcv * 1.05; // Valor inicial estimado

      // Intentar obtener USDT real de la página de criptos
      try {
        final urlCrypto = Uri.parse(getUrl('criptodolar'));
        final responseCrypto = await http.get(urlCrypto, headers: _headers);

        if (responseCrypto.statusCode == 200) {
          String bodyCrypto = responseCrypto.body;
          // corsproxy devuelve directo
          final dataCrypto = jsonDecode(bodyCrypto);
          usdt =
              (dataCrypto['monitors']['binance']['price'] ?? usdt).toDouble();
        }
      } catch (_) {}

      return {'BCV': bcv, 'EURO': euro, 'USDT': usdt};
    }
    return null;
  }

  Future<Map<String, double>?> _fetchDolarApi() async {
    // Fallback: ve.dolarapi.com
    String getUrl() {
      const String target = 'https://ve.dolarapi.com/v1/dolares';
      if (kIsWeb) {
        return 'https://corsproxy.io/?$target';
      }
      return target;
    }

    final response = await http.get(Uri.parse(getUrl()), headers: _headers);

    if (response.statusCode == 200) {
      String body = response.body;

      final List<dynamic> data = jsonDecode(body);
      double bcv = 0;
      double usdt = 0;

      for (var item in data) {
        final String nombre = (item['nombre'] ?? '').toString().toLowerCase();
        final double promedio = (item['promedio'] ?? 0).toDouble();

        if (nombre == 'oficial' || nombre == 'bcv') {
          bcv = promedio;
        } else if (nombre == 'paralelo') {
          usdt = promedio;
        }
      }

      // Estimación de Euro si usamos este fallback
      double euro = bcv > 0 ? bcv * 1.09 : 0;

      if (bcv > 0) {
        return {'BCV': bcv, 'EURO': euro, 'USDT': usdt};
      }
    }
    return null;
  }
}
