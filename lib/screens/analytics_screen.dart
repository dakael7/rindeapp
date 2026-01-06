import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/transaction_model.dart';

// Modelo local para analíticas que soporta la separación de efectivo
class _AnalyticsItem {
  final DateTime date;
  final double amountVES;
  final double amountCash;
  final bool isPositive;
  final String categoryName;
  final int categoryColor;
  final String title;

  _AnalyticsItem(
    this.date,
    this.amountVES,
    this.amountCash,
    this.isPositive,
    this.categoryName,
    this.categoryColor,
    this.title,
  );
}

class _CategorySummary {
  final String name;
  final int color;
  double totalAmount;
  final List<_AnalyticsItem> transactions;
  _CategorySummary(this.name, this.color)
    : totalAmount = 0.0,
      transactions = [];
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;

  // Datos
  List<_AnalyticsItem> _allTransactions = [];
  double _currentRate = 1.0; // Tasa para visualizar en USD
  bool _showCashWallet = false; // Toggle para ver Efectivo o Digital

  // Filtros
  String _selectedPeriod = '1M';
  final List<String> _periods = ['1S', '1M', '3M', '6M', '1A', 'TODO'];

  // Datos Visuales
  double _periodIncome = 0.0;
  double _periodExpense = 0.0;
  List<Map<String, dynamic>> _chartPoints = [];
  double _minBalance = 0.0;
  double _maxBalance = 1.0;
  List<_CategorySummary> _categoryStats = [];

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
    List<_AnalyticsItem> transactions = [];

    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      transactions = decoded.map((item) {
        final double amountVES = (item['amountInVES'] ?? 0).toDouble();
        final String origCurrency = item['originalCurrency'] ?? 'VES';
        final double origAmount = (item['originalAmount'] ?? 0).toDouble();
        final bool isExpense = item['isExpense'] ?? true;
        final DateTime date = DateTime.parse(item['date']);
        final String categoryName = item['categoryName'] ?? 'General';
        final int categoryColor = item['categoryColor'] ?? 0xFF90A4AE;
        final String title = item['title'] ?? 'Movimiento';

        double finalVES = 0.0;
        double finalCash = 0.0;

        if (origCurrency == 'USD_CASH') {
          finalCash = origAmount;
        } else {
          finalVES = amountVES;
        }

        return _AnalyticsItem(
          date,
          finalVES,
          finalCash,
          !isExpense,
          categoryName,
          categoryColor,
          title,
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
    double currentBalanceCash = 0;
    Map<String, _CategorySummary> catMap = {};

    // 1. Calcular balance inicial antes del periodo seleccionado
    int txIndex = 0;
    while (txIndex < _allTransactions.length &&
        _allTransactions[txIndex].date.isBefore(startDate)) {
      final t = _allTransactions[txIndex];
      if (t.isPositive) {
        currentBalanceVES += t.amountVES;
        currentBalanceCash += t.amountCash;
      } else {
        currentBalanceVES -= t.amountVES;
        currentBalanceCash -= t.amountCash;
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
          currentBalanceVES += t.amountVES;
          currentBalanceCash += t.amountCash;

          if (_showCashWallet) {
            income += t.amountCash;
          } else {
            income += (t.amountVES / _currentRate);
          }
        } else {
          currentBalanceVES -= t.amountVES;
          currentBalanceCash -= t.amountCash;

          if (_showCashWallet) {
            expense += t.amountCash;
            // Sumar a categoría si es gasto
            if (t.amountCash > 0) {
              catMap.putIfAbsent(
                t.categoryName,
                () => _CategorySummary(t.categoryName, t.categoryColor),
              );
              catMap[t.categoryName]!.totalAmount += t.amountCash;
              catMap[t.categoryName]!.transactions.add(t);
            }
          } else {
            double val = t.amountVES / _currentRate;
            expense += val;
            if (val > 0) {
              catMap.putIfAbsent(
                t.categoryName,
                () => _CategorySummary(t.categoryName, t.categoryColor),
              );
              catMap[t.categoryName]!.totalAmount += val;
              catMap[t.categoryName]!.transactions.add(t);
            }
          }
        }
        txIndex++;
      }

      double valueToShow = 0.0;
      if (_showCashWallet) {
        valueToShow = currentBalanceCash;
      } else {
        valueToShow = currentBalanceVES / _currentRate;
      }

      points.add({
        'date': cursor,
        'value': valueToShow,
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

    // Ordenar categorías por monto descendente
    List<_CategorySummary> sortedCats = catMap.values.toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    setState(() {
      _periodIncome = income;
      _periodExpense = expense;
      _chartPoints = points;
      _minBalance = minVal - (range * 0.2);
      _maxBalance = maxVal + (range * 0.2);
      _categoryStats = sortedCats;
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
                  // Selector de Billetera (Digital vs Efectivo)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _WalletTypeButton(
                            label: 'Digital (Bs)',
                            isSelected: !_showCashWallet,
                            onTap: () => setState(() {
                              _showCashWallet = false;
                              _applyFilter();
                            }),
                          ),
                        ),
                        Expanded(
                          child: _WalletTypeButton(
                            label: 'Efectivo (\$)',
                            isSelected: _showCashWallet,
                            onTap: () => setState(() {
                              _showCashWallet = true;
                              _applyFilter();
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

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
                      size: Size.infinite,
                      painter: _BarChartPainter(
                        data: _chartPoints,
                        minVal: _minBalance,
                        maxVal: _maxBalance,
                        barColor: primaryGreen,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Gráfico de Categorías (Pie Chart)
                  if (_categoryStats.isNotEmpty) ...[
                    Text(
                      'Distribución de Gastos',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _CategoryPieChart(
                      data: _categoryStats,
                      onTap: _showCategoryDetails,
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  void _showCategoryDetails(_CategorySummary category) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF071925),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Color(category.color).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.category, color: Color(category.color)),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Total: \$${category.totalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: category.transactions.length,
                itemBuilder: (context, index) {
                  final t = category.transactions[index];
                  final amount = _showCashWallet
                      ? t.amountCash
                      : (t.amountVES / _currentRate);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.receipt_long, color: Colors.white54),
                    title: Text(
                      t.title,
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy').format(t.date),
                      style: GoogleFonts.poppins(color: Colors.white24),
                    ),
                    trailing: Text(
                      '\$${amount.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFFF5252),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletTypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _WalletTypeButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4ADE80) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? const Color(0xFF071925) : Colors.white54,
            fontWeight: FontWeight.bold,
          ),
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

class _CategoryPieChart extends StatelessWidget {
  final List<_CategorySummary> data;
  final Function(_CategorySummary) onTap;

  const _CategoryPieChart({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    double total = data.fold(0, (sum, item) => sum + item.totalAmount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF132B3D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            width: 200,
            child: GestureDetector(
              onTapUp: (details) {
                _handleTap(details, context, total);
              },
              child: CustomPaint(
                painter: _PieChartPainter(data: data, total: total),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Leyenda
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: data.map((cat) {
              final percent = (cat.totalAmount / total * 100).toStringAsFixed(
                1,
              );
              return GestureDetector(
                onTap: () => onTap(cat),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Color(cat.color),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${cat.name} ($percent%)',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _handleTap(TapUpDetails details, BuildContext context, double total) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset localOffset = details.localPosition;
    final Offset center = Offset(100, 100); // Radio es 100 (mitad de 200)

    // Calcular ángulo
    final double dx = localOffset.dx - center.dx;
    final double dy = localOffset.dy - center.dy;
    double angle = math.atan2(dy, dx); // -PI a PI
    if (angle < 0) angle += 2 * math.pi; // 0 a 2PI

    // Encontrar categoría
    double startAngle = -math.pi / 2; // Empezamos arriba
    if (startAngle < 0) startAngle += 2 * math.pi; // Normalizar inicio

    // Ajustar ángulo del toque para coincidir con el inicio del dibujo (-PI/2)
    double touchAngle = angle + (math.pi / 2);
    if (touchAngle >= 2 * math.pi) touchAngle -= 2 * math.pi;

    double currentAngle = 0;
    for (var cat in data) {
      final sweepAngle = (cat.totalAmount / total) * 2 * math.pi;
      if (touchAngle >= currentAngle &&
          touchAngle < currentAngle + sweepAngle) {
        onTap(cat);
        break;
      }
      currentAngle += sweepAngle;
    }
  }
}

class _PieChartPainter extends CustomPainter {
  final List<_CategorySummary> data;
  final double total;

  _PieChartPainter({required this.data, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2);
    final strokeWidth = 30.0;

    double startAngle = -math.pi / 2;

    for (var cat in data) {
      final sweepAngle = (cat.totalAmount / total) * 2 * math.pi;
      final paint = Paint()
        ..color = Color(cat.color)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
