import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart' show SystemNavigator, rootBundle;
import 'package:google_fonts/google_fonts.dart'; // Mantenemos el import por si se usa en el futuro
import 'package:gal/gal.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'home_screen.dart';
import '../services/simple_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'lock_screen.dart';

/// Pantalla de bienvenida que solicita el nombre del usuario.
/// Mantiene la lógica de persistencia pero aplica el diseño visual de "RINDE".
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final SimpleStorageService _storageService = SimpleStorageService();
  bool _isLoading = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _animController;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      'title': 'Bienvenido a RINDE',
      'desc':
          'Tu asistente financiero inteligente para el control de gastos e ingresos en Venezuela.',
    },
    {
      'title': 'Control Multimoneda',
      'desc':
          'Registra movimientos en Bs y Divisas. Visualiza tu balance unificado al instante.',
    },
    {
      'title': 'Automatización',
      'desc':
          'Programa pagos recurrentes, gestiona deudas y crea metas de ahorro fácilmente.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _handlePermissionsAndInit();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  Future<void> _handlePermissionsAndInit() async {
    // Request gallery permission
    final bool galleryGranted = await Gal.requestAccess();
    if (!galleryGranted && mounted) {
      _showPermissionDeniedDialog('acceso a la galería');
      return;
    }

    // Request notification permission (for Android 13+)
    final FlutterLocalNotificationsPlugin notificationsPlugin =
        FlutterLocalNotificationsPlugin();
    final bool? notificationsGranted = await notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    if (notificationsGranted == false && mounted) {
      _showPermissionDeniedDialog('notificaciones');
      return;
    }

    // If all permissions are granted, proceed with the app flow.
    _checkExistingUser();
  }

  void _showPermissionDeniedDialog(String permissionName) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF132B3D),
        title: Text(
          'Permiso Requerido',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        content: Text(
          'El permiso para $permissionName es fundamental para el funcionamiento de la aplicación. La app se cerrará.',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text(
              'Cerrar Aplicación',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  /// Verifica si ya existe un usuario guardado para omitir esta pantalla.
  Future<void> _checkExistingUser() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _storageService.getUser();
      if (user != null && user.name.isNotEmpty) {
        // El usuario existe, verificar si tiene bloqueo activado
        final prefs = await SharedPreferences.getInstance();
        final bool isLocked = prefs.getBool('app_lock_enabled') ?? false;

        if (mounted) {
          if (isLocked) {
            // Ir a pantalla de bloqueo, y si pasa, ir a Home
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => LockScreen(
                  mode: LockMode.verify,
                  nextScreen: HomeScreen(userName: user.name),
                ),
              ),
            );
          } else {
            // Ir directo a Home
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => HomeScreen(userName: user.name),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Manejo de errores silencioso en consola para no interrumpir UX
      debugPrint('Error checking user: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  /// Guarda el nombre del usuario y navega a la pantalla principal.
  Future<void> _saveUserAndNavigate() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, introduce tu nombre'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Guardar usuario en base de datos local
      await _storageService.saveUser(name);

      // Navegar a home
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomeScreen(userName: name)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar usuario: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Placeholder original en base64 para cuando no carga el asset
  static const _placeholderPngBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAQAAAAAYLlVAAAAKUlEQVR4Ae3BAQ0AAADCoPdPbQ43oAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAL4GkAAG2h0QJAAAAAElFTkSuQmCC';

  @override
  Widget build(BuildContext context) {
    // Nota: Ignoramos parcialmente el Theme global para asegurar
    // que esta pantalla específica coincida con el diseño de la imagen "RINDE".

    const primaryGreen = Color(0xFF64E698);

    return Scaffold(
      backgroundColor: const Color(
        0xFF071925,
      ), // Fondo azul oscuro específico del diseño
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryGreen),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemCount: _onboardingData.length + 1,
                      itemBuilder: (context, index) {
                        if (index < _onboardingData.length) {
                          return _buildOnboardingSlide(
                            _onboardingData[index],
                            index,
                          );
                        } else {
                          return _buildRegistrationSlide();
                        }
                      },
                    ),
                  ),

                  // Controles Inferiores (Indicadores y Botón Siguiente)
                  Padding(
                    padding: const EdgeInsets.all(30.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SmoothPageIndicator(
                          controller: _pageController,
                          count: _onboardingData.length + 1,
                          effect: const ExpandingDotsEffect(
                            activeDotColor: primaryGreen,
                            dotColor: Colors.white24,
                            dotHeight: 8,
                            dotWidth: 8,
                            expansionFactor: 4,
                          ),
                        ),

                        // Botón Siguiente (Oculto en la última página porque ahí está "Aceptar")
                        if (_currentPage < _onboardingData.length)
                          TextButton(
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Text(
                              'Siguiente',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildOnboardingSlide(Map<String, dynamic> data, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ilustración Generada por Código (Sin Assets)
          _buildIllustration(index),

          const SizedBox(height: 40),
          Text(
            data['title'],
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data['desc'],
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: const Color(0xFFB0BEC5),
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustration(int index) {
    return SizedBox(
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (index == 0) ..._buildScene0(),
          if (index == 1) ..._buildScene1(),
          if (index == 2) ..._buildScene2(),
        ],
      ),
    );
  }

  // Escena 1: Bienvenida (Formas abstractas y saludo)
  List<Widget> _buildScene0() {
    return [
      Positioned(
        top: 20,
        right: 30,
        child: _AnimatedBlob(
          color: const Color(0xFF64E698).withOpacity(0.2),
          size: 100,
          controller: _animController,
          phase: 0.0,
        ),
      ),
      Positioned(
        bottom: 40,
        left: 20,
        child: _AnimatedBlob(
          color: const Color(0xFF64B5F6).withOpacity(0.2),
          size: 140,
          controller: _animController,
          phase: 0.5,
        ),
      ),
      _FloatingCard(
        controller: _animController,
        icon: Icons.waving_hand_rounded,
        color: const Color(0xFF64E698),
      ),
    ];
  }

  // Escena 2: Multimoneda (Burbujas flotantes intercambiando)
  List<Widget> _buildScene1() {
    return [
      Positioned(
        top: 40,
        left: 40,
        child: _AnimatedBlob(
          color: const Color(0xFFFFB74D).withOpacity(0.2),
          size: 80,
          controller: _animController,
          phase: 0.2,
        ),
      ),
      Positioned(
        bottom: 20,
        right: 20,
        child: _AnimatedBlob(
          color: const Color(0xFF64E698).withOpacity(0.2),
          size: 120,
          controller: _animController,
          phase: 0.7,
        ),
      ),
      // Burbujas de Moneda
      Positioned(
        left: 60,
        child: _FloatingBubble(
          text: '\$',
          color: const Color(0xFF64E698),
          controller: _animController,
          phase: 0.0,
        ),
      ),
      Positioned(
        right: 60,
        child: _FloatingBubble(
          text: 'Bs',
          color: const Color(0xFF64B5F6),
          controller: _animController,
          phase: 0.5,
        ),
      ),
      const Center(
        child: Icon(Icons.sync_alt, color: Colors.white24, size: 40),
      ),
    ];
  }

  // Escena 3: Automatización (Engranaje girando y calendario)
  List<Widget> _buildScene2() {
    return [
      Positioned(
        top: 30,
        left: 30,
        child: _AnimatedBlob(
          color: const Color(0xFFE57373).withOpacity(0.2),
          size: 90,
          controller: _animController,
          phase: 0.3,
        ),
      ),
      Positioned(
        bottom: 50,
        right: 40,
        child: _AnimatedBlob(
          color: const Color(0xFFBA68C8).withOpacity(0.2),
          size: 110,
          controller: _animController,
          phase: 0.8,
        ),
      ),

      _RotatingIcon(
        controller: _animController,
        icon: Icons.settings,
        color: Colors.white10,
        size: 180,
      ),
      _FloatingCard(
        controller: _animController,
        icon: Icons.savings_rounded,
        color: const Color(0xFFFFB74D),
      ),
    ];
  }

  Widget _buildRegistrationSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          // Logo Area
          Container(
            height: 100,
            alignment: Alignment.center,
            child: FutureBuilder<bool>(
              future: _pngExists(),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data == true) {
                  return Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  );
                }
                return Image.memory(
                  base64Decode(_placeholderPngBase64),
                  fit: BoxFit.contain,
                );
              },
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            '¿Cómo quieres\nque te llamemos?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 40),
          _NameInput(controller: _nameController),
          const SizedBox(height: 30),
          SizedBox(
            width: 150,
            height: 50,
            child: ElevatedButton(
              onPressed: _saveUserAndNavigate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF64E698),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text(
                'Aceptar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // Widget auxiliar para crear formas circulares de fondo
  Widget _buildBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Widget extraído para el Input, estilizado específicamente con bordes dorados
class _NameInput extends StatelessWidget {
  final TextEditingController controller;

  const _NameInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white), // Texto blanco
      cursorColor: const Color(0xFF64E698), // Cursor verde
      decoration: InputDecoration(
        hintText: 'Introduce tu nombre',
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.5), // Hint grisáceo
        ),
        filled: true,
        fillColor: const Color(0xFF132B3D), // Fondo del input (azul intermedio)
        contentPadding: const EdgeInsets.symmetric(
          vertical: 18.0,
          horizontal: 20.0,
        ),
        // Borde en estado normal (Dorado)
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFFC9A655), width: 1.0),
        ),
        // Borde cuando está seleccionado (Dorado más grueso)
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: Color(0xFFC9A655), width: 2.0),
        ),
      ),
    );
  }
}

/// Función auxiliar para verificar la existencia del asset
Future<bool> _pngExists() async {
  try {
    await rootBundle.load('assets/images/logo.png');
    return true;
  } catch (_) {
    return false;
  }
}

// --- WIDGETS DE ANIMACIÓN PERSONALIZADOS ---

class _AnimatedBlob extends StatelessWidget {
  final Color color;
  final double size;
  final AnimationController controller;
  final double phase;

  const _AnimatedBlob({
    required this.color,
    required this.size,
    required this.controller,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final val = math.sin((controller.value * 2 * math.pi) + phase);
        return Transform.scale(
          scale: 1.0 + (val * 0.1), // Escala pulsante
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        );
      },
    );
  }
}

class _FloatingCard extends StatelessWidget {
  final AnimationController controller;
  final IconData icon;
  final Color color;

  const _FloatingCard({
    required this.controller,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final val = math.sin(controller.value * 2 * math.pi);
        return Transform.translate(
          offset: Offset(0, val * 10), // Flota arriba/abajo
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: const Color(0xFF132B3D),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: color.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(icon, size: 60, color: color),
          ),
        );
      },
    );
  }
}

class _FloatingBubble extends StatelessWidget {
  final String text;
  final Color color;
  final AnimationController controller;
  final double phase;

  const _FloatingBubble({
    required this.text,
    required this.color,
    required this.controller,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final val = math.sin((controller.value * 2 * math.pi) + phase);
        return Transform.translate(
          offset: Offset(0, val * 15),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: const Color(0xFF071925),
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RotatingIcon extends StatelessWidget {
  final AnimationController controller;
  final IconData icon;
  final Color color;
  final double size;

  const _RotatingIcon({
    required this.controller,
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: controller.value * 2 * math.pi,
          child: Icon(icon, size: size, color: color),
        );
      },
    );
  }
}
