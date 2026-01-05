import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Modelo de Transacción Recurrente
class RecurringTransaction {
  String id;
  String title;
  double amount;
  String currency; // 'VES', 'USD', 'EUR'
  bool isIndexed; // Si es true, se registra en VES calculado a la tasa
  bool isExpense;
  String frequencyType; // 'DAYS', 'WEEKLY', 'MONTHLY'
  int
  frequencyValue; // Intervalo de días, Día de la semana (1-7), o Día del mes (1-31)
  DateTime nextExecution;
  bool active;

  RecurringTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.currency,
    required this.isIndexed,
    required this.isExpense,
    required this.frequencyType,
    required this.frequencyValue,
    required this.nextExecution,
    this.active = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'currency': currency,
    'isIndexed': isIndexed,
    'isExpense': isExpense,
    'frequencyType': frequencyType,
    'frequencyValue': frequencyValue,
    'nextExecution': nextExecution.toIso8601String(),
    'active': active,
  };

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) =>
      RecurringTransaction(
        id: json['id'],
        title: json['title'],
        amount: (json['amount'] ?? 0).toDouble(),
        currency: json['currency'] ?? 'VES',
        isIndexed: json['isIndexed'] ?? false,
        isExpense: json['isExpense'] ?? true,
        frequencyType: json['frequencyType'] ?? 'MONTHLY',
        frequencyValue: json['frequencyValue'] ?? 1,
        nextExecution: DateTime.parse(json['nextExecution']),
        active: json['active'] ?? true,
      );
}

class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({Key? key}) : super(key: key);

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> {
  final Color _backgroundColor = const Color(0xFF071925);
  final Color _cardColor = const Color(0xFF132B3D);
  final Color _primaryGreen = const Color(0xFF4ADE80);
  final Color _expenseRed = const Color(0xFFFF5252);

  List<RecurringTransaction> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('recurring_transactions');
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      _items = decoded.map((e) => RecurringTransaction.fromJson(e)).toList();
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString('recurring_transactions', encoded);
  }

  void _toggleActive(RecurringTransaction item) {
    setState(() {
      item.active = !item.active;
    });
    _saveData();
  }

  void _deleteItem(String id) {
    setState(() {
      _items.removeWhere((e) => e.id == id);
    });
    _saveData();
  }

  void _openForm({RecurringTransaction? existingItem}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RecurringForm(
        existingItem: existingItem,
        onSave: (item) {
          setState(() {
            if (existingItem != null) {
              final index = _items.indexWhere((e) => e.id == existingItem.id);
              if (index != -1) _items[index] = item;
            } else {
              _items.add(item);
            }
          });
          _saveData();
          Navigator.pop(context);
        },
      ),
    );
  }

  String _getFrequencyText(RecurringTransaction item) {
    if (item.frequencyType == 'DAYS') {
      return 'Cada ${item.frequencyValue} días';
    } else if (item.frequencyType == 'WEEKLY') {
      const days = [
        '',
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
        'Domingo',
      ];
      return 'Cada semana (los ${days[item.frequencyValue]})';
    } else {
      return 'Mensual (día ${item.frequencyValue})';
    }
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
          'Automatización',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryGreen))
          : _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.autorenew,
                    size: 80,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay pagos programados',
                    style: GoogleFonts.poppins(color: Colors.white54),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Dismissible(
                  key: Key(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: _expenseRed,
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => _deleteItem(item.id),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: item.active
                            ? (item.isExpense ? _expenseRed : _primaryGreen)
                                  .withOpacity(0.3)
                            : Colors.white.withOpacity(0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: item.active
                                ? (item.isExpense ? _expenseRed : _primaryGreen)
                                      .withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item.isExpense
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            color: item.active
                                ? (item.isExpense ? _expenseRed : _primaryGreen)
                                : Colors.grey,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: GoogleFonts.poppins(
                                  color: item.active
                                      ? Colors.white
                                      : Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _getFrequencyText(item),
                                style: GoogleFonts.poppins(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '${item.currency} ${item.amount.toStringAsFixed(2)}',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (item.isIndexed)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'INDEXADO',
                                        style: GoogleFonts.poppins(
                                          color: Colors.blueAccent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: item.active,
                          onChanged: (_) => _toggleActive(item),
                          activeThumbColor: _primaryGreen,
                          activeTrackColor: _primaryGreen.withOpacity(0.3),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: _primaryGreen,
        icon: const Icon(Icons.add, color: Color(0xFF071925)),
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
}

class _RecurringForm extends StatefulWidget {
  final RecurringTransaction? existingItem;
  final Function(RecurringTransaction) onSave;

  const _RecurringForm({this.existingItem, required this.onSave});

  @override
  State<_RecurringForm> createState() => _RecurringFormState();
}

class _RecurringFormState extends State<_RecurringForm> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  bool _isExpense = true;
  String _currency = 'USD';
  bool _isIndexed = false;
  String _frequencyType = 'MONTHLY';
  int _frequencyValue = 1; // Default day 1

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _titleController.text = item.title;
      _amountController.text = item.amount.toString();
      _isExpense = item.isExpense;
      _currency = item.currency;
      _isIndexed = item.isIndexed;
      _frequencyType = item.frequencyType;
      _frequencyValue = item.frequencyValue;
    } else {
      // Default to today's day for monthly
      _frequencyValue = DateTime.now().day;
    }
  }

  DateTime _calculateNextExecution() {
    final now = DateTime.now();
    DateTime next;

    if (_frequencyType == 'DAYS') {
      // Empezar mañana si es nuevo
      next = now.add(Duration(days: _frequencyValue));
    } else if (_frequencyType == 'WEEKLY') {
      // _frequencyValue es 1 (Lunes) a 7 (Domingo)
      int daysToAdd = (_frequencyValue - now.weekday + 7) % 7;
      if (daysToAdd == 0) daysToAdd = 7; // Próxima semana si es hoy
      next = now.add(Duration(days: daysToAdd));
    } else {
      // MONTHLY
      // Si el día ya pasó este mes, ir al siguiente
      if (now.day >= _frequencyValue) {
        if (now.month == 12) {
          next = DateTime(now.year + 1, 1, _frequencyValue);
        } else {
          next = DateTime(now.year, now.month + 1, _frequencyValue);
        }
      } else {
        next = DateTime(now.year, now.month, _frequencyValue);
      }
    }
    // Normalizar hora para evitar ejecuciones múltiples el mismo día
    return DateTime(next.year, next.month, next.day, 8, 0, 0);
  }

  void _submit() {
    if (_titleController.text.isEmpty || _amountController.text.isEmpty) return;

    final item = RecurringTransaction(
      id:
          widget.existingItem?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text,
      amount: double.tryParse(_amountController.text) ?? 0.0,
      currency: _currency,
      isIndexed: _isIndexed,
      isExpense: _isExpense,
      frequencyType: _frequencyType,
      frequencyValue: _frequencyValue,
      nextExecution: _calculateNextExecution(),
      active: true,
    );

    widget.onSave(item);
  }

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
              'Programar Movimiento',
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
                  child: _TypeButton(
                    label: 'Gasto',
                    isSelected: _isExpense,
                    color: expenseRed,
                    onTap: () => setState(() => _isExpense = true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _TypeButton(
                    label: 'Ingreso',
                    isSelected: !_isExpense,
                    color: primaryGreen,
                    onTap: () => setState(() => _isExpense = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Concepto
            TextField(
              controller: _titleController,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Concepto (ej. Alquiler, Salario)',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Monto y Moneda
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Monto',
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
                        onChanged: (v) => setState(() {
                          _currency = v!;
                          if (_currency == 'VES') _isIndexed = false;
                        }),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Opción Indexado (Solo si no es VES)
            if (_currency != 'VES')
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Indexar a Bolívares',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                subtitle: Text(
                  'Se registrará en Bs calculado a la tasa del día',
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                value: _isIndexed,
                onChanged: (v) => setState(() => _isIndexed = v),
                activeThumbColor: primaryGreen,
              ),

            const SizedBox(height: 20),
            Text(
              'Frecuencia',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FreqChip(
                    'Mensual',
                    'MONTHLY',
                    _frequencyType,
                    (v) => setState(() => _frequencyType = v),
                  ),
                  _FreqChip(
                    'Semanal',
                    'WEEKLY',
                    _frequencyType,
                    (v) => setState(() => _frequencyType = v),
                  ),
                  _FreqChip(
                    'Por Días',
                    'DAYS',
                    _frequencyType,
                    (v) => setState(() => _frequencyType = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Selector de Valor de Frecuencia
            if (_frequencyType == 'MONTHLY')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Día del mes: $_frequencyValue',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  Slider(
                    value: _frequencyValue.toDouble(),
                    min: 1,
                    max: 31,
                    divisions: 30,
                    activeColor: primaryGreen,
                    onChanged: (v) =>
                        setState(() => _frequencyValue = v.toInt()),
                  ),
                ],
              )
            else if (_frequencyType == 'WEEKLY')
              DropdownButtonFormField<int>(
                initialValue: _frequencyValue > 7 ? 1 : _frequencyValue,
                dropdownColor: cardColor,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Lunes')),
                  DropdownMenuItem(value: 2, child: Text('Martes')),
                  DropdownMenuItem(value: 3, child: Text('Miércoles')),
                  DropdownMenuItem(value: 4, child: Text('Jueves')),
                  DropdownMenuItem(value: 5, child: Text('Viernes')),
                  DropdownMenuItem(value: 6, child: Text('Sábado')),
                  DropdownMenuItem(value: 7, child: Text('Domingo')),
                ],
                onChanged: (v) => setState(() => _frequencyValue = v!),
                style: GoogleFonts.poppins(color: Colors.white),
              )
            else
              TextField(
                keyboardType: TextInputType.number,
                style: GoogleFonts.poppins(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Cada cuántos días (ej. 15)',
                  labelStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (v) =>
                    setState(() => _frequencyValue = int.tryParse(v) ?? 1),
              ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'GUARDAR AUTOMATIZACIÓN',
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

class _TypeButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.white10,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: isSelected ? const Color(0xFF071925) : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _FreqChip extends StatelessWidget {
  final String label;
  final String value;
  final String groupValue;
  final Function(String) onSelect;

  const _FreqChip(this.label, this.value, this.groupValue, this.onSelect);

  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelect(value),
        selectedColor: const Color(0xFF4ADE80),
        backgroundColor: const Color(0xFF132B3D),
        labelStyle: GoogleFonts.poppins(
          color: isSelected ? const Color(0xFF071925) : Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
