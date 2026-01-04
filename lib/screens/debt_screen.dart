import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DebtModel {
  String id;
  String title;
  double totalAmount;
  String currency;
  bool isExpense; // true = Deuda (Pagar), false = Cobro (Recibir)
  DateTime nextDate;
  int totalInstallments;
  int paidInstallments;
  bool isCompleted;

  DebtModel({
    required this.id,
    required this.title,
    required this.totalAmount,
    required this.currency,
    required this.isExpense,
    required this.nextDate,
    this.totalInstallments = 1,
    this.paidInstallments = 0,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'totalAmount': totalAmount,
    'currency': currency,
    'isExpense': isExpense,
    'nextDate': nextDate.toIso8601String(),
    'totalInstallments': totalInstallments,
    'paidInstallments': paidInstallments,
    'isCompleted': isCompleted,
  };

  factory DebtModel.fromJson(Map<String, dynamic> json) => DebtModel(
    id: json['id'],
    title: json['title'],
    totalAmount: (json['totalAmount'] ?? 0).toDouble(),
    currency: json['currency'] ?? 'USD',
    isExpense: json['isExpense'] ?? true,
    nextDate: DateTime.parse(json['nextDate']),
    totalInstallments: json['totalInstallments'] ?? 1,
    paidInstallments: json['paidInstallments'] ?? 0,
    isCompleted: json['isCompleted'] ?? false,
  );
}

class DebtScreen extends StatefulWidget {
  const DebtScreen({Key? key}) : super(key: key);

  @override
  State<DebtScreen> createState() => _DebtScreenState();
}

class _DebtScreenState extends State<DebtScreen>
    with SingleTickerProviderStateMixin {
  final Color _backgroundColor = const Color(0xFF071925);
  final Color _cardColor = const Color(0xFF132B3D);
  final Color _primaryGreen = const Color(0xFF4ADE80);
  final Color _expenseRed = const Color(0xFFFF5252);
  final Color _textGrey = const Color(0xFFB0BEC5);

  late TabController _tabController;
  List<DebtModel> _debts = [];
  bool _isLoading = true;
  double _currentBCV = 52.5; // Valor por defecto, se actualizará

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Cargar Tasa BCV para cálculos
    _currentBCV = prefs.getDouble('rate_bcv') ?? 52.5;

    final String? data = prefs.getString('debts_data');
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      _debts = decoded.map((e) => DebtModel.fromJson(e)).toList();
      // Ordenar por fecha próxima
      _debts.sort((a, b) => a.nextDate.compareTo(b.nextDate));
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveDebts() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_debts.map((e) => e.toJson()).toList());
    await prefs.setString('debts_data', encoded);
  }

  // Registra el pago en la Wallet y actualiza la deuda
  Future<void> _processPayment(DebtModel debt) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Calcular monto de la cuota
    final double installmentAmount = debt.totalAmount / debt.totalInstallments;

    // 2. Calcular valor en VES para la wallet
    double amountInVES = installmentAmount;
    double rateUsed = 1.0;
    String rateType = 'N/A';

    if (debt.currency != 'VES') {
      rateUsed = _currentBCV;
      rateType = 'BCV';
      amountInVES = installmentAmount * rateUsed;
    }

    // 3. Crear transacción en Wallet
    final String? txData = prefs.getString('transactions_data');
    List<dynamic> transactions = [];
    if (txData != null) {
      transactions = jsonDecode(txData);
    }

    final newTx = {
      'id': 'DEBT_${DateTime.now().millisecondsSinceEpoch}',
      'title':
          '${debt.isExpense ? "Pago" : "Cobro"}: ${debt.title} (${debt.paidInstallments + 1}/${debt.totalInstallments})',
      'originalAmount': installmentAmount,
      'originalCurrency': debt.currency,
      'rateType': rateType,
      'exchangeRate': rateUsed,
      'amountInVES': amountInVES,
      'isExpense':
          debt.isExpense, // Si es deuda, es gasto. Si es cobro, es ingreso.
      'date': DateTime.now().toIso8601String(),
    };

    transactions.add(newTx);
    await prefs.setString('transactions_data', jsonEncode(transactions));

    // 4. Actualizar estado de la deuda
    setState(() {
      debt.paidInstallments += 1;
      if (debt.paidInstallments >= debt.totalInstallments) {
        debt.isCompleted = true;
      } else {
        // Programar siguiente fecha (ej. +1 mes) si se desea automatizar fechas
        // Por ahora mantenemos la fecha o el usuario la edita manualmente
        debt.nextDate = debt.nextDate.add(const Duration(days: 30));
      }
    });
    _saveDebts();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            debt.isExpense ? 'Pago registrado' : 'Cobro registrado',
          ),
          backgroundColor: _primaryGreen,
        ),
      );
    }
  }

  void _deleteDebt(String id) {
    setState(() {
      _debts.removeWhere((e) => e.id == id);
    });
    _saveDebts();
  }

  void _openForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DebtForm(
        onSave: (newDebt) {
          setState(() {
            _debts.add(newDebt);
            _debts.sort((a, b) => a.nextDate.compareTo(b.nextDate));
          });
          _saveDebts();
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Programación',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _primaryGreen,
          labelColor: Colors.white,
          unselectedLabelColor: _textGrey,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Por Pagar'),
            Tab(text: 'Por Cobrar'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryGreen))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(true), // Deudas
                _buildList(false), // Cobros
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        backgroundColor: _primaryGreen,
        icon: const Icon(Icons.add_task, color: Color(0xFF071925)),
        label: Text(
          'Programar',
          style: GoogleFonts.poppins(
            color: const Color(0xFF071925),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildList(bool showExpenses) {
    final filtered = _debts
        .where((d) => d.isExpense == showExpenses && !d.isCompleted)
        .toList();
    final completed = _debts
        .where((d) => d.isExpense == showExpenses && d.isCompleted)
        .toList();

    if (filtered.isEmpty && completed.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              showExpenses ? Icons.money_off : Icons.attach_money,
              size: 60,
              color: Colors.white10,
            ),
            const SizedBox(height: 16),
            Text(
              showExpenses
                  ? 'Estás al día con tus deudas'
                  : 'No tienes cobros pendientes',
              style: GoogleFonts.poppins(color: _textGrey),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ...filtered.map((debt) => _buildDebtCard(debt)),
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Completados',
            style: GoogleFonts.poppins(
              color: _textGrey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...completed.map((debt) => _buildDebtCard(debt, isHistory: true)),
        ],
      ],
    );
  }

  Widget _buildDebtCard(DebtModel debt, {bool isHistory = false}) {
    final progress = debt.paidInstallments / debt.totalInstallments;
    final amountPerInstallment = debt.totalAmount / debt.totalInstallments;
    final color = debt.isExpense ? _expenseRed : _primaryGreen;

    return Dismissible(
      key: Key(debt.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.withOpacity(0.8),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteDebt(debt.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHistory ? Colors.white10 : color.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.title,
                        style: GoogleFonts.poppins(
                          color: isHistory ? _textGrey : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          decoration: isHistory
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      Text(
                        'Vence: ${DateFormat('dd/MM/yyyy').format(debt.nextDate)}',
                        style: GoogleFonts.poppins(
                          color: _textGrey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${debt.currency} ${debt.totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Barra de Progreso de Cuotas
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white10,
                      color: color,
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${debt.paidInstallments}/${debt.totalInstallments}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            if (!isHistory) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      _showPaymentConfirmation(debt, amountPerInstallment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color.withOpacity(0.2),
                    foregroundColor: color,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: color.withOpacity(0.5)),
                  ),
                  child: Text(
                    debt.isExpense
                        ? 'PAGAR CUOTA (${debt.currency} ${amountPerInstallment.toStringAsFixed(2)})'
                        : 'COBRAR CUOTA (${debt.currency} ${amountPerInstallment.toStringAsFixed(2)})',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showPaymentConfirmation(DebtModel debt, double amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(
          'Confirmar Movimiento',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        content: Text(
          '¿Deseas registrar este ${debt.isExpense ? "pago" : "cobro"} de ${debt.currency} ${amount.toStringAsFixed(2)} en tu billetera?',
          style: GoogleFonts.poppins(color: _textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: _textGrey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processPayment(debt);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen),
            child: Text(
              'Confirmar',
              style: const TextStyle(color: Color(0xFF071925)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtForm extends StatefulWidget {
  final Function(DebtModel) onSave;

  const _DebtForm({required this.onSave});

  @override
  State<_DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends State<_DebtForm> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _installmentsController = TextEditingController(text: '1');

  bool _isExpense = true;
  String _currency = 'USD';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 7));
  bool _hasInstallments = false;

  @override
  Widget build(BuildContext context) {
    const cardColor = Color(0xFF132B3D);
    const primaryGreen = Color(0xFF4ADE80);
    const expenseRed = Color(0xFFFF5252);

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF071925),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 4,
                width: 40,
                color: Colors.white24,
                margin: const EdgeInsets.only(bottom: 20),
              ),
            ),
            Text(
              'Nueva Programación',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Tipo
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isExpense = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isExpense ? expenseRed : Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Por Pagar',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isExpense = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isExpense ? primaryGreen : Colors.white10,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Por Cobrar',
                        style: GoogleFonts.poppins(
                          color: !_isExpense
                              ? const Color(0xFF071925)
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _titleController,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Concepto (ej. Préstamo a Juan)',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Monto Total',
                      labelStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _currency,
                        dropdownColor: cardColor,
                        items: ['VES', 'USD']
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(
                                  e,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _currency = v!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Fecha
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: Color(0xFF4ADE80),
                        onPrimary: Color(0xFF071925),
                        surface: Color(0xFF132B3D),
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Fecha de Pago/Cobro',
                      style: GoogleFonts.poppins(color: Colors.white54),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy').format(_selectedDate),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Cuotas Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Pago por Cuotas',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              value: _hasInstallments,
              onChanged: (v) => setState(() => _hasInstallments = v),
              activeColor: primaryGreen,
            ),

            if (_hasInstallments)
              TextField(
                controller: _installmentsController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.poppins(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Número de Cuotas',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (_titleController.text.isEmpty ||
                      _amountController.text.isEmpty)
                    return;

                  widget.onSave(
                    DebtModel(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: _titleController.text,
                      totalAmount: double.tryParse(_amountController.text) ?? 0,
                      currency: _currency,
                      isExpense: _isExpense,
                      nextDate: _selectedDate,
                      totalInstallments: _hasInstallments
                          ? (int.tryParse(_installmentsController.text) ?? 1)
                          : 1,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'GUARDAR',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF071925),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
