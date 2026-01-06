import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // Para HapticFeedback
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:gal/gal.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/rendering.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart'; // Importar paquete
import 'wallet_screen.dart'; // Asegúrate de que este archivo exista en la misma carpeta
import 'rate_history_screen.dart';
import 'analytics_screen.dart';
import 'inflation_detail_screen.dart'; // Importar nueva pantalla
import '../services/exchange_rate_service.dart';
import 'savings_screen.dart';
import 'profile_screen.dart';
import 'debt_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;

  const HomeScreen({Key? key, required this.userName}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  final _pageController = PageController(viewportFraction: 0.92);

  // --- Variables de Estado ---
  final Map<String, double> _rates = {
    'BCV': 52.5,
    'USDT': 54.2,
    'EURO': 56.1,
    'CUSTOM': 0.0,
  };
  String _currentDisplayMode = 'BCV'; // BCV, USDT, EURO, VES
  double _totalBalanceVES = 0.0;
  List<Map<String, dynamic>> _recentTransactions = [];
  bool _obscureBalances = false;
  int _pendingCount = 0;
  double _pendingAmountVES = 0.0;
  double _totalSavedUSD = 0.0;
  double _totalGoalUSD = 0.0;
  double _totalBalanceUSDCash = 0.0;

  // --- Datos para Inflación Personal ---
  Map<String, double> _currencyBalances = {
    'VES': 0.0,
    'USD': 0.0,
    'EUR': 0.0,
    'USDT': 0.0,
    'USD_CASH': 0.0,
  };
  List<Map<String, dynamic>> _rateHistory = [];

  // --- Animaciones ---
  late AnimationController _entranceController;
  late Animation<Offset> _headerSlideAnimation;
  late Animation<Offset> _carouselSlideAnimation;
  late Animation<Offset> _activitiesSlideAnimation;
  late Animation<double> _fadeAnimation;

  // --- Keys para el Tutorial ---
  final GlobalKey _headerKey = GlobalKey();
  final GlobalKey _balanceKey = GlobalKey();
  final GlobalKey _savingsKey = GlobalKey();
  final GlobalKey _debtsKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _walletTabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadFinancialData();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _headerSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
          ),
        );

    _carouselSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
          ),
        );

    _activitiesSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
          ),
        );

    _entranceController.forward();

    // Iniciar tutorial después de que la UI se renderice
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkAndShowTutorial(),
    );
  }

  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final bool seen = prefs.getBool('has_seen_tutorial_v1') ?? false;

    if (!seen) {
      // Pequeño delay para asegurar que las animaciones de entrada terminen
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _showTutorial();
      });
    }
  }

  void _showTutorial() {
    TutorialCoachMark(
      targets: _createTutorialTargets(),
      colorShadow: const Color(0xFF071925),
      textSkip: "OMITIR",
      paddingFocus: 10,
      opacityShadow: 0.8,
      imageFilter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      onFinish: () {
        // Al terminar Home, navegamos a la Billetera para continuar el tour
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WalletScreen(showTutorial: true),
          ),
        ).then((result) {
          if (result == 'next') {
            // Si viene de Billetera, vamos a Analíticas
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AnalyticsScreen(showTutorial: true),
              ),
            ).then((_) => _markTutorialAsSeen());
          } else {
            _markTutorialAsSeen();
          }
        });
      },
      onSkip: () {
        _markTutorialAsSeen();
        return true;
      },
      onClickTarget: (target) {},
      onClickOverlay: (target) {},
    ).show(context: context);
  }

  Future<void> _markTutorialAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_tutorial_v1', true);
  }

  List<TargetFocus> _createTutorialTargets() {
    return [
      _buildTarget(
        _headerKey,
        "Tasas al Día",
        "Aquí verás las tasas de cambio actualizadas (BCV, USDT, EURO). Toca el reloj para ver el historial completo.",
        ContentAlign.bottom,
      ),
      _buildTarget(
        _balanceKey,
        "Tu Poder de Compra",
        "Este es tu balance real indexado. Desliza hacia los lados para ver tu Inflación Personal y Metas.",
        ContentAlign.bottom,
      ),
      _buildTarget(
        _fabKey,
        "Calculadora Rápida",
        "Convierte divisas al instante y genera captures de pago con un solo toque.",
        ContentAlign.top,
      ),
      _buildTarget(
        _walletTabKey,
        "Billetera",
        "Registra tus ingresos y gastos aquí. El sistema calculará todo automáticamente en base a la tasa del día.",
        ContentAlign.top,
      ),
      _buildTarget(
        _savingsKey,
        "Metas de Ahorro",
        "Define objetivos financieros y sigue tu progreso visualmente.",
        ContentAlign.top,
      ),
      _buildTarget(
        _debtsKey,
        "Pagos Pendientes",
        "Gestiona tus deudas y pagos recurrentes. RINDE te avisará cuando debas pagar.",
        ContentAlign.top,
      ),
    ];
  }

  TargetFocus _buildTarget(
    GlobalKey key,
    String title,
    String desc,
    ContentAlign align,
  ) {
    return TargetFocus(
      identify: title,
      keyTarget: key,
      alignSkip: Alignment.topRight,
      contents: [
        TargetContent(
          align: align,
          builder: (context, controller) {
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
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 20),
                if (align == ContentAlign.top) // Botón visual de siguiente
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "Toca para continuar",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF4ADE80),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
      shape: ShapeLightFocus.RRect,
      radius: 15,
    );
  }

  /// Carga Balance y Movimientos de forma segura (previniendo errores de tipo)
  Future<void> _loadFinancialData() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Cargar Tasas guardadas
    final double? bcv = prefs.getDouble('rate_bcv');
    final double? usdt = prefs.getDouble('rate_usdt');
    final double? euro = prefs.getDouble('rate_euro');
    final double? custom = prefs.getDouble('rate_custom');

    if (bcv != null) _rates['BCV'] = bcv;
    if (usdt != null) _rates['USDT'] = usdt;
    if (euro != null) _rates['EURO'] = euro;
    if (custom != null) _rates['CUSTOM'] = custom;

    // Cargar Configuraciones
    _obscureBalances = prefs.getBool('obscure_balances') ?? false;
    final String defaultCurrency = prefs.getString('default_currency') ?? 'BCV';
    if (_currentDisplayMode == 'BCV') {
      _currentDisplayMode =
          defaultCurrency; // Aplicar default solo si no se ha cambiado manualmente en esta sesión (o lógica simple: siempre aplicar al cargar)
    }

    final String? data = prefs.getString('transactions_data');

    double totalVES = 0.0;
    double totalUSDCash = 0.0;
    List<Map<String, dynamic>> loadedRecent = [];
    Map<String, double> tempBalances = {
      'VES': 0.0,
      'USD': 0.0,
      'EUR': 0.0,
      'USDT': 0.0,
      'USD_CASH': 0.0,
    };

    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);

      for (var item in decoded) {
        // Usar amountInVES como fuente de verdad (compatible con WalletScreen)
        final dynamic rawVES = item['amountInVES'];
        double amountVES = 0.0;

        if (rawVES is num) {
          amountVES = rawVES.toDouble();
        } else {
          // Fallback para datos antiguos (amountInUSD)
          final dynamic rawUSD = item['amountInUSD'];
          if (rawUSD is num) {
            amountVES = rawUSD.toDouble() * (_rates['BCV'] ?? 52.5);
          } else {
            amountVES = double.tryParse(rawVES?.toString() ?? '0') ?? 0.0;
          }
        }

        final bool isExpense = item['isExpense'] ?? true;

        // --- Calcular Saldos por Moneda Original ---
        String origCurrency = item['originalCurrency'] ?? 'VES';
        double origAmount = (item['originalAmount'] ?? 0).toDouble();

        if (origCurrency == 'USD_CASH') {
          // El efectivo se suma aparte (Paralelo)
          totalUSDCash += isExpense ? -origAmount : origAmount;
        } else {
          // El resto (VES, USD Digital, EUR) se suma a la base contable en VES
          totalVES += isExpense ? -amountVES : amountVES;
        }

        // Sumar o restar según sea ingreso o gasto
        tempBalances[origCurrency] =
            (tempBalances[origCurrency] ?? 0) +
            (isExpense ? -origAmount : origAmount);
      }

      // Convertimos a lista de mapas segura
      List<Map<String, dynamic>> allTransactions = decoded
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      // Ordenar por fecha
      allTransactions.sort((a, b) {
        DateTime dateA =
            DateTime.tryParse(a['date'].toString()) ?? DateTime.now();
        DateTime dateB =
            DateTime.tryParse(b['date'].toString()) ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      // Tomar los últimos 5
      loadedRecent = allTransactions.take(5).toList();
    }

    // Cargar Metas de Ahorro
    final String? savingsData = prefs.getString('savings_data');
    double tempSaved = 0.0;
    double tempGoal = 0.0;
    if (savingsData != null) {
      try {
        final List<dynamic> decoded = jsonDecode(savingsData);
        for (var item in decoded) {
          tempSaved += (item['currentAmount'] ?? 0).toDouble();
          tempGoal += (item['targetAmount'] ?? 0).toDouble();
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _totalBalanceVES = totalVES;
        _totalBalanceUSDCash = totalUSDCash;
        _recentTransactions = loadedRecent;
        _currencyBalances = tempBalances;
        _totalSavedUSD = tempSaved;
        _totalGoalUSD = tempGoal;
      });
      // Intentar actualizar tasas online en segundo plano
      _updateRatesOnline();
      _calculatePendingPayments();
      _loadRateHistory(); // Cargar historial para cálculos de inflación
    }
  }

  Future<void> _loadRateHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('rates_history_data');
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      setState(() {
        _rateHistory = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _rateHistory.sort(
          (a, b) => b['date'].compareTo(a['date']),
        ); // Más reciente primero
      });
    }
  }

  Future<void> _updateRatesOnline() async {
    try {
      final service = ExchangeRateService();
      final newRates = await service.getRates();

      if (newRates != null && mounted) {
        setState(() {
          _rates['BCV'] = newRates['BCV']!;
          _rates['USDT'] = newRates['USDT']!;
          _rates['EURO'] = newRates['EURO']!;
        });

        // Guardar persistencia
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('rate_bcv', newRates['BCV']!);
        await prefs.setDouble('rate_usdt', newRates['USDT']!);
        await prefs.setDouble('rate_euro', newRates['EURO']!);

        _saveRateHistory(newRates);
        _calculatePendingPayments();
      }
    } catch (e) {
      debugPrint('Error obteniendo tasas: $e');
    }
  }

  Future<void> _saveRateHistory(Map<String, double> rates) async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyData = prefs.getString('rates_history_data');
    List<dynamic> history = [];

    if (historyData != null) {
      history = jsonDecode(historyData);
    }

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    // Verificar si ya existe un registro para HOY
    int todayIndex = -1;
    for (int i = 0; i < history.length; i++) {
      final date = DateTime.parse(history[i]['date']);
      if (DateFormat('yyyy-MM-dd').format(date) == todayStr) {
        todayIndex = i;
        break;
      }
    }

    if (todayIndex != -1) {
      // Actualizar registro de hoy con la tasa más reciente
      history[todayIndex] = {'date': now.toIso8601String(), 'rates': rates};
    } else {
      // Crear nuevo registro para hoy (asegura continuidad en el calendario)
      history.add({'date': now.toIso8601String(), 'rates': rates});
    }

    await prefs.setString('rates_history_data', jsonEncode(history));
  }

  Future<void> _calculatePendingPayments() async {
    final prefs = await SharedPreferences.getInstance();
    double totalVES = 0.0;
    int count = 0;
    final now = DateTime.now();
    final next30Days = now.add(const Duration(days: 30));

    // 1. Recurring Transactions (Gastos Automatizados)
    final String? recurringData = prefs.getString('recurring_transactions');
    if (recurringData != null) {
      final List<dynamic> decoded = jsonDecode(recurringData);
      for (var item in decoded) {
        if (item['active'] == true && item['isExpense'] == true) {
          DateTime nextExecution = DateTime.parse(item['nextExecution']);
          if (nextExecution.isBefore(next30Days)) {
            double amount = (item['amount'] ?? 0).toDouble();
            String currency = item['currency'] ?? 'VES';
            // Convert to VES
            if (currency == 'VES') {
              totalVES += amount;
            } else {
              double rate = _rates['BCV'] ?? 52.5;
              totalVES += amount * rate;
            }
            count++;
          }
        }
      }
    }

    // 2. Debts (Deudas Programadas)
    final String? debtsData = prefs.getString('debts_data');
    if (debtsData != null) {
      final List<dynamic> decoded = jsonDecode(debtsData);
      for (var item in decoded) {
        if (item['isExpense'] == true && item['isCompleted'] == false) {
          DateTime nextDate = DateTime.parse(item['nextDate']);
          if (nextDate.isBefore(next30Days)) {
            double totalAmount = (item['totalAmount'] ?? 0).toDouble();
            int totalInstallments = item['totalInstallments'] ?? 1;
            double installmentAmount = totalAmount / totalInstallments;

            String currency = item['currency'] ?? 'USD';
            if (currency == 'VES') {
              totalVES += installmentAmount;
            } else {
              double rate = _rates['BCV'] ?? 52.5;
              totalVES += installmentAmount * rate;
            }
            count++;
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _pendingCount = count;
        _pendingAmountVES = totalVES;
      });
    }
  }

  void _onItemTapped(int index) async {
    if (index == 1) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
      );
      _loadFinancialData(); // Recargar datos al volver
      return;
    }

    if (index == 2) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const WalletScreen()),
      );
      _loadFinancialData();
      return;
    }

    if (index == 3) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(userName: widget.userName),
        ),
      );
      _loadFinancialData(); // Recargar al volver (por si cambió configuración)
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  void _toggleDisplayMode() {
    setState(() {
      if (_currentDisplayMode == 'BCV') {
        _currentDisplayMode = 'USDT';
      } else if (_currentDisplayMode == 'USDT') {
        _currentDisplayMode = 'EURO';
      } else if (_currentDisplayMode == 'EURO') {
        if ((_rates['CUSTOM'] ?? 0) > 0) {
          _currentDisplayMode = 'CUSTOM';
        } else {
          _currentDisplayMode = 'VES';
        }
      } else if (_currentDisplayMode == 'CUSTOM')
        _currentDisplayMode = 'VES';
      else
        _currentDisplayMode = 'BCV';
    });
  }

  Map<String, dynamic> _getDisplayData() {
    double amount = 0.0;
    String symbol = '\$';
    String label = 'Indexado: BCV';
    double cash = _totalBalanceUSDCash;

    final rate = _rates[_currentDisplayMode] ?? 1.0;

    if (_currentDisplayMode == 'VES') {
      amount = _totalBalanceVES;
      symbol = 'Bs';
      label = 'Bolívares';
    } else if (_currentDisplayMode == 'CUSTOM') {
      amount = _totalBalanceVES / (rate == 0 ? 1 : rate);
      symbol = '*';
      label = 'Tasa Personalizada';
    } else {
      amount = _totalBalanceVES / (rate == 0 ? 1 : rate);
      if (_currentDisplayMode == 'EURO') {
        symbol = '€';
      } else if (_currentDisplayMode == 'USDT')
        symbol = '₮';
      else
        symbol = '\$';
      label = 'Indexado: $_currentDisplayMode';
    }
    return {'amount': amount, 'symbol': symbol, 'label': label, 'cash': cash};
  }

  void _showFeedbackMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: const Color(0xFF132B3D),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF4ADE80),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showCalculatorSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CurrencyCalculatorSheet(rates: _rates),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    const primaryGreen = Color(0xFF4ADE80);
    const cardColor = Color(0xFF132B3D);
    const textGrey = Color(0xFFB0BEC5);
    const expenseRed = Color(0xFFFF5252);

    final displayData = _getDisplayData();

    final textTheme = GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)
        .copyWith(
          headlineLarge: GoogleFonts.poppins(
            color: primaryGreen,
            fontWeight: FontWeight.bold,
            fontSize: 32,
          ),
          headlineMedium: GoogleFonts.poppins(
            color: primaryGreen,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
          titleLarge: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
          titleMedium: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          bodyLarge: GoogleFonts.poppins(color: textGrey, fontSize: 14),
          bodyMedium: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        );

    return Theme(
      data: Theme.of(context).copyWith(textTheme: textTheme),
      child: Scaffold(
        backgroundColor: backgroundColor,

        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // 1. Header
                  SlideTransition(
                    position: _headerSlideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: _Header(
                        key: _headerKey,
                        userName: widget.userName,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 2. Carrusel
                  SlideTransition(
                    position: _carouselSlideAnimation,
                    child: _MainInfoCards(
                      key: _balanceKey,
                      pageController: _pageController,
                      cardColor: cardColor,
                      primaryGreen: primaryGreen,
                      displayData: displayData,
                      onToggleMode: _toggleDisplayMode,
                      allHabitsDone: true,
                      obscureBalances: _obscureBalances,
                      currencyBalances: _currencyBalances,
                      rateHistory: _rateHistory,
                      currentRates: _rates,
                      cashBalance: _totalBalanceUSDCash,
                      totalSaved: _totalSavedUSD,
                      totalGoal: _totalGoalUSD,
                      onSavingsTap: _openSavings,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 3. Mi Alcancía (Nueva Sección)
                  _SavingsBanner(key: _savingsKey, onTap: _openSavings),

                  const SizedBox(height: 20),

                  // 3.5 Pagos Pendientes
                  _PendingPaymentsBanner(
                    key: _debtsKey,
                    count: _pendingCount,
                    amountVES: _pendingAmountVES,
                    rates: _rates,
                    displayMode: _currentDisplayMode,
                    onTap: _openPendingPayments,
                    obscureBalances: _obscureBalances,
                  ),

                  const SizedBox(height: 30),

                  // 4. Actividades Recientes
                  SlideTransition(
                    position: _activitiesSlideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: _RecentActivityList(
                        cardColor: cardColor,
                        primaryGreen: primaryGreen,
                        expenseRed: expenseRed,
                        textGrey: textGrey,
                        transactions: _recentTransactions,
                        currentRates: _rates,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // --- NAVBAR CON CORTE (NOTCH) ---
        bottomNavigationBar: BottomAppBar(
          color: const Color(0xFF071925),
          elevation: 0,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_filled, primaryGreen, textGrey),
                _buildNavItem(1, Icons.bar_chart, primaryGreen, textGrey),
                ScaleTransition(
                  scale: _fadeAnimation,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryGreen.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: FloatingActionButton(
                      key: _fabKey,
                      onPressed: _showCalculatorSheet,
                      backgroundColor: cardColor,
                      elevation: 0,
                      shape: const CircleBorder(
                        side: BorderSide(color: primaryGreen, width: 1.5),
                      ),
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [primaryGreen, Color(0xFFFFD700)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Icon(
                          Icons.calculate,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ),
                _buildNavItem(
                  2,
                  Icons.wallet,
                  primaryGreen,
                  textGrey,
                  key: _walletTabKey,
                ),
                _buildNavItem(3, Icons.person_outline, primaryGreen, textGrey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    Color selectedColor,
    Color unselectedColor, {
    Key? key,
  }) {
    final isSelected = _selectedIndex == index;
    return _BouncingWidget(
      key: key,
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? selectedColor : unselectedColor,
            size: 26,
          ),
          if (isSelected)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 4,
              width: 4,
              decoration: BoxDecoration(
                color: selectedColor,
                shape: BoxShape.circle,
              ),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }

  // Método para abrir la alcancía y recargar datos al volver
  void _openSavings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SavingsScreen()),
    );
    _loadFinancialData(); // Recargar balance por si hubo movimientos
  }

  void _openPendingPayments() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DebtScreen()),
    );
    _loadFinancialData();
  }
}

// ==========================================
// WIDGETS PERSONALIZADOS
// ==========================================

class _RecentActivityList extends StatelessWidget {
  final Color cardColor;
  final Color primaryGreen;
  final Color expenseRed;
  final Color textGrey;
  final List<Map<String, dynamic>> transactions;
  final Map<String, double> currentRates;

  const _RecentActivityList({
    required this.cardColor,
    required this.primaryGreen,
    required this.expenseRed,
    required this.textGrey,
    required this.transactions, // Corregido: requerido en constructor
    required this.currentRates,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Actividad Reciente',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            _BouncingWidget(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WalletScreen()),
              ),
              child: Text(
                'Ver todo',
                style: GoogleFonts.poppins(color: textGrey),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (transactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            child: Text(
              "Sin movimientos recientes",
              style: GoogleFonts.poppins(color: textGrey.withOpacity(0.5)),
            ),
          )
        else
          ...transactions.map((t) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _ActivityCard(
                transaction: t,
                cardColor: cardColor,
                primaryGreen: primaryGreen,
                expenseRed: expenseRed,
                textGrey: textGrey,
                currentRates: currentRates,
              ),
            );
          }).toList(),
      ],
    );
  }
}

class _ActivityCard extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final Color cardColor;
  final Color primaryGreen;
  final Color expenseRed;
  final Color textGrey;
  final Map<String, double> currentRates;

  const _ActivityCard({
    Key? key,
    required this.transaction,
    required this.cardColor,
    required this.primaryGreen,
    required this.expenseRed,
    required this.textGrey,
    required this.currentRates,
  }) : super(key: key);

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  int _displayMode = 0; // 0: Original, 1: USD (BCV), 2: VES

  void _toggleMode() {
    final t = widget.transaction;
    if (t['originalCurrency'] == 'USD_CASH')
      return; // El efectivo es independiente
    setState(() {
      _displayMode = (_displayMode + 1) % 3;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transaction;
    final bool isExpense = t['isExpense'] ?? true;
    // Conversión segura a double
    // Preferimos originalAmount si existe, sino amountInUSD (legacy)
    final dynamic rawOriginal = t['originalAmount'];
    final dynamic rawLegacy = t['amountInUSD'];

    double amount = 0.0;
    if (rawOriginal is num) {
      amount = rawOriginal.toDouble();
    } else if (rawLegacy is num)
      amount = rawLegacy.toDouble();
    else
      amount =
          double.tryParse(
            rawOriginal?.toString() ?? rawLegacy?.toString() ?? '0',
          ) ??
          0.0;

    final String title = t['title'] ?? 'Movimiento';
    final String originalCurrency = t['originalCurrency'] ?? 'USD';

    // Calcular valores para los modos
    double displayVal = amount;
    String displaySymbol = '\$';
    String displayLabel = originalCurrency;

    if (originalCurrency == 'USD_CASH') {
      // Modo único para efectivo
      displayVal = amount;
      displaySymbol = '\$';
      displayLabel = 'Efectivo';
    } else {
      // Modos alternables
      if (_displayMode == 0) {
        // Original
        displayVal = amount;
        displaySymbol = originalCurrency == 'VES'
            ? 'Bs'
            : (originalCurrency == 'EUR' ? '€' : '\$');
        displayLabel = originalCurrency;
      } else if (_displayMode == 1) {
        // USD (BCV)
        final double amountInVES = (t['amountInVES'] ?? 0).toDouble();
        final double bcv = widget.currentRates['BCV'] ?? 1.0;
        displayVal = amountInVES / (bcv > 0 ? bcv : 1);
        displaySymbol = '\$';
        displayLabel = 'BCV';
      } else {
        // VES
        displayVal = (t['amountInVES'] ?? 0).toDouble();
        displaySymbol = 'Bs';
        displayLabel = 'Bolívares';
      }
    }

    // Parseo de fecha seguro
    final DateTime date =
        DateTime.tryParse(t['date'].toString()) ?? DateTime.now();
    final String dateString = DateFormat('dd/MM HH:mm').format(date);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.cardColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF071925),
              shape: BoxShape.circle,
              border: Border.all(color: widget.textGrey.withOpacity(0.2)),
            ),
            child: Icon(
              isExpense ? Icons.arrow_upward : Icons.arrow_downward,
              color: isExpense ? widget.expenseRed : widget.primaryGreen,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$dateString • $displayLabel',
                  style: GoogleFonts.poppins(
                    color: widget.textGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _toggleMode,
            child: Container(
              color: Colors.transparent, // Hitbox area
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isExpense ? "-" : "+"}$displaySymbol${NumberFormat.currency(symbol: '', decimalDigits: 2).format(displayVal)}',
                    style: GoogleFonts.poppins(
                      color: isExpense
                          ? widget.expenseRed
                          : widget.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SavingsBanner extends StatelessWidget {
  final VoidCallback onTap;
  // Key habilitada
  const _SavingsBanner({Key? key, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: _BouncingWidget(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF132B3D), Color(0xFF0F2231)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ADE80).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.savings,
                  color: Color(0xFF4ADE80),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mi Alcancía',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Gestiona tus metas de ahorro',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFB0BEC5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white24,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingPaymentsBanner extends StatelessWidget {
  final int count;
  final double amountVES;
  final Map<String, double> rates;
  final String displayMode;
  final VoidCallback onTap;
  final bool obscureBalances;

  const _PendingPaymentsBanner({
    // Key habilitada
    Key? key,
    required this.count,
    required this.amountVES,
    required this.rates,
    required this.displayMode,
    required this.onTap,
    required this.obscureBalances,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calcular monto a mostrar según displayMode
    double displayAmount = amountVES;
    String symbol = 'Bs';
    final rate = rates[displayMode] ?? 1.0;

    if (displayMode != 'VES') {
      displayAmount = amountVES / (rate == 0 ? 1 : rate);
      if (displayMode == 'EURO') {
        symbol = '€';
      } else if (displayMode == 'USDT')
        symbol = '₮';
      else
        symbol = '\$';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: _BouncingWidget(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF132B3D), Color(0xFF0F2231)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB74D).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: Color(0xFFFFB74D),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pagos Programados',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      count == 0
                          ? 'Estás al día'
                          : '$count pendientes • ${obscureBalances ? "****" : "$symbol${displayAmount.toStringAsFixed(2)}"}',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFB0BEC5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white24,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Pantalla de Calculadora de Tasas (BottomSheet)
class _CurrencyCalculatorSheet extends StatefulWidget {
  final Map<String, double> rates;
  const _CurrencyCalculatorSheet({Key? key, required this.rates})
    : super(key: key);

  @override
  State<_CurrencyCalculatorSheet> createState() =>
      _CurrencyCalculatorSheetState();
}

class _CurrencyCalculatorSheetState extends State<_CurrencyCalculatorSheet> {
  final GlobalKey _globalKey = GlobalKey();
  String _amount = '';
  String _baseCurrency = 'USD'; // USD, VES
  final List<String> _selectedRates = ['BCV'];

  late Map<String, double> _activeRates;
  DateTime? _selectedDate;
  List<Map<String, dynamic>> _history = [];
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _activeRates = widget.rates;
    _loadHistory();
    _initNotifications();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);

    // Solicitar permiso en Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> _showSuccessNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final bool notificationsEnabled =
        prefs.getBool('notifications_enabled') ?? true;

    if (!notificationsEnabled) return;

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'rinde_channel',
          'Notificaciones RINDE',
          channelDescription: 'Notificaciones de guardado',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );
    await _notificationsPlugin.show(
      0,
      'RINDE',
      'Se ha guardado en galería',
      notificationDetails,
    );
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('rates_history_data');
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      if (mounted) {
        setState(() {
          _history = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    }
  }

  void _pickDate() async {
    final DateTime now = DateTime.now();

    // Pre-calcular fechas disponibles para el predicado (Días con historial)
    final Set<String> availableDates = _history.map((e) {
      final d = DateTime.parse(e['date']);
      return DateFormat('yyyy-MM-dd').format(d);
    }).toSet();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
      selectableDayPredicate: (DateTime day) {
        final dateStr = DateFormat('yyyy-MM-dd').format(day);
        final todayStr = DateFormat('yyyy-MM-dd').format(now);
        // Permitir hoy o días con historial registrado
        return dateStr == todayStr || availableDates.contains(dateStr);
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF4ADE80),
              onPrimary: Color(0xFF132B3D),
              surface: Color(0xFF132B3D),
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF071925),
            ),
          ),
          child: child!,
        );
      },
    );

    if (!mounted) return;

    if (picked != null) {
      final isToday =
          picked.year == now.year &&
          picked.month == now.month &&
          picked.day == now.day;

      if (isToday) {
        setState(() {
          _selectedDate = null;
          _activeRates = widget.rates;
        });
        return;
      }

      final entry = _findRateForDate(picked);
      if (entry != null) {
        setState(() {
          _selectedDate = picked;
          _activeRates = Map<String, double>.from(
            entry['rates'].map((k, v) => MapEntry(k, (v as num).toDouble())),
          );
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No hay tasas registradas para el ${DateFormat('dd/MM/yyyy').format(picked)}',
            ),
            backgroundColor: const Color(0xFFFF5252),
          ),
        );
      }
    }
  }

  Map<String, dynamic>? _findRateForDate(DateTime date) {
    final entriesOnDay = _history.where((e) {
      final d = DateTime.parse(e['date']);
      return d.year == date.year && d.month == date.month && d.day == date.day;
    }).toList();

    if (entriesOnDay.isNotEmpty) {
      entriesOnDay.sort(
        (a, b) =>
            DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])),
      );
      return entriesOnDay.first;
    }
    return null;
  }

  void _onKeyTap(String value) {
    if (value == '.' && _amount.contains('.')) return;
    if (_amount.length < 12) {
      HapticFeedback.lightImpact();
      setState(() {
        _amount += value;
      });
    }
  }

  void _onBackspace() {
    if (_amount.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _amount = _amount.substring(0, _amount.length - 1);
      });
    }
  }

  void _onClear() {
    HapticFeedback.mediumImpact();
    setState(() {
      _amount = '';
    });
  }

  void _toggleCurrency() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_baseCurrency == 'VES') {
        _baseCurrency = 'USD';
      } else {
        _baseCurrency = 'VES';
      }
    });
  }

  Future<void> _capturePng() async {
    try {
      // Verificar permisos explícitamente antes de capturar
      bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        hasAccess = await Gal.requestAccess();
        if (!hasAccess) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Se requiere acceso a la galería'),
                backgroundColor: Color(0xFFFF5252),
              ),
            );
          }
          return;
        }
      }

      HapticFeedback.mediumImpact();
      if (_globalKey.currentContext == null) return;

      RenderRepaintBoundary boundary =
          _globalKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;

      // Usar pixelRatio del dispositivo (limitado a 3.0 para evitar errores de memoria)
      double pixelRatio = MediaQuery.of(context).devicePixelRatio;
      if (pixelRatio > 3.0) pixelRatio = 3.0;

      ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();

        try {
          await Gal.putImageBytes(
            pngBytes,
            name: "RINDE_${DateTime.now().millisecondsSinceEpoch}",
          );

          if (mounted) {
            _showSuccessNotification();
          }
        } catch (e) {
          debugPrint(e.toString());
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error al guardar'),
                backgroundColor: Color(0xFFFF5252),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  void didUpdateWidget(_CurrencyCalculatorSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rates != oldWidget.rates && _selectedDate == null) {
      setState(() {
        _activeRates = widget.rates;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double val = double.tryParse(_amount) ?? 0.0;
    const primaryGreen = Color(0xFF4ADE80);
    const cardColor = Color(0xFF132B3D);
    const textGrey = Color(0xFFB0BEC5);

    // Tasas base
    final bcv = _activeRates['BCV'] ?? 0.0;
    final usdt = _activeRates['USDT'] ?? 0.0;
    final euro = _activeRates['EURO'] ?? 0.0;

    final bool isHistorical = _selectedDate != null;
    final Color dateColor = isHistorical ? const Color(0xFFFFC107) : textGrey;

    // Cálculo de responsividad para el teclado
    final double screenWidth = MediaQuery.of(context).size.width;
    // Ancho disponible = Pantalla - Padding Horizontal (24*2) - Espaciado Grid (10*2)
    final double availableWidth = screenWidth - 48 - 20;
    final double itemWidth = availableWidth / 3;
    final double itemHeight = 60.0; // Altura fija cómoda para los botones
    final double childAspectRatio = itemWidth / itemHeight;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F2231),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(height: 4, width: 40, color: Colors.white24),
            const SizedBox(height: 20),

            // --- ÁREA DE CAPTURA (Solo el recibo) ---
            RepaintBoundary(
              key: _globalKey,
              child: Container(
                color: const Color(0xFF0F2231), // Fondo para la imagen
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    // Logo RINDE
                    Image.asset(
                      'assets/images/logo.png',
                      height: 40,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: 40,
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Header: Tasas en vivo (Motor de Agregación)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isHistorical
                                  ? const Color(0xFFFFC107).withOpacity(0.1)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: isHistorical
                                  ? Border.all(
                                      color: const Color(
                                        0xFFFFC107,
                                      ).withOpacity(0.3),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: dateColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isHistorical
                                      ? DateFormat(
                                          'dd/MM/yy',
                                        ).format(_selectedDate!)
                                      : 'Hoy',
                                  style: GoogleFonts.poppins(
                                    color: dateColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'BCV: ${bcv.toStringAsFixed(2)}  |  USDT: ${usdt.toStringAsFixed(2)}  |  EUR: ${euro.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(
                            color: textGrey,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Input Principal
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Monto a convertir',
                                style: GoogleFonts.poppins(
                                  color: textGrey,
                                  fontSize: 12,
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _amount.isEmpty ? '0' : _amount,
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _baseCurrency,
                                    style: GoogleFonts.poppins(
                                      color: primaryGreen,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: _toggleCurrency,
                                    child: const Icon(
                                      Icons.swap_vert,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Resultados
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: Column(
                        children: _buildDynamicResults(val, primaryGreen),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- FIN ÁREA DE CAPTURA ---
            const SizedBox(height: 24),

            // Keypad (Fuera de la captura)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 12,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: childAspectRatio, // Ratio dinámico
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                if (index == 9) {
                  return _buildKey('.');
                }
                if (index == 11) {
                  return InkWell(
                    onTap: _onBackspace,
                    onLongPress: _onClear,
                    borderRadius: BorderRadius.circular(30),
                    child: const Center(
                      child: Icon(
                        Icons.backspace_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  );
                }
                if (index == 10) {
                  return _buildKey('0');
                }
                return _buildKey('${index + 1}');
              },
            ),

            const SizedBox(height: 24),

            // Botón GUARDAR (Fuera de la captura)
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _capturePng,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'GUARDAR IMAGEN',
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
      ),
    );
  }

  List<Widget> _buildDynamicResults(double val, Color primaryGreen) {
    return [
      ..._selectedRates.asMap().entries.map((entry) {
        final index = entry.key;
        final rateKey = entry.value;
        final isLast = index == _selectedRates.length - 1;

        return Column(
          children: [
            _buildDynamicRow(index, rateKey, val, primaryGreen),
            if (!isLast) const Divider(color: Colors.white10, height: 24),
          ],
        );
      }).toList(),
      const SizedBox(height: 16),
      InkWell(
        onTap: () {
          setState(() {
            _selectedRates.add('BCV');
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.add, color: Colors.white54, size: 20),
        ),
      ),
    ];
  }

  Widget _buildDynamicRow(
    int index,
    String rateKey,
    double val,
    Color primaryGreen,
  ) {
    final double rate = _activeRates[rateKey] ?? 1.0;
    final double effectiveRate = rate > 0 ? rate : 1.0;
    final Color rowColor = rateKey == 'BCV' ? primaryGreen : Colors.white;

    double result;
    String symbol;

    if (_baseCurrency == 'VES') {
      result = val / effectiveRate;
      symbol = rateKey == 'EURO' ? '€' : '\$';
    } else {
      result = val * effectiveRate;
      symbol = 'Bs';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: rateKey,
            dropdownColor: const Color(0xFF132B3D),
            icon: Icon(Icons.arrow_drop_down, color: primaryGreen),
            style: GoogleFonts.poppins(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            items: ['BCV', 'USDT', 'EURO', 'CUSTOM'].map((String value) {
              String label = value;
              if (value == 'CUSTOM') label = 'Personalizada';
              return DropdownMenuItem<String>(value: value, child: Text(label));
            }).toList(),
            onChanged: (newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedRates[index] = newValue;
                });
              }
            },
          ),
        ),
        _buildResultValue(result, symbol, effectiveRate, rowColor),
      ],
    );
  }

  Widget _buildResultValue(
    double value,
    String symbol,
    double effectiveRate,
    Color color,
  ) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Text(
                  '$symbol ${value.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: value.toStringAsFixed(2)),
                    );
                    HapticFeedback.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Copiado: ${value.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(),
                        ),
                        duration: const Duration(seconds: 1),
                        backgroundColor: color,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.copy,
                    size: 16,
                    color: Colors.white24,
                  ),
                ),
              ],
            ),
            Text(
              '@ ${effectiveRate.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(color: Colors.white24, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(String label) {
    return InkWell(
      onTap: () => _onKeyTap(label),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ==========================================
// COMPONENTES EXISTENTES (Headers y Cards)
// ==========================================

class _Header extends StatelessWidget {
  final String userName;
  const _Header({Key? key, required this.userName})
    : super(key: key); // Key habilitada

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bienvenido de vuelta,', style: theme.bodyLarge),
              Text(
                userName,
                style: theme.headlineMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RateHistoryScreen(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF132B3D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Icon(
              Icons.history, // Icono cambiado para reflejar la funcionalidad
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}

class _MainInfoCards extends StatelessWidget {
  final PageController pageController;
  final Color cardColor;
  final Color primaryGreen;
  final Map<String, dynamic> displayData;
  final VoidCallback onToggleMode;
  final bool allHabitsDone;
  final bool obscureBalances;
  final Map<String, double> currencyBalances;
  final List<Map<String, dynamic>> rateHistory;
  final Map<String, double> currentRates;
  final double cashBalance;
  final double totalSaved;
  final double totalGoal;
  final VoidCallback onSavingsTap;

  const _MainInfoCards({
    // Key habilitada
    Key? key,
    required this.pageController,
    required this.cardColor,
    required this.primaryGreen,
    required this.displayData,
    required this.onToggleMode,
    required this.allHabitsDone,
    required this.obscureBalances,
    required this.currencyBalances,
    required this.rateHistory,
    required this.currentRates,
    required this.cashBalance,
    required this.totalSaved,
    required this.totalGoal,
    required this.onSavingsTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: pageController,
            itemCount: 3,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: index == 0
                    ? _PowerCard(
                        cardColor: cardColor,
                        primaryGreen: primaryGreen,
                        amount: displayData['amount'],
                        symbol: displayData['symbol'],
                        label: displayData['label'],
                        onTap: onToggleMode,
                        cashBalance: cashBalance,
                        plantIsHealthy: allHabitsDone,
                        obscureBalances: obscureBalances,
                      )
                    : _InfoCard(
                        index: index,
                        cardColor: cardColor,
                        primaryGreen: primaryGreen,
                        currencyBalances: currencyBalances,
                        rateHistory: rateHistory,
                        currentRates: currentRates,
                        totalSaved: totalSaved,
                        totalGoal: totalGoal,
                        onSavingsTap: onSavingsTap,
                      ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        SmoothPageIndicator(
          controller: pageController,
          count: 3,
          onDotClicked: (index) => pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          ),
          effect: ExpandingDotsEffect(
            activeDotColor: primaryGreen,
            dotColor: Colors.white24,
            dotHeight: 8,
            dotWidth: 8,
            expansionFactor: 4,
            spacing: 6,
          ),
        ),
      ],
    );
  }
}

class _PowerCard extends StatelessWidget {
  final Color cardColor;
  final Color primaryGreen;
  final double amount;
  final String symbol;
  final String label;
  final VoidCallback onTap;
  final double cashBalance;
  final bool plantIsHealthy;
  final bool obscureBalances;

  const _PowerCard({
    required this.cardColor,
    required this.primaryGreen,
    required this.amount,
    required this.symbol,
    required this.label,
    required this.onTap,
    required this.cashBalance,
    required this.plantIsHealthy,
    required this.obscureBalances,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return _BouncingWidget(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Poder de Compra', style: theme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  obscureBalances
                      ? '$symbol ****'
                      : '$symbol${amount.toStringAsFixed(2)}',
                  style: theme.headlineLarge?.copyWith(fontSize: 38),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.poppins(
                          color: primaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (cashBalance > 0 && !obscureBalances) ...[
                      const SizedBox(width: 12),
                      Container(height: 20, width: 1, color: Colors.white24),
                      const SizedBox(width: 12),
                      Text(
                        'Efectivo: \$${cashBalance.toStringAsFixed(2)}',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFFFD700),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            Positioned(
              right: 0,
              bottom: 0,
              top: 0,
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: plantIsHealthy ? 1.0 : 0.5,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: plantIsHealthy
                            ? [
                                primaryGreen.withOpacity(0.3),
                                Colors.transparent,
                              ]
                            : [
                                Colors.grey.withOpacity(0.1),
                                Colors.transparent,
                              ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                        color: plantIsHealthy ? null : Colors.grey,
                        colorBlendMode: plantIsHealthy ? null : BlendMode.srcIn,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.local_florist,
                            color: plantIsHealthy ? primaryGreen : Colors.grey,
                            size: 40,
                          );
                        },
                      ),
                    ),
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

// ==========================================
// WIDGET DE ANIMACIÓN DE REBOTE
// ==========================================

class _BouncingWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final HitTestBehavior behavior;
  const _BouncingWidget({
    Key? key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.95,
    this.behavior = HitTestBehavior.opaque,
  }) : super(key: key);

  @override
  State<_BouncingWidget> createState() => _BouncingWidgetState();
}

class _BouncingWidgetState extends State<_BouncingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!();
        }
      },
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final int index;
  final Color cardColor;
  final Color primaryGreen;
  final Map<String, double>? currencyBalances;
  final List<Map<String, dynamic>>? rateHistory;
  final Map<String, double>? currentRates;
  final double totalSaved;
  final double totalGoal;
  final VoidCallback? onSavingsTap;

  const _InfoCard({
    required this.index,
    required this.cardColor,
    required this.primaryGreen,
    this.currencyBalances,
    this.rateHistory,
    this.currentRates,
    this.totalSaved = 0,
    this.totalGoal = 0,
    this.onSavingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final title = index == 1 ? 'Inflación Personal' : 'Meta de Ahorro';
    final icon = index == 1 ? Icons.trending_up : Icons.flag_outlined;

    // Lógica para mostrar resumen en la tarjeta de Inflación
    String mainText = '';
    String subText = '';

    if (index == 1 && currencyBalances != null) {
      // Calcular resumen rápido
      double vesBalance = currencyBalances!['VES'] ?? 0;
      double cashBalance = currencyBalances!['USD_CASH'] ?? 0;

      if (vesBalance > 0) {
        // Calcular pérdida aproximada
        // (Simplificado para la tarjeta, el detalle está en la otra pantalla)
        mainText = 'Ver Análisis';
        subText = 'Bs ${vesBalance.toStringAsFixed(0)} expuestos';
      } else if (cashBalance > 0) {
        mainText = 'Efectivo';
        subText = 'Balance: \$${cashBalance.toStringAsFixed(2)}';
      } else {
        mainText = 'Protegido';
        subText = 'Sin saldo en Bs';
      }
    } else {
      mainText =
          '\$${totalSaved.toStringAsFixed(0)} / \$${totalGoal.toStringAsFixed(0)}';
      subText = 'Toca para gestionar';
    }

    return GestureDetector(
      onTap: () {
        if (index == 1) {
          // Navegar a detalle de inflación
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InflationDetailScreen(
                balances: currencyBalances ?? {},
                history: rateHistory ?? [],
                currentRates: currentRates ?? {},
              ),
            ),
          );
        }
        if (index == 2 && onSavingsTap != null) {
          onSavingsTap!();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: theme.titleMedium),
                  const SizedBox(height: 12),
                  Text(
                    mainText,
                    style: theme.headlineLarge?.copyWith(fontSize: 28),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subText,
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      if (index == 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.touch_app,
                                size: 12,
                                color: primaryGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Toca para detalles',
                                style: GoogleFonts.poppins(
                                  color: primaryGreen,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(icon, color: primaryGreen, size: 34),
          ],
        ),
      ),
    );
  }
}
