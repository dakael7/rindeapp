import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SavingsGoal {
  String id;
  String name;
  double targetAmount; // En VES
  double currentAmount; // En VES
  DateTime deadline;
  int colorIndex;

  SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.deadline,
    required this.colorIndex,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'targetAmount': targetAmount,
    'currentAmount': currentAmount,
    'deadline': deadline.toIso8601String(),
    'colorIndex': colorIndex,
  };

  factory SavingsGoal.fromJson(Map<String, dynamic> json) => SavingsGoal(
    id: json['id'],
    name: json['name'],
    targetAmount: (json['targetAmount'] ?? 0).toDouble(),
    currentAmount: (json['currentAmount'] ?? 0).toDouble(),
    deadline: DateTime.parse(json['deadline']),
    colorIndex: json['colorIndex'] ?? 0,
  );
}

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({Key? key}) : super(key: key);

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  final Color _backgroundColor = const Color(0xFF071925);
  final Color _cardColor = const Color(0xFF132B3D);
  final Color _primaryGreen = const Color(0xFF4ADE80);
  final List<Color> _goalColors = [
    const Color(0xFF4ADE80), // Green
    const Color(0xFF64B5F6), // Blue
    const Color(0xFFFFB74D), // Orange
    const Color(0xFFE57373), // Red
    const Color(0xFFBA68C8), // Purple
  ];

  List<SavingsGoal> _goals = [];
  bool _isLoading = true;
  double _totalSaved = 0.0;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('savings_goals');
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      _goals = decoded.map((e) => SavingsGoal.fromJson(e)).toList();
    }
    _calculateTotal();
    setState(() {
      _isLoading = false;
    });
  }

  void _calculateTotal() {
    double total = 0;
    for (var g in _goals) {
      total += g.currentAmount;
    }
    _totalSaved = total;
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_goals.map((e) => e.toJson()).toList());
    await prefs.setString('savings_goals', encoded);
    _calculateTotal();
    setState(() {});
  }

  // --- INTEGRACIÓN CON WALLET ---
  // Esta función crea una transacción en el historial general
  Future<void> _registerWalletTransaction({
    required String title,
    required double amount,
    required bool isExpense,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('transactions_data');
    List<dynamic> transactions = [];

    if (data != null) {
      transactions = jsonDecode(data);
    }

    // Estructura compatible con WalletScreen
    final newTransaction = {
      'id': 'SAVINGS_${DateTime.now().millisecondsSinceEpoch}',
      'title': title,
      'originalAmount': amount,
      'originalCurrency': 'VES',
      'rateType': 'N/A',
      'exchangeRate': 1.0,
      'amountInVES': amount,
      'isExpense': isExpense,
      'date': DateTime.now().toIso8601String(),
    };

    transactions.add(newTransaction);
    await prefs.setString('transactions_data', jsonEncode(transactions));
  }

  void _addOrUpdateGoal(SavingsGoal goal, {bool isNew = false}) {
    if (isNew) {
      _goals.add(goal);
    } else {
      final index = _goals.indexWhere((g) => g.id == goal.id);
      if (index != -1) {
        _goals[index] = goal;
      }
    }
    _saveGoals();
  }

  void _deleteGoal(String id) {
    // Nota: Al eliminar, el dinero se queda en el "limbo" si no se retira antes.
    // Por simplicidad UX, asumimos que el usuario retira antes de borrar,
    // o podríamos auto-reintegrar. Aquí solo borramos la meta.
    _goals.removeWhere((g) => g.id == id);
    _saveGoals();
  }

  void _showTransactionDialog(SavingsGoal goal, bool isDeposit) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDeposit ? 'Abonar a la meta' : 'Retirar de la meta',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 24),
                decoration: InputDecoration(
                  prefixText: 'Bs ',
                  prefixStyle: GoogleFonts.poppins(color: _primaryGreen),
                  hintText: '0.00',
                  hintStyle: GoogleFonts.poppins(color: Colors.white24),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: _primaryGreen),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(controller.text) ?? 0.0;
                    if (amount <= 0) return;

                    if (!isDeposit && amount > goal.currentAmount) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Saldo insuficiente en la meta'),
                        ),
                      );
                      return;
                    }

                    // 1. Actualizar Meta Local
                    if (isDeposit) {
                      goal.currentAmount += amount;
                    } else {
                      goal.currentAmount -= amount;
                    }
                    _addOrUpdateGoal(goal);

                    // 2. Registrar en Wallet (Inverso: Depósito es Gasto en Wallet, Retiro es Ingreso)
                    await _registerWalletTransaction(
                      title: isDeposit
                          ? 'Abono: ${goal.name}'
                          : 'Retiro: ${goal.name}',
                      amount: amount,
                      isExpense:
                          isDeposit, // Si deposito en alcancía, sale de wallet (Gasto)
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isDeposit ? 'Abono exitoso' : 'Retiro exitoso',
                          ),
                          backgroundColor: _primaryGreen,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'CONFIRMAR',
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
      ),
    );
  }

  void _showGoalForm({SavingsGoal? existingGoal}) {
    final nameCtrl = TextEditingController(text: existingGoal?.name);
    final targetCtrl = TextEditingController(
      text: existingGoal?.targetAmount.toString(),
    );
    int selectedColor = existingGoal?.colorIndex ?? 0;
    DateTime selectedDate =
        existingGoal?.deadline ?? DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: _cardColor,
            title: Text(
              existingGoal == null ? 'Nueva Meta' : 'Editar Meta',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Nombre (ej. Laptop)',
                      labelStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                      ),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: targetCtrl,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Meta (Bs)',
                      labelStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                      ),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Color:',
                        style: GoogleFonts.poppins(color: Colors.white70),
                      ),
                      Row(
                        children: List.generate(_goalColors.length, (index) {
                          return GestureDetector(
                            onTap: () =>
                                setDialogState(() => selectedColor = index),
                            child: Container(
                              margin: const EdgeInsets.only(left: 8),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: _goalColors[index],
                                shape: BoxShape.circle,
                                border: selectedColor == index
                                    ? Border.all(color: Colors.white, width: 2)
                                    : null,
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.isEmpty || targetCtrl.text.isEmpty) return;

                  final newGoal = SavingsGoal(
                    id:
                        existingGoal?.id ??
                        DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameCtrl.text,
                    targetAmount: double.tryParse(targetCtrl.text) ?? 0,
                    currentAmount: existingGoal?.currentAmount ?? 0,
                    deadline: selectedDate,
                    colorIndex: selectedColor,
                  );

                  _addOrUpdateGoal(newGoal, isNew: existingGoal == null);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: _primaryGreen),
                child: Text(
                  'Guardar',
                  style: const TextStyle(color: Color(0xFF071925)),
                ),
              ),
            ],
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
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryGreen))
          : Column(
              children: [
                // Header Total
                Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _primaryGreen.withOpacity(0.2),
                        Colors.transparent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.savings_outlined,
                          color: Color(0xFF071925),
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ahorro Total',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Bs ${_totalSaved.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Lista de Metas
                Expanded(
                  child: _goals.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.rocket_launch_outlined,
                                size: 60,
                                color: Colors.white24,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Crea tu primera meta',
                                style: GoogleFonts.poppins(
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _goals.length,
                          itemBuilder: (context, index) {
                            final goal = _goals[index];
                            final progress =
                                (goal.currentAmount / goal.targetAmount).clamp(
                                  0.0,
                                  1.0,
                                );
                            final color = _goalColors[goal.colorIndex];

                            return Dismissible(
                              key: Key(goal.id),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (direction) async {
                                return await showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: _cardColor,
                                    title: Text(
                                      '¿Eliminar meta?',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                      ),
                                    ),
                                    content: Text(
                                      'El saldo no se devolverá automáticamente a la wallet.',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white70,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          'Eliminar',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onDismissed: (_) => _deleteGoal(goal.id),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                color: Colors.red.withOpacity(0.2),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.05),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              goal.name,
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            Text(
                                              'Meta: Bs ${goal.targetAmount.toStringAsFixed(0)}',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white54,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            '${(progress * 100).toStringAsFixed(0)}%',
                                            style: GoogleFonts.poppins(
                                              color: color,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor: Colors.white10,
                                        color: color,
                                        minHeight: 8,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () =>
                                                _showTransactionDialog(
                                                  goal,
                                                  false,
                                                ),
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                color: Colors.white.withOpacity(
                                                  0.2,
                                                ),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            child: Text(
                                              'Retirar',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () =>
                                                _showTransactionDialog(
                                                  goal,
                                                  true,
                                                ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: color,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            child: Text(
                                              'Abonar',
                                              style: GoogleFonts.poppins(
                                                color: const Color(0xFF071925),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showGoalForm(),
        backgroundColor: _primaryGreen,
        child: const Icon(Icons.add, color: Color(0xFF071925)),
      ),
    );
  }
}
