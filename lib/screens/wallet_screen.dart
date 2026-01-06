import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'recurring_transactions_screen.dart';
import 'debt_screen.dart';

// ==========================================
// MODELO DE DATOS ACTUALIZADO (Algoritmo Generalizado)
// ==========================================

class TransactionCategory {
  final String id;
  final String name;
  final int color;

  TransactionCategory({
    required this.id,
    required this.name,
    required this.color,
  });

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'color': color};

  factory TransactionCategory.fromJson(Map<String, dynamic> json) =>
      TransactionCategory(
        id: json['id'],
        name: json['name'],
        color: json['color'],
      );
}

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
  final String categoryName;
  final int categoryColor;

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
    this.categoryName = 'General',
    this.categoryColor = 0xFF90A4AE,
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
    'categoryName': categoryName,
    'categoryColor': categoryColor,
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
    categoryName: json['categoryName'] ?? 'General',
    categoryColor: json['categoryColor'] ?? 0xFF90A4AE,
  );
}

// ==========================================
// PANTALLA PRINCIPAL DE BILLETERA
// ==========================================

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

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
  List<TransactionCategory> _categories = [];

  // --- Filtros ---
  String _searchQuery = '';
  TransactionCategory? _selectedCategoryFilter;
  String _sortOrder =
      'DATE_DESC'; // DATE_DESC, DATE_ASC, AMOUNT_DESC, AMOUNT_ASC
  DateTimeRange? _selectedDateRange;

  // Tasas de cambio configurables (Valores por defecto)
  final Map<String, double> _currentRates = {
    'BCV': 52.5,
    'USDT': 54.2,
    'EURO': 56.1,
    'CUSTOM': 0.0,
  };

  bool _isLoading = true;

  bool get _hasActiveFilters =>
      _selectedCategoryFilter != null ||
      _selectedDateRange != null ||
      _sortOrder != 'DATE_DESC' ||
      _searchQuery.isNotEmpty;

  List<Transaction> get _filteredTransactions {
    return _transactions.where((t) {
      // 1. Búsqueda
      if (_searchQuery.isNotEmpty &&
          !t.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      // 2. Categoría
      if (_selectedCategoryFilter != null &&
          t.categoryName != _selectedCategoryFilter!.name) {
        return false;
      }
      // 3. Rango de Fechas
      if (_selectedDateRange != null) {
        if (t.date.isBefore(_selectedDateRange!.start) ||
            t.date.isAfter(
              _selectedDateRange!.end.add(const Duration(days: 1)),
            )) {
          return false;
        }
      }
      return true;
    }).toList()..sort((a, b) {
      switch (_sortOrder) {
        case 'AMOUNT_ASC':
          return a.amountInVES.compareTo(b.amountInVES);
        case 'AMOUNT_DESC':
          return b.amountInVES.compareTo(a.amountInVES);
        case 'DATE_ASC':
          return a.date.compareTo(b.date);
        case 'DATE_DESC':
        default:
          return b.date.compareTo(a.date);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkRecurringTransactions();
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

    // 3. Cargar Categorías
    final String? catData = prefs.getString('categories_data');
    List<TransactionCategory> loadedCategories = [];
    if (catData != null) {
      final List<dynamic> decoded = jsonDecode(catData);
      loadedCategories = decoded
          .map((e) => TransactionCategory.fromJson(e))
          .toList();
    } else {
      // Categorías por defecto
      loadedCategories = [
        TransactionCategory(id: '1', name: 'General', color: 0xFF90A4AE),
        TransactionCategory(id: '2', name: 'Comida', color: 0xFFFF7043),
        TransactionCategory(id: '3', name: 'Transporte', color: 0xFF42A5F5),
      ];
      _saveCategories(loadedCategories);
    }

    setState(() {
      _transactions = loadedTransactions;
      _categories = loadedCategories;
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
          // Si es Efectivo, es independiente (1:1)
          // Si es Digital (USD/EUR), usamos BCV por defecto
          if (item.currency == 'USD_CASH') {
            rateUsed = 1.0;
            rateType = 'CASH';
          } else {
            // Usar la tasa configurada en la programación
            rateType = item.rateType;
            rateUsed = _currentRates[rateType] ?? _currentRates['BCV'] ?? 52.5;
          }

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

  Future<void> _saveCategories(List<TransactionCategory> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(
      categories.map((e) => e.toJson()).toList(),
    );
    await prefs.setString('categories_data', encoded);
  }

  Future<void> _saveCustomRate(double customRate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('rate_custom', customRate);
    setState(() {
      _currentRates['CUSTOM'] = customRate;
    });
  }

  /// ALGORITMO: Cálculo del Saldo Neto en Bolívares (Excluyendo Efectivo USD)
  double get _totalBalanceVES {
    double total = 0;
    for (var t in _transactions) {
      // El efectivo se maneja por separado como moneda paralela
      if (t.originalCurrency == 'USD_CASH') continue;

      if (t.isExpense) {
        total -= t.amountInVES;
      } else {
        total += t.amountInVES;
      }
    }
    return total;
  }

  /// ALGORITMO: Cálculo del Saldo en Efectivo USD (Paralelo)
  double get _totalBalanceUSDCash {
    double total = 0;
    for (var t in _transactions) {
      if (t.originalCurrency == 'USD_CASH') {
        if (t.isExpense) {
          total -= t.originalAmount;
        } else {
          total += t.originalAmount;
        }
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

  // --- Modal de Filtros ---
  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateModal) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filtros',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_hasActiveFilters)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCategoryFilter = null;
                            _sortOrder = 'DATE_DESC';
                            _selectedDateRange = null;
                            _searchQuery = '';
                          });
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Limpiar Todo',
                          style: GoogleFonts.poppins(color: _expenseRed),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Sort
                Text(
                  'Ordenar por',
                  style: GoogleFonts.poppins(color: _textGrey),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildFilterChip(
                      'Más Recientes',
                      'DATE_DESC',
                      setStateModal,
                    ),
                    _buildFilterChip('Más Antiguos', 'DATE_ASC', setStateModal),
                    _buildFilterChip(
                      'Mayor Monto',
                      'AMOUNT_DESC',
                      setStateModal,
                    ),
                    _buildFilterChip(
                      'Menor Monto',
                      'AMOUNT_ASC',
                      setStateModal,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Date Range
                Text('Periodo', style: GoogleFonts.poppins(color: _textGrey)),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      locale: const Locale('es', 'ES'),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDateRange: _selectedDateRange,
                      builder: (context, child) => Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.dark(
                            primary: _primaryGreen,
                            onPrimary: _backgroundColor,
                            surface: _cardColor,
                            onSurface: Colors.white,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) {
                      setState(() => _selectedDateRange = picked);
                      setStateModal(() {});
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedDateRange != null
                            ? _primaryGreen
                            : Colors.white10,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedDateRange == null
                              ? 'Seleccionar fechas'
                              : '${DateFormat('dd/MM/yy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}',
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                        Icon(
                          Icons.calendar_today,
                          color: _selectedDateRange != null
                              ? _primaryGreen
                              : _textGrey,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Categories
                Text('Categoría', style: GoogleFonts.poppins(color: _textGrey)),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _categories.map((cat) {
                        final isSelected =
                            _selectedCategoryFilter?.id == cat.id;
                        return FilterChip(
                          label: Text(cat.name),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            setState(() {
                              _selectedCategoryFilter = selected ? cat : null;
                            });
                            setStateModal(() {});
                          },
                          backgroundColor: _cardColor,
                          selectedColor: Color(cat.color).withOpacity(0.3),
                          checkmarkColor: Color(cat.color),
                          labelStyle: GoogleFonts.poppins(
                            color: isSelected
                                ? Color(cat.color)
                                : Colors.white70,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? Color(cat.color)
                                  : Colors.transparent,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Apply Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Aplicar Filtros',
                      style: GoogleFonts.poppins(
                        color: _backgroundColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    StateSetter setStateModal,
  ) {
    final isSelected = _sortOrder == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          setState(() => _sortOrder = value);
          setStateModal(() {});
        }
      },
      selectedColor: _primaryGreen,
      backgroundColor: _cardColor,
      labelStyle: GoogleFonts.poppins(
        color: isSelected ? _backgroundColor : Colors.white,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        categories: _categories,
        onAddCategory: (newCat) {
          setState(() {
            _categories.add(newCat);
          });
          _saveCategories(_categories);
        },
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
                Container(child: _buildBalanceCard()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar movimiento...',
                      hintStyle: GoogleFonts.poppins(color: _textGrey),
                      prefixIcon: Icon(Icons.search, color: _textGrey),
                      suffixIcon: IconButton(
                        icon: Icon(
                          Icons.filter_list,
                          color: _hasActiveFilters ? _primaryGreen : _textGrey,
                        ),
                        onPressed: _showFilterModal,
                      ),
                      filled: true,
                      fillColor: _cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredTransactions.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _filteredTransactions.length,
                          itemBuilder: (context, index) {
                            final transaction = _filteredTransactions[index];
                            return _buildTransactionItem(transaction);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'exchangeBtn',
            onPressed: _openExchangeModal,
            backgroundColor: _cardColor,
            child: const Icon(Icons.currency_exchange, color: Colors.white),
          ),
          const SizedBox(width: 16),
          FloatingActionButton.extended(
            heroTag: 'registerBtn',
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
        ],
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
            'Digital: \$${projectedUSD.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_totalBalanceUSDCash > 0)
            Text(
              'Efectivo: \$${_totalBalanceUSDCash.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(
                color: const Color(0xFFFFD700),
                fontSize: 20,
                fontWeight: FontWeight.w600,
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
              'Base Digital: ${currencyFormatter.format(_totalBalanceVES)}',
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
          : (t.originalCurrency == 'EUR'
                ? '€ '
                : (t.originalCurrency == 'USD_CASH' ? '💵 ' : '\$ ')),
      decimalDigits: 2,
    );

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
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Color(t.categoryColor).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      t.categoryName,
                      style: GoogleFonts.poppins(
                        color: Color(t.categoryColor),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Muestra el impacto real en Bolívares
            _TransactionAmountToggle(
              transaction: t,
              bcvRate: _currentRates['BCV'] ?? 1.0,
              color: t.isExpense ? _expenseRed : _primaryGreen,
              labelColor: _textGrey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final msg = _transactions.isEmpty
        ? 'Sin registros aún'
        : 'No se encontraron resultados';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _transactions.isEmpty
                ? Icons.account_balance_wallet_outlined
                : Icons.search_off,
            size: 80,
            color: _textGrey.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(msg, style: GoogleFonts.poppins(color: _textGrey)),
        ],
      ),
    );
  }

  void _openExchangeModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExchangeModal(
        backgroundColor: _backgroundColor,
        cardColor: _cardColor,
        primaryGreen: _primaryGreen,
        expenseRed: _expenseRed,
        textGrey: _textGrey,
        initialRate: _currentRates['BCV'] ?? 50.0,
        onConfirm: (isBuying, usdAmount, vesAmount, rate) {
          final date = DateTime.now();
          final timestamp = date.millisecondsSinceEpoch;

          // 1. Transacción de Efectivo (USD)
          final cashTx = Transaction(
            id: '${timestamp}_cash',
            title: isBuying
                ? 'Compra Divisas (Entrada)'
                : 'Venta Divisas (Salida)',
            originalAmount: usdAmount,
            originalCurrency: 'USD_CASH',
            rateType: 'CASH',
            exchangeRate: 1.0,
            amountInVES:
                usdAmount, // En cash, amountInVES guarda el valor en USD
            isExpense:
                !isBuying, // Si compro, entra dinero a la caja (Ingreso). Si vendo, sale (Gasto).
            date: date,
          );

          // 2. Transacción Digital (VES)
          final vesTx = Transaction(
            id: '${timestamp}_ves',
            title: isBuying
                ? 'Compra Divisas (Salida)'
                : 'Venta Divisas (Entrada)',
            originalAmount: vesAmount,
            originalCurrency: 'VES',
            rateType: 'MANUAL',
            exchangeRate: 1.0,
            amountInVES: vesAmount,
            isExpense: isBuying, // Si compro, gasto Bs. Si vendo, entran Bs.
            date: date,
          );

          setState(() {
            _transactions.insert(0, cashTx);
            _transactions.insert(0, vesTx);
          });
          _saveTransactions();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Conversión registrada con éxito'),
              backgroundColor: _primaryGreen,
            ),
          );
        },
      ),
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
  final List<TransactionCategory> categories;
  final Function(TransactionCategory) onAddCategory;
  final Function(Transaction) onSave;

  const _TransactionForm({
    required this.backgroundColor,
    required this.cardColor,
    required this.primaryGreen,
    required this.expenseRed,
    required this.textGrey,
    required this.rates,
    required this.categories,
    required this.onAddCategory,
    required this.onSave,
  });

  @override
  State<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<_TransactionForm> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _customRateController = TextEditingController();

  TransactionCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) {
      _selectedCategory = widget.categories.first;
    }
  }

  bool _isExpense = true;
  String _selectedCurrency = 'VES'; // Moneda de entrada
  String _selectedRateType = 'BCV'; // Tasa a usar para la conversión

  // Obtiene la tasa seleccionada para el cálculo
  double get _currentRate {
    // Si es Efectivo, no usamos ninguna tasa (1:1), es independiente.
    if (_selectedCurrency == 'USD_CASH') {
      return 1.0;
    }
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
      rateType: _selectedCurrency == 'VES'
          ? 'N/A'
          : (_selectedCurrency == 'USD_CASH' ? 'CASH' : _selectedRateType),
      exchangeRate: _currentRate,
      amountInVES: _calculatedVES, // GUARDAMOS EN MONEDA COMÚN
      isExpense: _isExpense,
      date: DateTime.now(),
      categoryName: _selectedCategory?.name ?? 'General',
      categoryColor: _selectedCategory?.color ?? 0xFF90A4AE,
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
                      items: ['VES', 'USD', 'EUR', 'USD_CASH'].map((
                        String val,
                      ) {
                        String label = val;
                        if (val == 'USD_CASH') label = 'Efectivo (\$)';
                        return DropdownMenuItem(
                          value: val,
                          child: Text(
                            label,
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

          // 3. Selección de Tasa (Solo si NO es VES y NO es Efectivo)
          if (_selectedCurrency != 'VES' &&
              _selectedCurrency != 'USD_CASH') ...[
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
                  _selectedCurrency == 'USD_CASH'
                      ? 'Saldo en Efectivo:'
                      : 'Registro Contable (Base):',
                  style: GoogleFonts.poppins(
                    color: widget.textGrey,
                    fontSize: 12,
                  ),
                ),
                Text(
                  _selectedCurrency == 'USD_CASH'
                      ? '\$${_calculatedVES.toStringAsFixed(2)}'
                      : 'Bs. ${_calculatedVES.toStringAsFixed(2)}',
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

          _buildCategorySelector(),

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

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Categoría', style: GoogleFonts.poppins(color: widget.textGrey)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Botón Agregar
              GestureDetector(
                onTap: _showAddCategoryDialog,
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.primaryGreen),
                  ),
                  child: Icon(Icons.add, color: widget.primaryGreen, size: 20),
                ),
              ),
              // Lista de Categorías
              ...widget.categories.map((cat) {
                final isSelected = _selectedCategory?.id == cat.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Color(cat.color) : widget.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? Colors.transparent : Colors.white10,
                      ),
                    ),
                    child: Text(
                      cat.name,
                      style: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    Color selectedColor = const Color(0xFF90A4AE);
    final List<Color> colors = [
      const Color(0xFFFF7043), // Orange
      const Color(0xFF42A5F5), // Blue
      const Color(0xFF26C6DA), // Cyan
      const Color(0xFF66BB6A), // Green
      const Color(0xFFEF5350), // Red
      const Color(0xFFAB47BC), // Purple
      const Color(0xFFFFCA28), // Amber
      const Color(0xFF8D6E63), // Brown
      const Color(0xFF78909C), // Blue Grey
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: widget.cardColor,
            title: Text(
              'Nueva Categoría',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: GoogleFonts.poppins(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    labelStyle: TextStyle(color: widget.textGrey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: widget.textGrey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: widget.primaryGreen),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: colors.map((color) {
                    return GestureDetector(
                      onTap: () => setStateDialog(() => selectedColor = color),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: selectedColor == color
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.poppins(color: widget.textGrey),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    final newCat = TransactionCategory(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: nameController.text,
                      color: selectedColor.value,
                    );
                    widget.onAddCategory(newCat);
                    setState(() => _selectedCategory = newCat);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.primaryGreen,
                ),
                child: Text(
                  'Crear',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF132B3D),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==========================================
// MODAL DE INTERCAMBIO (COMPRA/VENTA)
// ==========================================

class _ExchangeModal extends StatefulWidget {
  final Color backgroundColor;
  final Color cardColor;
  final Color primaryGreen;
  final Color expenseRed;
  final Color textGrey;
  final double initialRate;
  final Function(bool isBuying, double usd, double ves, double rate) onConfirm;

  const _ExchangeModal({
    required this.backgroundColor,
    required this.cardColor,
    required this.primaryGreen,
    required this.expenseRed,
    required this.textGrey,
    required this.initialRate,
    required this.onConfirm,
  });

  @override
  State<_ExchangeModal> createState() => _ExchangeModalState();
}

class _ExchangeModalState extends State<_ExchangeModal> {
  bool _isBuying =
      false; // false = Vender $ (Recibir Bs), true = Comprar $ (Pagar Bs)
  final _usdController = TextEditingController();
  final _rateController = TextEditingController();
  final _vesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rateController.text = widget.initialRate.toString();
  }

  void _calculateVES() {
    final usd = double.tryParse(_usdController.text) ?? 0.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    final total = usd * rate;
    if (total > 0) {
      _vesController.text = total.toStringAsFixed(2);
    }
  }

  void _calculateRateFromVES() {
    final usd = double.tryParse(_usdController.text) ?? 0.0;
    final ves = double.tryParse(_vesController.text) ?? 0.0;
    if (usd > 0 && ves > 0) {
      final rate = ves / usd;
      _rateController.text = rate.toStringAsFixed(2);
    }
  }

  void _submit() {
    final usd = double.tryParse(_usdController.text) ?? 0.0;
    final ves = double.tryParse(_vesController.text) ?? 0.0;
    final rate = double.tryParse(_rateController.text) ?? 0.0;

    if (usd > 0 && ves > 0) {
      widget.onConfirm(_isBuying, usd, ves, rate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _isBuying ? widget.expenseRed : widget.primaryGreen;
    final actionLabel = _isBuying ? 'Comprar Efectivo' : 'Vender Efectivo';

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

          // Toggle Switch
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: widget.cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isBuying = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isBuying
                            ? widget.primaryGreen
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Vender \$',
                        style: GoogleFonts.poppins(
                          color: !_isBuying
                              ? const Color(0xFF132B3D)
                              : Colors.white54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isBuying = true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isBuying
                            ? widget.expenseRed
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Comprar \$',
                        style: GoogleFonts.poppins(
                          color: _isBuying ? Colors.white : Colors.white54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Inputs
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildInput(
                  controller: _usdController,
                  label: 'Cantidad \$',
                  onChanged: (_) => _calculateVES(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: _buildInput(
                  controller: _rateController,
                  label: 'Tasa',
                  onChanged: (_) => _calculateVES(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Icon(Icons.arrow_downward, color: Colors.white24),
          const SizedBox(height: 16),
          _buildInput(
            controller: _vesController,
            label: _isBuying ? 'Total a Pagar (Bs)' : 'Total a Recibir (Bs)',
            onChanged: (_) => _calculateRateFromVES(),
            isBold: true,
          ),

          const SizedBox(height: 24),

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
                actionLabel.toUpperCase(),
                style: GoogleFonts.poppins(
                  color: _isBuying ? Colors.white : const Color(0xFF132B3D),
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

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required Function(String) onChanged,
    bool isBold = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        fontSize: isBold ? 18 : 14,
      ),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: widget.textGrey),
        filled: true,
        fillColor: widget.cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

class _TransactionAmountToggle extends StatefulWidget {
  final Transaction transaction;
  final double bcvRate;
  final Color color;
  final Color labelColor;

  const _TransactionAmountToggle({
    required this.transaction,
    required this.bcvRate,
    required this.color,
    required this.labelColor,
  });

  @override
  State<_TransactionAmountToggle> createState() =>
      _TransactionAmountToggleState();
}

class _TransactionAmountToggleState extends State<_TransactionAmountToggle> {
  int _displayMode = 0; // 0: Original, 1: USD (BCV), 2: VES

  void _toggle() {
    if (widget.transaction.originalCurrency == 'USD_CASH') return;
    setState(() {
      _displayMode = (_displayMode + 1) % 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    double val = t.originalAmount;
    String symbol = t.originalCurrency == 'VES'
        ? 'Bs '
        : (t.originalCurrency == 'EUR' ? '€ ' : '\$ ');
    String label = t.originalCurrency;

    if (t.originalCurrency == 'USD_CASH') {
      val = t.originalAmount;
      symbol = '\$ ';
      label = 'Efectivo';
    } else if (_displayMode == 1) {
      val = t.amountInVES / (widget.bcvRate > 0 ? widget.bcvRate : 1);
      symbol = '\$ ';
      label = 'BCV';
    } else if (_displayMode == 2) {
      val = t.amountInVES;
      symbol = 'Bs ';
      label = 'Bolívares';
    }

    return GestureDetector(
      onTap: _toggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${t.isExpense ? "-" : "+"}$symbol${NumberFormat.currency(symbol: '', decimalDigits: 2).format(val)}',
            style: GoogleFonts.poppins(
              color: widget.color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(color: widget.labelColor, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
