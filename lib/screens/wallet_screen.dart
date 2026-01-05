import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'recurring_transactions_screen.dart';
import 'debt_screen.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'dart:ui' as ui;

// ==========================================
// MODELO DE DATOS ACTUALIZADO (Algoritmo Generalizado)
// ==========================================

class Transaction {
  final String id;
  final String title;
  final double originalAmount;
  final String originalCurrency; // 'USD', 'EUR', 'VES'
  final String rateType; // 'BCV', 'USDT', 'EURO', 'CUSTOM'
  final double exchangeRate; // La tasa usada EN EL MOMENTO del registro

  // CAMBIO CLAVE: Almacenamos el valor base en Bolívares (Moneda Común)
  final double amountInVES;

  final bool isExpense;
  final DateTime date;

  Transaction({
    required this.id,
    required this.title,
    required this.originalAmount,
    required this.originalCurrency,
    required this.rateType,
    required this.exchangeRate,
    required this.amountInVES,
    required this.isExpense,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'originalAmount': originalAmount,
    'originalCurrency': originalCurrency,
    'rateType': rateType,
    'exchangeRate': exchangeRate,
    'amountInVES': amountInVES, // Guardamos Bs
    'isExpense': isExpense,
    'date': date.toIso8601String(),
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'],
    title: json['title'],
    originalAmount: (json['originalAmount'] ?? 0).toDouble(),
    originalCurrency: json['originalCurrency'] ?? 'VES',
    rateType: json['rateType'] ?? 'BCV',
    exchangeRate: (json['exchangeRate'] ?? 1).toDouble(),
    // Recuperamos el valor base. Si es data vieja (amountInUSD), se asume 0 o se migra.
    amountInVES: (json['amountInVES'] ?? 0).toDouble(),
    isExpense: json['isExpense'],
    date: DateTime.parse(json['date']),
  );
}

// ==========================================
// PANTALLA PRINCIPAL DE BILLETERA
// ==========================================

class WalletScreen extends StatefulWidget {
  final bool showTutorial;
  const WalletScreen({Key? key, this.showTutorial = false}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  // --- Colores del Sistema RINDE ---
  final Color _backgroundColor = const Color(0xFF071925);
  final Color _cardColor = const Color(0xFF132B3D);
  final Color _primaryGreen = const Color(0xFF4ADE80);
  final Color _expenseRed = const Color(0xFFFF5252);
  final Color _textGrey = const Color(0xFFB0BEC5);

  // --- Estado ---
  List<Transaction> _transactions = [];

  // Tasas de cambio configurables (Valores por defecto)
  final Map<String, double> _currentRates = {
    'BCV': 52.5,
    'USDT': 54.2,
    'EURO': 56.1,
    'CUSTOM': 0.0,
  };

  bool _isLoading = true;

  // --- Keys para Tutorial ---
  final GlobalKey _balanceCardKey = GlobalKey();
  final GlobalKey _listKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkRecurringTransactions();

    if (widget.showTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorial());
    }
  }

  void _showTutorial() {
    TutorialCoachMark(
      targets: [
        TargetFocus(
          identify: "Balance",
          keyTarget: _balanceCardKey,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) => _buildTutorialText(
                "Detalle Total",
                "Aquí ves el desglose completo de tu dinero. El monto grande es tu proyección en Divisas, y abajo ves la base real en Bolívares.",
              ),
            ),
          ],
          shape: ShapeLightFocus.RRect,
          radius: 20,
        ),
        TargetFocus(
          identify: "Registrar",
          keyTarget: _fabKey,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) => _buildTutorialText(
                "Nuevo Movimiento",
                "Toca aquí para registrar ingresos o gastos. Puedes especificar la moneda original y la tasa, RINDE hará el resto.",
              ),
            ),
          ],
          shape: ShapeLightFocus.Circle,
        ),
      ],
      colorShadow: const Color(0xFF071925),
      textSkip: "OMITIR",
      paddingFocus: 10,
      opacityShadow: 0.8,
      imageFilter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      onFinish: () => Navigator.pop(context, 'next'), // Continuar a Analíticas
      onSkip: () {
        Navigator.pop(context, 'skip'); // Cancelar tour
        return true;
      },
      onClickTarget: (target) {},
      onClickOverlay: (target) {},
    ).show(context: context);
  }

  /// Carga datos y configuración
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Cargar Transacciones
    final String? data = prefs.getString('transactions_data');
    List<Transaction> loadedTransactions = [];
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      loadedTransactions = decoded.map((e) => Transaction.fromJson(e)).toList();
      loadedTransactions.sort((a, b) => b.date.compareTo(a.date));
    }

    // 2. Cargar Tasas Configuradas
    final double? bcv = prefs.getDouble('rate_bcv');
    final double? usdt = prefs.getDouble('rate_usdt');
    final double? euro = prefs.getDouble('rate_euro');
    final double? custom = prefs.getDouble('rate_custom');

    setState(() {
      _transactions = loadedTransactions;
      if (bcv != null) _currentRates['BCV'] = bcv;
      if (usdt != null) _currentRates['USDT'] = usdt;
      if (euro != null) _currentRates['EURO'] = euro;
      if (custom != null) _currentRates['CUSTOM'] = custom;
      _isLoading = false;
    });
  }

  /// MOTOR DE AUTOMATIZACIÓN
  /// Verifica si hay pagos programados pendientes y los ejecuta
  Future<void> _checkRecurringTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recurringData = prefs.getString('recurring_transactions');

    if (recurringData == null) return;

    List<dynamic> decoded = jsonDecode(recurringData);
    List<RecurringTransaction> recurringItems = decoded
        .map((e) => RecurringTransaction.fromJson(e))
        .toList();
    bool changesMade = false;
    int executedCount = 0;

    final now = DateTime.now();

    for (var item in recurringItems) {
      if (!item.active) continue;

      // Si la fecha de ejecución ya pasó o es hoy
      if (item.nextExecution.isBefore(now) ||
          item.nextExecution.isAtSameMomentAs(now)) {
        // 1. Calcular Monto en VES
        double amountInVES = 0.0;
        double rateUsed = 1.0;
        String rateType = 'N/A';

        if (item.currency == 'VES') {
          amountInVES = item.amount;
        } else {
          // Usar tasa BCV por defecto para automatizaciones
          rateUsed = _currentRates['BCV'] ?? 52.5;
          rateType = 'BCV';

          if (item.isIndexed) {
            // Si es indexado, el registro es en VES calculado
            amountInVES = item.amount * rateUsed;
          } else {
            // Si es moneda extranjera pura, el sistema calcula VES internamente
            amountInVES = item.amount * rateUsed;
          }
        }

        // 2. Crear Transacción Real
        final newTx = Transaction(
          id: 'AUTO_${DateTime.now().millisecondsSinceEpoch}_$executedCount',
          title: '${item.title} (Auto)',
          originalAmount: item.isIndexed
              ? amountInVES
              : item.amount, // Si es indexado, guardamos el VES resultante como original
          originalCurrency: item.isIndexed ? 'VES' : item.currency,
          rateType: rateType,
          exchangeRate: rateUsed,
          amountInVES: amountInVES,
          isExpense: item.isExpense,
          date: DateTime.now(),
        );

        _transactions.insert(0, newTx);

        // 3. Calcular Siguiente Fecha
        DateTime next = item.nextExecution;
        if (item.frequencyType == 'DAYS') {
          next = next.add(Duration(days: item.frequencyValue));
        } else if (item.frequencyType == 'WEEKLY') {
          next = next.add(const Duration(days: 7));
        } else {
          // Mensual simple: sumar 30 días aprox o lógica de mes real
          // Para simplificar en ejecución automática, sumamos días del mes actual
          final daysInMonth = DateTime(next.year, next.month + 1, 0).day;
          next = next.add(Duration(days: daysInMonth));
        }

        // Asegurar que la próxima fecha sea en el futuro (por si la app estuvo cerrada mucho tiempo)
        while (next.isBefore(now)) {
          next = next.add(const Duration(days: 1)); // Fallback simple
        }

        item.nextExecution = next;
        changesMade = true;
        executedCount++;
      }
    }

    if (changesMade) {
      // Guardar Transacciones
      await _saveTransactions();

      // Guardar Automatizaciones Actualizadas
      final String encodedRecurring = jsonEncode(
        recurringItems.map((e) => e.toJson()).toList(),
      );
      await prefs.setString('recurring_transactions', encodedRecurring);

      setState(() {}); // Refrescar UI

      if (mounted && executedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Se ejecutaron $executedCount pagos automáticos'),
            backgroundColor: _primaryGreen,
          ),
        );
      }
    }
  }

  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      _transactions.map((e) => e.toJson()).toList(),
    );
    await prefs.setString('transactions_data', encoded);
  }

  Future<void> _saveCustomRate(double customRate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('rate_custom', customRate);
    setState(() {
      _currentRates['CUSTOM'] = customRate;
    });
  }

  /// ALGORITMO: Cálculo del Saldo Neto en Bolívares (Moneda Común)
  double get _totalBalanceVES {
    double total = 0;
    for (var t in _transactions) {
      if (t.isExpense) {
        total -= t.amountInVES;
      } else {
        total += t.amountInVES;
      }
    }
    return total;
  }

  /// Proyección: Convierte el saldo total en Bs a la moneda deseada usando la tasa ACTUAL
  double _projectBalanceTo(String rateKey) {
    final rate = _currentRates[rateKey] ?? 1.0;
    if (rate == 0) return 0;
    return _totalBalanceVES / rate;
  }

  void _deleteTransaction(String id) {
    setState(() {
      _transactions.removeWhere((t) => t.id == id);
    });
    _saveTransactions();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Transacción eliminada', style: GoogleFonts.poppins()),
        backgroundColor: _expenseRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // --- Diálogo de Configuración de Tasas ---
  void _showRateConfigDialog() {
    final customController = TextEditingController(
      text: (_currentRates['CUSTOM'] ?? 0).toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Tasas de Cambio',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReadOnlyRate('BCV', _currentRates['BCV']),
            const SizedBox(height: 8),
            _buildReadOnlyRate('USDT', _currentRates['USDT']),
            const SizedBox(height: 8),
            _buildReadOnlyRate('EURO', _currentRates['EURO']),
            const SizedBox(height: 8),
            _buildRateInput(customController, 'Tasa Personalizada'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(color: _textGrey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final custom = double.tryParse(customController.text) ?? 0.0;
              _saveCustomRate(custom);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen),
            child: Text(
              'Guardar',
              style: GoogleFonts.poppins(
                color: const Color(0xFF132B3D),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyRate(String label, double? value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(color: _textGrey)),
          Row(
            children: [
              Icon(Icons.cloud_sync, size: 14, color: _primaryGreen),
              const SizedBox(width: 6),
              Text(
                'Bs ${value?.toStringAsFixed(2) ?? '0.00'}',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRateInput(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GoogleFonts.poppins(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _textGrey),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _primaryGreen),
        ),
        suffixText: 'Bs',
        suffixStyle: TextStyle(color: _textGrey),
      ),
    );
  }

  void _openTransactionForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TransactionForm(
        backgroundColor: _backgroundColor,
        cardColor: _cardColor,
        primaryGreen: _primaryGreen,
        expenseRed: _expenseRed,
        textGrey: _textGrey,
        rates: _currentRates,
        onSave: (transaction) {
          setState(() {
            _transactions.insert(0, transaction);
          });
          _saveTransactions();
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Billetera Indexada',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DebtScreen()),
            ).then((_) => _loadData()),
          ),
          IconButton(
            icon: const Icon(Icons.autorenew, color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RecurringTransactionsScreen(),
              ),
            ).then((_) => _checkRecurringTransactions()),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: _showRateConfigDialog,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryGreen))
          : Column(
              children: [
                Container(key: _balanceCardKey, child: _buildBalanceCard()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Historial (Base Bs)',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.filter_list, color: _textGrey),
                    ],
                  ),
                ),
                Expanded(
                  child: _transactions.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _transactions.length,
                          itemBuilder: (context, index) {
                            final transaction = _transactions[index];
                            return _buildTransactionItem(transaction);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        key: _fabKey,
        onPressed: _openTransactionForm,
        backgroundColor: _primaryGreen,
        icon: const Icon(Icons.add, color: Color(0xFF132B3D)),
        label: Text(
          'Registrar',
          style: GoogleFonts.poppins(
            color: const Color(0xFF132B3D),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // Tarjeta que muestra el "Saldo al cambio de hoy"
  Widget _buildBalanceCard() {
    // Proyección principal en Dólares (BCV o USDT según preferencia, usamos BCV por defecto)
    final double projectedUSD = _projectBalanceTo('BCV');
    final currencyFormatter = NumberFormat.currency(
      symbol: 'Bs ',
      decimalDigits: 2,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Proyección al Cambio (BCV)',
            style: GoogleFonts.poppins(color: _textGrey, fontSize: 14),
          ),
          const SizedBox(height: 8),
          // Mostramos GRANDE el valor en Dólares (lo que le importa al usuario)
          Text(
            '\$${projectedUSD.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Mostramos PEQUEÑO el Saldo Real en Bolívares (La base del algoritmo)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _primaryGreen.withOpacity(0.3)),
            ),
            child: Text(
              'Base Contable: ${currencyFormatter.format(_totalBalanceVES)}',
              style: GoogleFonts.poppins(
                color: _primaryGreen,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Desglose de Tasas (Como pide el algoritmo)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMiniProjection('USDT', '\$', _projectBalanceTo('USDT')),
                const SizedBox(width: 24),
                _buildMiniProjection('EURO', '€', _projectBalanceTo('EURO')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniProjection(String label, String symbol, double amount) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.poppins(color: _textGrey, fontSize: 10)),
        Text(
          '$symbol${amount.toStringAsFixed(2)}',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionItem(Transaction t) {
    final originalFormat = NumberFormat.currency(
      symbol: t.originalCurrency == 'VES'
          ? 'Bs '
          : (t.originalCurrency == 'EUR' ? '€ ' : '\$ '),
      decimalDigits: 2,
    );

    final vesFormat = NumberFormat.currency(symbol: 'Bs ', decimalDigits: 2);

    return Dismissible(
      key: Key(t.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteTransaction(t.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _expenseRed.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.isExpense
                    ? _expenseRed.withOpacity(0.1)
                    : _primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                t.isExpense ? Icons.arrow_upward : Icons.arrow_downward,
                color: t.isExpense ? _expenseRed : _primaryGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // Muestra qué se ingresó originalmente
                  Row(
                    children: [
                      Text(
                        originalFormat.format(t.originalAmount),
                        style: GoogleFonts.poppins(
                          color: _textGrey,
                          fontSize: 12,
                        ),
                      ),
                      if (t.originalCurrency != 'VES') ...[
                        const SizedBox(width: 4),
                        Text(
                          '@ ${t.exchangeRate}',
                          style: GoogleFonts.poppins(
                            color: _textGrey.withOpacity(0.5),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Muestra el impacto real en Bolívares
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${t.isExpense ? "-" : "+"}${vesFormat.format(t.amountInVES)}',
                  style: GoogleFonts.poppins(
                    color: t.isExpense ? _expenseRed : _primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Base Bs',
                  style: GoogleFonts.poppins(color: _textGrey, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: _textGrey.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin registros aún',
            style: GoogleFonts.poppins(color: _textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialText(String title, String desc) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          desc,
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16),
        ),
      ],
    );
  }
}

// ==========================================
// FORMULARIO DE REGISTRO (Conversión Inmediata)
// ==========================================

class _TransactionForm extends StatefulWidget {
  final Color backgroundColor;
  final Color cardColor;
  final Color primaryGreen;
  final Color expenseRed;
  final Color textGrey;
  final Map<String, double> rates;
  final Function(Transaction) onSave;

  const _TransactionForm({
    required this.backgroundColor,
    required this.cardColor,
    required this.primaryGreen,
    required this.expenseRed,
    required this.textGrey,
    required this.rates,
    required this.onSave,
  });

  @override
  State<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<_TransactionForm> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _customRateController = TextEditingController();

  bool _isExpense = true;
  String _selectedCurrency = 'VES'; // Moneda de entrada
  String _selectedRateType = 'BCV'; // Tasa a usar para la conversión

  // Obtiene la tasa seleccionada para el cálculo
  double get _currentRate {
    if (_selectedRateType == 'MANUAL') {
      return double.tryParse(_customRateController.text) ?? 1.0;
    }
    if (_selectedRateType == 'PERSONAL') {
      return widget.rates['CUSTOM'] ?? 1.0;
    }
    // Si la moneda es VES, la tasa es 1 (1 Bs = 1 Bs)
    if (_selectedCurrency == 'VES') return 1.0;

    return widget.rates[_selectedRateType] ?? 1.0;
  }

  // ALGORITMO DE CONVERSIÓN INMEDIATA
  double get _calculatedVES {
    final amount = double.tryParse(_amountController.text) ?? 0.0;

    if (_selectedCurrency == 'VES') {
      return amount; // Si entra en Bs, son Bs.
    } else {
      // Si entra en Divisa, se multiplica por la tasa para obtener Bs.
      // Ej: 100 USD * 52.5 Tasa = 5250 Bs.
      return amount * _currentRate;
    }
  }

  void _submit() {
    if (_titleController.text.isEmpty || _amountController.text.isEmpty) return;

    final originalAmount = double.parse(_amountController.text);

    final transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text,
      originalAmount: originalAmount,
      originalCurrency: _selectedCurrency,
      rateType: _selectedCurrency == 'VES' ? 'N/A' : _selectedRateType,
      exchangeRate: _currentRate,
      amountInVES: _calculatedVES, // GUARDAMOS EN MONEDA COMÚN
      isExpense: _isExpense,
      date: DateTime.now(),
    );

    widget.onSave(transaction);
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _isExpense ? widget.expenseRed : widget.primaryGreen;

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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

          // 1. Tipo (Ingreso / Gasto)
          Row(
            children: [
              Expanded(child: _buildTypeSelector('Gasto', true)),
              const SizedBox(width: 16),
              Expanded(child: _buildTypeSelector('Ingreso', false)),
            ],
          ),

          const SizedBox(height: 24),

          // 2. Input Monto y Moneda
          Text(
            'Monto Original',
            style: GoogleFonts.poppins(color: widget.textGrey),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: GoogleFonts.poppins(color: Colors.white24),
                    filled: true,
                    fillColor: widget.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: widget.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCurrency,
                      dropdownColor: widget.cardColor,
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                      ),
                      items: ['VES', 'USD', 'EUR'].map((String val) {
                        return DropdownMenuItem(
                          value: val,
                          child: Text(
                            val,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedCurrency = val!;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 3. Selección de Tasa (Solo si NO es VES)
          if (_selectedCurrency != 'VES') ...[
            Text(
              'Tasa de Conversión (a Bolívares)',
              style: GoogleFonts.poppins(color: widget.textGrey),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildRateChip('BCV', widget.rates['BCV'] ?? 0),
                  _buildRateChip('USDT', widget.rates['USDT'] ?? 0),
                  _buildRateChip('EURO', widget.rates['EURO'] ?? 0),
                  if ((widget.rates['CUSTOM'] ?? 0) > 0)
                    _buildRateChip('PERSONAL', widget.rates['CUSTOM'] ?? 0),
                  _buildRateChip('MANUAL', 0),
                ],
              ),
            ),

            if (_selectedRateType == 'MANUAL')
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: TextField(
                  controller: _customRateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Ingresa tasa manual',
                    labelStyle: TextStyle(color: widget.textGrey),
                    filled: true,
                    fillColor: widget.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixText: 'Bs',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
          ],

          const SizedBox(height: 16),

          // 4. Previsualización de Conversión
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: activeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: activeColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Registro Contable (Base):',
                  style: GoogleFonts.poppins(
                    color: widget.textGrey,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Bs. ${_calculatedVES.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    color: activeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 5. Concepto
          TextField(
            controller: _titleController,
            style: GoogleFonts.poppins(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Concepto (ej. Pago Móvil, Zelle)',
              hintStyle: GoogleFonts.poppins(color: Colors.white24),
              filled: true,
              fillColor: widget.cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Botón Guardar
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: activeColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'REGISTRAR MOVIMIENTO',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF132B3D),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(String label, bool isExpenseValue) {
    final isSelected = _isExpense == isExpenseValue;
    final color = isExpenseValue ? widget.expenseRed : widget.primaryGreen;

    return GestureDetector(
      onTap: () => setState(() => _isExpense = isExpenseValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : widget.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white10,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? const Color(0xFF132B3D) : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildRateChip(String label, double rate) {
    final isSelected = _selectedRateType == label;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedRateType = label;
      }),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? widget.primaryGreen : widget.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? widget.primaryGreen : Colors.white24,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? const Color(0xFF132B3D) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            if (rate > 0)
              Text(
                rate.toString(),
                style: GoogleFonts.poppins(
                  color: isSelected
                      ? const Color(0xFF132B3D).withOpacity(0.7)
                      : widget.textGrey,
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
