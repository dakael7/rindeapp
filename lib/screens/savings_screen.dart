import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'wallet_screen.dart';
import '../utils/rate_helper.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({Key? key}) : super(key: key);

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  final Color _backgroundColor = const Color(0xFF071925);
  final Color _cardColor = const Color(0xFF132B3D);
  final Color _primaryGreen = const Color(0xFF4ADE80);
  final Color _expenseRed = const Color(0xFFFF5252);
  final Color _textGrey = const Color(0xFFB0BEC5);

  List<Map<String, dynamic>> _goals = [];
  Map<String, double> _rates = {};
  Map<String, Map<String, dynamic>> _pendingRates = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    // Usar RateHelper para obtener tasas y procesar vigencias
    final bcv = await RateHelper.getRateInfo('BCV');
    final euro = await RateHelper.getRateInfo('EURO');
    final usdt = await RateHelper.getRateInfo('USDT');
    final custom = await RateHelper.getRateInfo('CUSTOM');

    setState(() {
      _rates = {
        'BCV': bcv['current'],
        'USDT': usdt['current'],
        'EURO': euro['current'],
        'CUSTOM': custom['current'],
      };
      _pendingRates = {
        'BCV': {'rate': bcv['pending'], 'date': bcv['validFrom']},
        'EURO': {'rate': euro['pending'], 'date': euro['validFrom']},
      };

      final String? data = prefs.getString('savings_data');
      if (data != null) {
        _goals = List<Map<String, dynamic>>.from(jsonDecode(data));
      }
    });
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('savings_data', jsonEncode(_goals));
  }

  void _addGoal(String name, double target, String currency, String rateType) {
    setState(() {
      _goals.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': name,
        'targetAmount': target,
        'currentAmount': 0.0,
        'currency': currency,
        'rateType': rateType,
        'icon': 0xe4f8, // Icons.savings
        'color': 0xFF4ADE80,
      });
    });
    _saveGoals();
  }

  void _deleteGoal(int index) {
    setState(() {
      _goals.removeAt(index);
    });
    _saveGoals();
  }

  Future<void> _handleTransaction(int index, double goalAmount,
      double walletAmount, String walletKey, bool isDeposit) async {
    setState(() {
      double current = (_goals[index]['currentAmount'] ?? 0).toDouble();
      if (isDeposit) {
        current += goalAmount;
      } else {
        current -= goalAmount;
      }
      if (current < 0) current = 0;
      _goals[index]['currentAmount'] = current;
    });
    _saveGoals();

    // Actualizar Billetera correspondiente
    if (walletKey.isNotEmpty && walletAmount > 0) {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString('transactions_data');
      List<Transaction> transactions = [];
      if (data != null) {
        final List<dynamic> decoded = jsonDecode(data);
        transactions = decoded.map((e) => Transaction.fromJson(e)).toList();
      }

      final newTx = Transaction(
        id: 'SAVING_${DateTime.now().millisecondsSinceEpoch}',
        title: isDeposit
            ? 'Abono a Meta: ${_goals[index]['name']}'
            : 'Retiro de Meta: ${_goals[index]['name']}',
        originalAmount: walletAmount,
        originalCurrency: walletKey == 'balance_cash' ? 'USD_CASH' : 'VES',
        rateType: walletKey == 'balance_cash' ? 'CASH' : 'N/A',
        exchangeRate: 1.0,
        amountInVES: walletAmount,
        isExpense: isDeposit,
        date: DateTime.now(),
        categoryName: 'Ahorro',
        categoryColor: 0xFF4ADE80,
      );

      transactions.insert(0, newTx);
      final String encoded = jsonEncode(
        transactions.map((e) => e.toJson()).toList(),
      );
      await prefs.setString('transactions_data', encoded);
    }
  }

  void _showAddGoalDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    String goalCurrency = 'USD';
    String selectedRateType = 'BCV';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: _cardColor,
            title: Text('Nueva Meta',
                style: GoogleFonts.poppins(color: Colors.white)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nombre de la meta',
                      labelStyle: TextStyle(color: _textGrey),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: _textGrey)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: _primaryGreen)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          style: GoogleFonts.poppins(color: Colors.white),
                          onChanged: (_) => setDialogState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Monto Objetivo',
                            labelStyle: TextStyle(color: _textGrey),
                            enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: _textGrey)),
                            focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: _primaryGreen)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            border:
                                Border(bottom: BorderSide(color: _textGrey)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: goalCurrency,
                              dropdownColor: _cardColor,
                              isExpanded: true,
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  color: Colors.white),
                              items: ['USD', 'VES', 'USD_CASH'].map((val) {
                                String label = val;
                                if (val == 'USD') label = 'USD (Indexado a Bs)';
                                if (val == 'VES') label = 'Bolívares (Bs)';
                                if (val == 'USD_CASH') label = 'USD Efectivo';
                                return DropdownMenuItem(
                                  value: val,
                                  child: Text(label,
                                      style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setDialogState(() {
                                  goalCurrency = val!;
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (goalCurrency == 'USD') ...[
                    const SizedBox(height: 16),
                    Text('Tasa de Indexación',
                        style: GoogleFonts.poppins(
                            color: _textGrey, fontSize: 12)),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children:
                            ['BCV', 'USDT', 'EURO', 'CUSTOM'].map((rateKey) {
                          final isSelected = selectedRateType == rateKey;
                          final rateVal = _rates[rateKey] ?? 0.0;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedRateType = rateKey;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _primaryGreen
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: isSelected
                                        ? _primaryGreen
                                        : Colors.white24),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    rateKey == 'CUSTOM' ? 'PERS.' : rateKey,
                                    style: GoogleFonts.poppins(
                                      color: isSelected
                                          ? const Color(0xFF132B3D)
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    rateVal.toStringAsFixed(2),
                                    style: GoogleFonts.poppins(
                                      color: isSelected
                                          ? const Color(0xFF132B3D)
                                              .withOpacity(0.7)
                                          : _textGrey,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar',
                    style: GoogleFonts.poppins(color: _textGrey)),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text;
                  final amount = double.tryParse(amountController.text) ?? 0.0;
                  if (name.isNotEmpty && amount > 0) {
                    _addGoal(name, amount, goalCurrency, selectedRateType);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen),
                child: Text('Crear',
                    style: GoogleFonts.poppins(
                        color: const Color(0xFF132B3D),
                        fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTransactionDialog(int index, bool isDeposit) {
    final goal = _goals[index];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SavingsTransactionModal(
        isDeposit: isDeposit,
        goalName: goal['name'],
        goalCurrency: goal['currency'] ?? 'USD',
        goalRateType: goal['rateType'],
        rates: _rates,
        pendingRates: _pendingRates,
        onConfirm: (double goalAmount, double walletAmount, String walletKey) {
          _handleTransaction(
              index, goalAmount, walletAmount, walletKey, isDeposit);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(isDeposit ? 'Abono registrado' : 'Retiro registrado'),
              backgroundColor: isDeposit ? _primaryGreen : _expenseRed,
            ),
          );
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
          'Mi Alcancía',
          style: GoogleFonts.poppins(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _goals.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.savings_outlined,
                      size: 80, color: _textGrey.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text('No tienes metas de ahorro',
                      style: GoogleFonts.poppins(color: _textGrey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _goals.length,
              itemBuilder: (context, index) {
                final goal = _goals[index];
                final current = (goal['currentAmount'] ?? 0).toDouble();
                final target = (goal['targetAmount'] ?? 0).toDouble();
                final progress = (current / target).clamp(0.0, 1.0);
                final percent = (progress * 100).toStringAsFixed(1);
                final currency = goal['currency'] ?? 'USD';
                final symbol = currency == 'VES' ? 'Bs' : '\$';

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
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
                                  goal['name'],
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '$symbol${current.toStringAsFixed(2)} / $symbol${target.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(
                                      color: _textGrey, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: _expenseRed.withOpacity(0.7)),
                            onPressed: () => _deleteGoal(index),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.black26,
                        color: _primaryGreen,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$percent%',
                          style: GoogleFonts.poppins(
                              color: _primaryGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _showTransactionDialog(index, true),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Abonar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryGreen.withOpacity(0.2),
                                foregroundColor: _primaryGreen,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  _showTransactionDialog(index, false),
                              icon: const Icon(Icons.remove, size: 18),
                              label: const Text('Retirar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _expenseRed.withOpacity(0.2),
                                foregroundColor: _expenseRed,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGoalDialog,
        backgroundColor: _primaryGreen,
        child: const Icon(Icons.add, color: Color(0xFF132B3D)),
      ),
    );
  }
}

class _SavingsTransactionModal extends StatefulWidget {
  final bool isDeposit;
  final String goalName;
  final String goalCurrency;
  final String? goalRateType;
  final Map<String, double> rates;
  final Map<String, Map<String, dynamic>> pendingRates;
  final Function(double, double, String)
      onConfirm; // goalAmount, walletAmount, walletKey

  const _SavingsTransactionModal({
    Key? key,
    required this.isDeposit,
    required this.goalName,
    required this.goalCurrency,
    this.goalRateType,
    required this.rates,
    required this.pendingRates,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<_SavingsTransactionModal> createState() =>
      _SavingsTransactionModalState();
}

class _SavingsTransactionModalState extends State<_SavingsTransactionModal> {
  final _amountController = TextEditingController();
  String _selectedRateType = 'BCV';
  double _calculatedGoalAmount = 0.0;
  double _calculatedWalletAmount = 0.0;
  String _targetWalletKey = '';
  bool _usePendingRate = false;

  @override
  void initState() {
    super.initState();
    if (widget.goalRateType != null) {
      _selectedRateType = widget.goalRateType!;
    }
  }

  void _calculate() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount == 0) {
      setState(() {
        _calculatedGoalAmount = 0.0;
        _calculatedWalletAmount = 0.0;
      });
      return;
    }

    // Lógica corregida según requerimiento:
    if (widget.goalCurrency == 'USD') {
      // USD INDEXADO:
      // Input: USD
      // Meta: Se suma/resta el input en USD.
      // Billetera (VES): Se descuenta/suma el equivalente en Bs (Input * Tasa).
      double rate = widget.rates[_selectedRateType] ?? 0.0;

      // Si el usuario eligió usar la tasa pendiente
      if (_usePendingRate) {
        final pending = widget.pendingRates[_selectedRateType];
        if (pending != null && pending['rate'] != null) {
          rate = pending['rate'];
        }
      }

      final effectiveRate = rate > 0 ? rate : 1.0;

      setState(() {
        _calculatedGoalAmount = amount;
        _calculatedWalletAmount = amount * effectiveRate;
        _targetWalletKey = 'balance_ves';
      });
    } else if (widget.goalCurrency == 'VES') {
      // BS (BOLIVARES):
      // Input: Bs
      // Meta: Se suma/resta el input en Bs.
      // Billetera (VES): Se descuenta/suma el input en Bs.
      setState(() {
        _calculatedGoalAmount = amount;
        _calculatedWalletAmount = amount;
        _targetWalletKey = 'balance_ves';
      });
    } else {
      // USD EFECTIVO:
      // Input: USD
      // Meta: Se suma/resta el input en USD.
      // Billetera (CASH): Se descuenta/suma el input en USD.
      setState(() {
        _calculatedGoalAmount = amount;
        _calculatedWalletAmount = amount;
        _targetWalletKey = 'balance_cash';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.isDeposit ? const Color(0xFF4ADE80) : const Color(0xFFFF5252);
    final action = widget.isDeposit ? 'Abonar' : 'Retirar';
    final goalSymbol = widget.goalCurrency == 'VES' ? 'Bs' : '\$';
    final walletSymbol = widget.goalCurrency == 'USD_CASH'
        ? '\$'
        : (widget.goalCurrency == 'USD' ? 'Bs' : 'Bs');

    String inputLabel = 'Monto';
    if (widget.goalCurrency == 'USD')
      inputLabel = 'Monto en USD';
    else if (widget.goalCurrency == 'VES')
      inputLabel = 'Monto en Bs';
    else
      inputLabel = 'Monto en USD Efectivo';

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$action a ${widget.goalName}',
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Amount & Currency
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    labelText: inputLabel,
                    labelStyle: TextStyle(color: const Color(0xFFB0BEC5)),
                    hintStyle: GoogleFonts.poppins(color: Colors.white24),
                    filled: true,
                    fillColor: const Color(0xFF132B3D),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                  onChanged: (_) => _calculate(),
                ),
              ),
            ],
          ),

          // Rate Selector (Only for USD INDEXADO)
          if (widget.goalCurrency == 'USD') ...[
            const SizedBox(height: 16),
            Text('Tasa para conversión a Bs',
                style: GoogleFonts.poppins(color: const Color(0xFFB0BEC5))),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['BCV', 'USDT', 'EURO', 'CUSTOM'].map((rateKey) {
                  final isSelected = _selectedRateType == rateKey;
                  final rateVal = widget.rates[rateKey] ?? 0.0;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedRateType = rateKey;
                        _usePendingRate = false; // Resetear al cambiar tipo
                        _calculate();
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF4ADE80)
                            : const Color(0xFF132B3D),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isSelected
                                ? const Color(0xFF4ADE80)
                                : Colors.white24),
                      ),
                      child: Column(
                        children: [
                          Text(
                            rateKey == 'CUSTOM' ? 'PERS.' : rateKey,
                            style: GoogleFonts.poppins(
                              color: isSelected
                                  ? const Color(0xFF132B3D)
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            rateVal.toStringAsFixed(2),
                            style: GoogleFonts.poppins(
                              color: isSelected
                                  ? const Color(0xFF132B3D).withOpacity(0.7)
                                  : const Color(0xFFB0BEC5),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Alerta de Tasa Pendiente (Visualizar próxima tasa)
            Builder(builder: (context) {
              final pending = widget.pendingRates[_selectedRateType];
              if (pending != null && pending['rate'] != null) {
                final double nextRate = pending['rate'];
                final DateTime? date = pending['date'];
                final dateStr =
                    date != null ? "${date.day}/${date.month}" : "Mañana";

                return Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.yellow.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.yellow.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_outlined,
                          color: Colors.yellow, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Próxima tasa ($dateStr): $nextRate',
                          style: GoogleFonts.poppins(
                              color: Colors.yellow, fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _usePendingRate = !_usePendingRate;
                            _calculate();
                          });
                        },
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size(50, 30)),
                        child: Text(
                          _usePendingRate ? 'Usar Actual' : 'Usar',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],

          const SizedBox(height: 24),

          // Result
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Meta:',
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 12)),
                    Text(
                      '$goalSymbol${_calculatedGoalAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                        widget.isDeposit
                            ? 'Descontar de Billetera:'
                            : 'Abonar a Billetera:',
                        style: GoogleFonts.poppins(
                            color: Colors.white70, fontSize: 12)),
                    Text(
                      '$walletSymbol${_calculatedWalletAmount.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _calculatedGoalAmount > 0
                  ? () => widget.onConfirm(_calculatedGoalAmount,
                      _calculatedWalletAmount, _targetWalletKey)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                'CONFIRMAR',
                style: GoogleFonts.poppins(
                    color: const Color(0xFF132B3D),
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
