import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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

    switch (_selectedPeriod) {
      case '1S':
        startDate = now.subtract(const Duration(days: 7));
        break;
      case '1M':
        startDate = now.subtract(const Duration(days: 30));
        break;
      case '3M':
        startDate = now.subtract(const Duration(days: 90));
        break;
      case '6M':
        startDate = now.subtract(const Duration(days: 180));
        break;
      case '1A':
        startDate = now.subtract(const Duration(days: 365));
        break;
      case 'TODO':
        startDate = DateTime(2000);
        break;
      default:
        startDate = now.subtract(const Duration(days: 30));
    }

    double income = 0;
    double expense = 0;
    double currentBalanceVES = 0;
    List<Map<String, dynamic>> points = [];

    bool firstPointAdded = false;

    // Recorremos TODAS las transacciones para llevar el balance acumulado correcto
    for (var t in _allTransactions) {
      // Actualizar balance global en VES
      if (t.isPositive) {
        currentBalanceVES += t.amount;
      } else {
        currentBalanceVES -= t.amount;
      }

      // Solo agregamos puntos al gráfico si están dentro del rango seleccionado
      if (t.date.isAfter(startDate)) {
        // Convertimos a USD para visualización
        final double balanceUSD = currentBalanceVES / _currentRate;

        // Si es el primer punto visible, agregamos el estado inicial
        if (!firstPointAdded) {
          // El balance inicial es el balance ANTES de esta transacción
          double prevBalanceVES =
              currentBalanceVES - (t.isPositive ? t.amount : -t.amount);
          points.add({
            'date': startDate,
            'value': prevBalanceVES / _currentRate,
          });
          firstPointAdded = true;
        }

        // Sumar a totales del periodo (Convertidos a USD)
        if (t.isPositive) {
          income += t.amount / _currentRate;
        } else {
          expense += t.amount / _currentRate;
        }

        points.add({'date': t.date, 'value': balanceUSD});
      }
    }

    // Si no hay puntos pero hay historial previo, proyectamos una línea plana
    if (points.isEmpty && _allTransactions.isNotEmpty) {
      points.add({
        'date': startDate,
        'value': currentBalanceVES / _currentRate,
      });
    }
    // Agregar punto final "ahora" para extender la línea hasta el borde derecho
    points.add({'date': now, 'value': currentBalanceVES / _currentRate});

    // Calcular Min/Max para escalar el gráfico
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (var p in points) {
      final v = p['value'] as double;
      if (v < minVal) minVal = v;
      if (v > maxVal) maxVal = v;
    }

    // Margen visual para que la línea no toque los bordes exactos
    double range = (maxVal - minVal).abs();
    if (range == 0) range = 10.0; // Evitar división por cero si es línea plana

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
          ? Center(child: CircularProgressIndicator(color: primaryGreen))
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
                      painter: _LineChartPainter(
                        data: _chartPoints,
                        minVal: _minBalance,
                        maxVal: _maxBalance,
                        lineColor: primaryGreen,
                        gradientColor: primaryGreen,
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

class _LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double minVal;
  final double maxVal;
  final Color lineColor;
  final Color gradientColor;

  _LineChartPainter({
    required this.data,
    required this.minVal,
    required this.maxVal,
    required this.lineColor,
    required this.gradientColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    final startTime = (data.first['date'] as DateTime).millisecondsSinceEpoch;
    final endTime = (data.last['date'] as DateTime).millisecondsSinceEpoch;
    final timeRange = endTime - startTime;

    Offset getOffset(int index) {
      final t = (data[index]['date'] as DateTime).millisecondsSinceEpoch;
      final v = data[index]['value'] as double;

      final x = timeRange == 0
          ? 0.0
          : ((t - startTime) / timeRange) * size.width;
      // Invert Y axis (0 is top)
      final y = size.height - ((v - minVal) / (maxVal - minVal)) * size.height;
      return Offset(x, y);
    }

    path.moveTo(getOffset(0).dx, getOffset(0).dy);
    for (int i = 1; i < data.length; i++) {
      path.lineTo(getOffset(i).dx, getOffset(i).dy);
    }

    canvas.drawPath(path, paint);

    // Gradient fill
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [gradientColor.withOpacity(0.2), gradientColor.withOpacity(0.0)],
    );

    final fillPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
