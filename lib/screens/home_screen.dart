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
import 'wallet_screen.dart'; // Asegúrate de que este archivo exista en la misma carpeta
import 'rate_history_screen.dart';
import 'analytics_screen.dart';
import '../services/exchange_rate_service.dart';

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
  Map<String, double> _rates = {
    'BCV': 52.5,
    'USDT': 54.2,
    'EURO': 56.1,
    'CUSTOM': 0.0,
  };
  String _currentDisplayMode = 'BCV'; // BCV, USDT, EURO, VES
  double _totalBalanceVES = 0.0;
  List<Map<String, dynamic>> _recentTransactions = [];

  // --- Animaciones ---
  late AnimationController _entranceController;
  late Animation<Offset> _headerSlideAnimation;
  late Animation<Offset> _carouselSlideAnimation;
  late Animation<Offset> _activitiesSlideAnimation;
  late Animation<double> _fadeAnimation;

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

    final String? data = prefs.getString('transactions_data');

    double totalVES = 0.0;
    List<Map<String, dynamic>> loadedRecent = [];

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

        if (isExpense) {
          totalVES -= amountVES;
        } else {
          totalVES += amountVES;
        }
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

    if (mounted) {
      setState(() {
        _totalBalanceVES = totalVES;
        _recentTransactions = loadedRecent;
      });
      // Intentar actualizar tasas online en segundo plano
      _updateRatesOnline();
    }
  }

  Future<void> _updateRatesOnline() async {
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

    setState(() {
      _selectedIndex = index;
    });
  }

  void _toggleDisplayMode() {
    setState(() {
      if (_currentDisplayMode == 'BCV')
        _currentDisplayMode = 'USDT';
      else if (_currentDisplayMode == 'USDT')
        _currentDisplayMode = 'EURO';
      else if (_currentDisplayMode == 'EURO') {
        if ((_rates['CUSTOM'] ?? 0) > 0)
          _currentDisplayMode = 'CUSTOM';
        else
          _currentDisplayMode = 'VES';
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
      if (_currentDisplayMode == 'EURO')
        symbol = '€';
      else if (_currentDisplayMode == 'USDT')
        symbol = '₮';
      else
        symbol = '\$';
      label = 'Indexado: $_currentDisplayMode';
    }
    return {'amount': amount, 'symbol': symbol, 'label': label};
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
                      child: _Header(userName: widget.userName),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 2. Carrusel
                  SlideTransition(
                    position: _carouselSlideAnimation,
                    child: _MainInfoCards(
                      pageController: _pageController,
                      cardColor: cardColor,
                      primaryGreen: primaryGreen,
                      displayData: displayData,
                      onToggleMode: _toggleDisplayMode,
                      allHabitsDone: true,
                    ),
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
                        transactions:
                            _recentTransactions, // Pasamos la lista corregida
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
                  child: FloatingActionButton(
                    onPressed: _showCalculatorSheet,
                    backgroundColor: cardColor,
                    elevation: 0,
                    shape: const CircleBorder(
                      side: BorderSide(color: primaryGreen, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                _buildNavItem(2, Icons.wallet, primaryGreen, textGrey),
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
    Color unselectedColor,
  ) {
    final isSelected = _selectedIndex == index;
    return _BouncingWidget(
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
}

// ==========================================
// WIDGETS PERSONALIZADOS
// ==========================================

class _RecentActivityList extends StatelessWidget {
  final Color cardColor;
  final Color primaryGreen;
  final Color expenseRed;
  final Color textGrey;
  final List<Map<String, dynamic>> transactions; // Corregido: recibe la lista

  const _RecentActivityList({
    required this.cardColor,
    required this.primaryGreen,
    required this.expenseRed,
    required this.textGrey,
    required this.transactions, // Corregido: requerido en constructor
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
              child: _buildActivityCard(t),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> t) {
    final bool isExpense = t['isExpense'] ?? true;
    // Conversión segura a double
    // Preferimos originalAmount si existe, sino amountInUSD (legacy)
    final dynamic rawOriginal = t['originalAmount'];
    final dynamic rawLegacy = t['amountInUSD'];

    double amount = 0.0;
    if (rawOriginal is num)
      amount = rawOriginal.toDouble();
    else if (rawLegacy is num)
      amount = rawLegacy.toDouble();
    else
      amount =
          double.tryParse(
            rawOriginal?.toString() ?? rawLegacy?.toString() ?? '0',
          ) ??
          0.0;

    final String title = t['title'] ?? 'Movimiento';
    final String currency = t['originalCurrency'] ?? 'USD';
    final String displayAmount = '\$${amount.toStringAsFixed(2)}';

    // Parseo de fecha seguro
    final DateTime date =
        DateTime.tryParse(t['date'].toString()) ?? DateTime.now();
    final String dateString = DateFormat('dd/MM HH:mm').format(date);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.8),
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
              border: Border.all(color: textGrey.withOpacity(0.2)),
            ),
            child: Icon(
              isExpense ? Icons.arrow_upward : Icons.arrow_downward,
              color: isExpense ? expenseRed : primaryGreen,
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
                  '$dateString • $currency',
                  style: GoogleFonts.poppins(color: textGrey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            isExpense ? '-$displayAmount' : '+$displayAmount',
            style: GoogleFonts.poppins(
              color: isExpense ? expenseRed : primaryGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// Pantalla de Calculadora de Tasas (BottomSheet)
class _CurrencyCalculatorSheet extends StatefulWidget {
  final Map<String, double> rates;

  const _CurrencyCalculatorSheet({required this.rates});

  @override
  State<_CurrencyCalculatorSheet> createState() =>
      _CurrencyCalculatorSheetState();
}

class _CurrencyCalculatorSheetState extends State<_CurrencyCalculatorSheet> {
  final GlobalKey _globalKey = GlobalKey();
  String _amount = '';
  String _baseCurrency = 'USD'; // USD, VES
  List<String> _selectedRates = ['BCV'];

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
            dialogBackgroundColor: const Color(0xFF071925),
          ),
          child: child!,
        );
      },
    );

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
  Widget build(BuildContext context) {
    final double val = double.tryParse(_amount) ?? 0.0;
    const primaryGreen = Color(0xFF4ADE80);
    const cardColor = Color(0xFF132B3D);
    const textGrey = Color(0xFFB0BEC5);

    // Tasas base
    final bcv = _activeRates['BCV'] ?? 0.0;
    final usdt = _activeRates['USDT'] ?? 0.0;

    final bool isHistorical = _selectedDate != null;
    final Color dateColor = isHistorical ? const Color(0xFFFFC107) : textGrey;

    return RepaintBoundary(
      key: _globalKey,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F2231),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(height: 4, width: 40, color: Colors.white24),
            const SizedBox(height: 20),

            // Logo RINDE
            Image.asset(
              'assets/images/logo.png',
              height: 40,
              fit: BoxFit.contain,
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
                              color: const Color(0xFFFFC107).withOpacity(0.3),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: dateColor),
                        const SizedBox(width: 6),
                        Text(
                          isHistorical
                              ? DateFormat('dd/MM/yy').format(_selectedDate!)
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
                  'BCV: ${bcv.toStringAsFixed(2)}  |  USDT: ${usdt.toStringAsFixed(2)}',
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
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(children: _buildDynamicResults(val, primaryGreen)),
            ),

            const SizedBox(height: 24),

            // Keypad
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 12,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.8,
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

            // Botón GUARDAR
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
                  'GUARDAR',
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
  const _Header({Key? key, required this.userName}) : super(key: key);

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

  const _MainInfoCards({
    required this.pageController,
    required this.cardColor,
    required this.primaryGreen,
    required this.displayData,
    required this.onToggleMode,
    required this.allHabitsDone,
  });

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
                        plantIsHealthy: allHabitsDone,
                      )
                    : _InfoCard(
                        index: index,
                        cardColor: cardColor,
                        primaryGreen: primaryGreen,
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
  final bool plantIsHealthy;

  const _PowerCard({
    required this.cardColor,
    required this.primaryGreen,
    required this.amount,
    required this.symbol,
    required this.label,
    required this.onTap,
    required this.plantIsHealthy,
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
                  '$symbol${amount.toStringAsFixed(2)}',
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
  const _InfoCard({
    required this.index,
    required this.cardColor,
    required this.primaryGreen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final title = index == 1 ? 'Inflación Personal' : 'Meta de Ahorro';
    final amount = index == 1 ? '+12.5%' : '\$200 / \$500';
    final icon = index == 1 ? Icons.trending_up : Icons.flag_outlined;

    return Container(
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
                  amount,
                  style: theme.headlineLarge?.copyWith(fontSize: 28),
                ),
              ],
            ),
          ),
          Icon(icon, color: primaryGreen, size: 34),
        ],
      ),
    );
  }
}
