import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class InflationDetailScreen extends StatelessWidget {
  final Map<String, double> balances;
  final List<Map<String, dynamic>> history;
  final Map<String, double> currentRates;

  const InflationDetailScreen({
    Key? key,
    required this.balances,
    required this.history,
    required this.currentRates,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Colores
    const backgroundColor = Color(0xFF071925);
    const cardColor = Color(0xFF132B3D);
    const primaryGreen = Color(0xFF4ADE80);
    const expenseRed = Color(0xFFFF5252);
    const textGrey = Color(0xFFB0BEC5);

    // Filtrar monedas con saldo > 0
    final activeCurrencies = balances.entries
        .where((e) => e.value > 0.01) // Solo mostrar si hay saldo relevante
        .toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Inflación Personal',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: activeCurrencies.isEmpty
          ? Center(
              child: Text(
                'No hay saldos registrados para analizar.',
                style: GoogleFonts.poppins(color: textGrey),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Impacto en tus Finanzas (24h)',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Análisis basado en el cambio de tasas respecto a ayer.',
                  style: GoogleFonts.poppins(color: textGrey, fontSize: 12),
                ),
                const SizedBox(height: 24),
                ...activeCurrencies.map((entry) {
                  return _buildCurrencyCard(
                    context,
                    entry.key,
                    entry.value,
                    cardColor,
                    primaryGreen,
                    expenseRed,
                    textGrey,
                  );
                }).toList(),
                const SizedBox(height: 30),
                if (balances['VES'] != null && balances['VES']! > 0) ...[
                  Text(
                    'Devaluación del Bolívar (7 Días)',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildDevaluationChart(
                    balances['VES']!,
                    cardColor,
                    expenseRed,
                    textGrey,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildCurrencyCard(
    BuildContext context,
    String currency,
    double amount,
    Color cardColor,
    Color green,
    Color red,
    Color grey,
  ) {
    // Lógica de cálculo
    // 1. Obtener tasa de ayer
    double rateYesterday = 0.0;
    double rateToday = currentRates['BCV'] ?? 0.0; // Default base BCV

    if (currency != 'VES') {
      // Si es divisa, usamos su tasa contra Bs
      rateToday = currentRates[currency == 'USD' ? 'BCV' : currency] ?? 0.0;
    }

    // Buscar en historial (asumimos que history está ordenado desc por fecha)
    // Buscamos el primer registro que NO sea hoy
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    Map<String, dynamic>? yesterdayEntry;

    for (var entry in history) {
      final entryDate = DateTime.parse(entry['date']);
      if (DateFormat('yyyy-MM-dd').format(entryDate) != todayStr) {
        yesterdayEntry = entry;
        break;
      }
    }

    if (yesterdayEntry != null) {
      final rates = yesterdayEntry['rates'];
      if (currency == 'VES') {
        rateYesterday = (rates['BCV'] ?? 0).toDouble();
      } else {
        rateYesterday = (rates[currency == 'USD' ? 'BCV' : currency] ?? 0)
            .toDouble();
      }
    } else {
      rateYesterday = rateToday; // Sin historial, no hay cambio
    }

    // Cálculos
    double diffValue = 0.0;
    double diffPercent = 0.0;
    String diffLabel = '';
    bool isLoss = false;

    if (currency == 'VES') {
      // Para Bs: Calculamos pérdida de valor en Dólares
      // Valor Ayer en $ = Monto / TasaAyer
      // Valor Hoy en $ = Monto / TasaHoy
      if (rateYesterday > 0 && rateToday > 0) {
        final valYesterdayUSD = amount / rateYesterday;
        final valTodayUSD = amount / rateToday;
        diffValue =
            valTodayUSD - valYesterdayUSD; // Será negativo si subió el dólar
        diffPercent = (diffValue / valYesterdayUSD) * 100;
        isLoss = diffValue < 0;
        diffLabel = 'en valor USD';
      }
    } else {
      // Para Divisas: Calculamos ganancia de poder adquisitivo en Bs
      // Valor Ayer en Bs = Monto * TasaAyer
      // Valor Hoy en Bs = Monto * TasaHoy
      final valYesterdayVES = amount * rateYesterday;
      final valTodayVES = amount * rateToday;
      diffValue = valTodayVES - valYesterdayVES; // Positivo si subió la tasa
      if (valYesterdayVES > 0) {
        diffPercent = (diffValue / valYesterdayVES) * 100;
      }
      isLoss = diffValue < 0; // Raro en Vzla, pero posible
      diffLabel = 'en poder de compra (Bs)';
    }

    final symbol = currency == 'VES'
        ? 'Bs'
        : currency == 'EURO'
        ? '€'
        : '\$';
    final diffSymbol = currency == 'VES' ? '\$' : 'Bs';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      symbol,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currency == 'VES' ? 'Bolívares' : currency,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Tenencia: $symbol${amount.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(color: grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${diffPercent > 0 ? "+" : ""}${diffPercent.toStringAsFixed(2)}%',
                    style: GoogleFonts.poppins(
                      color: isLoss ? red : green,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '${diffValue > 0 ? "+" : ""}$diffSymbol${diffValue.abs().toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      color: isLoss
                          ? red.withOpacity(0.8)
                          : green.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 8),
          Text(
            currency == 'VES'
                ? 'Tus Bs valen ${diffValue.abs().toStringAsFixed(2)} dólares menos que ayer.'
                : 'Tus divisas compran ${diffValue.abs().toStringAsFixed(2)} bolívares más que ayer.',
            style: GoogleFonts.poppins(
              color: grey,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDevaluationChart(
    double amountVES,
    Color cardColor,
    Color red,
    Color grey,
  ) {
    // Tomar últimos 7 días del historial
    final chartData = history.take(7).toList().reversed.toList();

    if (chartData.isEmpty) return const SizedBox();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: chartData.map((entry) {
                final rate = (entry['rates']['BCV'] ?? 1).toDouble();
                final valueInUSD = amountVES / rate;

                // Normalizar altura (simple)
                // En un caso real, buscaríamos min/max para escalar
                final heightFactor =
                    (valueInUSD / (amountVES / (currentRates['BCV'] ?? 1))) *
                    0.5;
                // Esto es simplificado. Para visualización real de "pérdida",
                // mostramos barras que bajan o el valor en USD.

                // Mejor: Mostrar el valor en USD de esos Bs ese día
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '\$${valueInUSD.toStringAsFixed(1)}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 8,
                      height:
                          50 +
                          (valueInUSD % 50), // Altura dinámica simple para demo
                      decoration: BoxDecoration(
                        color: red.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('dd/MM').format(DateTime.parse(entry['date'])),
                      style: GoogleFonts.poppins(color: grey, fontSize: 10),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
