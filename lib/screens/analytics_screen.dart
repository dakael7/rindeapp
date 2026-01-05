import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/transaction_model.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;

  // Datos
  List<TransactionModel> _allTransactions = [];
  double _currentRate = 1.0; // Tasa para visualizar en USD

  // Filtros
  String _selectedPeriod = '1M';
  final List<String> _periods = ['1S', '1M', '3M', '6M', '1A', 'TODO'];

  // Datos Visuales
  double _periodIncome = 0.0;
  double _periodExpense = 0.0;
  List<Map<String, dynamic>> _chartPoints = [];
  double _minBalance = 0.0;
  double _maxBalance = 1.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Cargar Tasa BCV para mostrar valores en USD (Consistencia con Home)
    final double bcv = prefs.getDouble('rate_bcv') ?? 52.5;

    // 2. Cargar Transacciones (Formato compatible con WalletScreen)
    final String? data = prefs.getString('transactions_data');
    List<TransactionModel> transactions = [];

    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      transactions = decoded.map((item) {
        // Mapeo manual: WalletScreen usa 'amountInVES', TransactionModel usa 'amount'
        final double amount = (item['amountInVES'] ?? 0).toDouble();
        final bool isExpense = item['isExpense'] ?? true;
        final DateTime date = DateTime.parse(item['date']);
        final String title = item['title'] ?? 'Movimiento';

        // Manejo seguro del ID
        int? id;
        if (item['id'] is int) {
          id = item['id'];
        } else if (item['id'] is String) {
          id = int.tryParse(item['id']);
        }

        return TransactionModel(
          id: id,
          name: title,
          concept: title,
          amount: amount, // Mantenemos base en VES
          isPositive: !isExpense,
          date: date,
          createdAt: date,
          updatedAt: date,
        );
      }).toList();
    }

    // Ordenar por fecha ascendente para calcular la línea de tiempo correctamente
    transactions.sort((a, b) => a.date.compareTo(b.date));

    if (mounted) {
      setState(() {
        _allTransactions = transactions;
        _currentRate = bcv > 0 ? bcv : 1.0;
        _isLoading = false;
      });
      _applyFilter();
    }
  }

  void _applyFilter() {
    final now = DateTime.now();
    DateTime startDate;
    bool groupByMonth = false;

    switch (_selectedPeriod) {
      case '1S':
        startDate = now.subtract(const Duration(days: 6));
        break;
      case '1M':
        startDate = now.subtract(const Duration(days: 29));
        break;
      case '3M':
        startDate = now.subtract(const Duration(days: 89));
        break;
      case '6M':
        startDate = now.subtract(const Duration(days: 180));
        groupByMonth = true;
        break;
      case '1A':
        startDate = now.subtract(const Duration(days: 365));
        groupByMonth = true;
        break;
      case 'TODO':
        startDate = _allTransactions.isNotEmpty
            ? _allTransactions.first.date
            : DateTime(2020);
        groupByMonth = true;
        break;
      default:
        startDate = now.subtract(const Duration(days: 29));
    }

    // Normalizar fecha de inicio (Inicio del día o mes)
    if (groupByMonth) {
      startDate = DateTime(startDate.year, startDate.month, 1);
    } else {
      startDate = DateTime(startDate.year, startDate.month, startDate.day);
    }

    double income = 0;
    double expense = 0;
    double currentBalanceVES = 0;

    // 1. Calcular balance inicial antes del periodo seleccionado
    int txIndex = 0;
    while (txIndex < _allTransactions.length &&
        _allTransactions[txIndex].date.isBefore(startDate)) {
      final t = _allTransactions[txIndex];
      if (t.isPositive) {
        currentBalanceVES += t.amount;
      } else {
        currentBalanceVES -= t.amount;
      }
      txIndex++;
    }

    List<Map<String, dynamic>> points = [];
    DateTime cursor = startDate;

    // 2. Generar barras por intervalo (Día o Mes)
    while (cursor.isBefore(now) ||
        cursor.isAtSameMomentAs(now) ||
        (groupByMonth &&
            cursor.year == now.year &&
            cursor.month == now.month)) {
      DateTime nextCursor;
      if (groupByMonth) {
        nextCursor = DateTime(cursor.year, cursor.month + 1, 1);
      } else {
        nextCursor = cursor.add(const Duration(days: 1));
      }

      // Procesar transacciones dentro de este intervalo
      while (txIndex < _allTransactions.length &&
          _allTransactions[txIndex].date.isBefore(nextCursor)) {
        final t = _allTransactions[txIndex];
        if (t.isPositive) {
          currentBalanceVES += t.amount;
          income += t.amount / _currentRate;
        } else {
          currentBalanceVES -= t.amount;
          expense += t.amount / _currentRate;
        }
        txIndex++;
      }

      points.add({
        'date': cursor,
        'value': currentBalanceVES / _currentRate,
        'label': groupByMonth
            ? DateFormat('MMM').format(cursor)
            : DateFormat('d').format(cursor),
      });

      cursor = nextCursor;
      if (cursor.isAfter(now) && !groupByMonth) break;
      if (groupByMonth && cursor.isAfter(now)) break;
    }

    if (points.isEmpty) {
      points.add({'date': now, 'value': 0.0, 'label': ''});
    }

    // Calcular Min/Max para escalar el gráfico
    double minVal = 0;
    double maxVal = 0;

    if (points.isNotEmpty) {
      minVal = points
          .map((e) => e['value'] as double)
          .reduce((a, b) => a < b ? a : b);
      maxVal = points
          .map((e) => e['value'] as double)
          .reduce((a, b) => a > b ? a : b);
    }

    // Ajustar rango para que las barras se vean bien (siempre incluir el 0)
    if (minVal > 0) minVal = 0;
    if (maxVal < 0) maxVal = 0;

    double range = maxVal - minVal;
    if (range == 0) range = 10.0;

    // Añadir un poco de margen superior e inferior
    maxVal += range * 0.1;
    if (minVal < 0) minVal -= range * 0.1;

    setState(() {
      _periodIncome = income;
      _periodExpense = expense;
      _chartPoints = points;
      _minBalance = minVal - (range * 0.2);
      _maxBalance = maxVal + (range * 0.2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    const primaryGreen = Color(0xFF4ADE80);
    const expenseRed = Color(0xFFFF5252);
    const cardColor = Color(0xFF132B3D);

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
          'Analíticas',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filtros de Tiempo
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _periods.map((period) {
                        final isSelected = _selectedPeriod == period;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(period),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedPeriod = period);
                                _applyFilter();
                              }
                            },
                            selectedColor: primaryGreen,
                            backgroundColor: cardColor,
                            labelStyle: GoogleFonts.poppins(
                              color: isSelected
                                  ? const Color(0xFF071925)
                                  : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Resumen Ingresos vs Gastos
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          title: 'Ingresos',
                          amount: _periodIncome,
                          color: primaryGreen,
                          icon: Icons.arrow_downward,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Gastos',
                          amount: _periodExpense,
                          color: expenseRed,
                          icon: Icons.arrow_upward,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Gráfico de Balance
                  Text(
                    'Balance en el tiempo',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 250,
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: CustomPaint(
                      painter: _BarChartPainter(
                        data: _chartPoints,
                        minVal: _minBalance,
                        maxVal: _maxBalance,
                        barColor: primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF132B3D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: const Color(0xFFB0BEC5),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '\$${amount.toStringAsFixed(2)}', // Mostrar 2 decimales
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double minVal;
  final double maxVal;
  final Color barColor;

  _BarChartPainter({
    required this.data,
    required this.minVal,
    required this.maxVal,
    required this.barColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    final double barWidth = size.width / (data.length * 1.5);
    final double spacing = size.width / data.length;
    final double range = maxVal - minVal;

    // Posición Y del eje 0
    final double zeroY = size.height - ((0 - minVal) / range) * size.height;

    for (int i = 0; i < data.length; i++) {
      final double val = data[i]['value'];
      final double x = i * spacing + (spacing - barWidth) / 2;

      // Calcular altura de la barra
      final double barTop =
          size.height - ((val - minVal) / range) * size.height;

      // Dibujar barra desde zeroY hasta barTop
      Rect rect = Rect.fromLTRB(
        x,
        math.min(zeroY, barTop),
        x + barWidth,
        math.max(zeroY, barTop),
      );

      // Bordes redondeados
      RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      canvas.drawRRect(rrect, paint);
    }

    // Dibujar línea base en 0
    final linePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
