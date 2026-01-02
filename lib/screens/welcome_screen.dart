import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart'; // Mantenemos el import por si se usa en el futuro
import 'home_screen.dart';
import '../services/simple_storage_service.dart';

/// Pantalla de bienvenida que solicita el nombre del usuario.
/// Mantiene la lógica de persistencia pero aplica el diseño visual de "RINDE".
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _nameController = TextEditingController();
  final SimpleStorageService _storageService = SimpleStorageService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkExistingUser();
  }

  /// Verifica si ya existe un usuario guardado para omitir esta pantalla.
  Future<void> _checkExistingUser() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _storageService.getUser();
      if (user != null && user.name.isNotEmpty) {
        // El usuario existe, navegar al home
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeScreen(userName: user.name),
            ),
          );
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

    return Scaffold(
      backgroundColor: const Color(
        0xFF071925,
      ), // Fondo azul oscuro específico del diseño
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF64E698)),
                ),
              )
            : Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal:
                        30.0, // Aumentado ligeramente para coincidir con el diseño
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      // -------------------------------------------------------
                      // LOGO AREA
                      // -------------------------------------------------------
                      Container(
                        height: 120,
                        alignment: Alignment.center,
                        child: FutureBuilder<bool>(
                          future: _pngExists(),
                          builder: (context, snapshot) {
                            Widget inner;
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              inner = const SizedBox(width: 100, height: 100);
                            } else if (snapshot.hasData &&
                                snapshot.data == true) {
                              inner = Image.asset(
                                'assets/images/logo.png',
                                width: 100,
                                height: 100,
                                fit: BoxFit.contain,
                              );
                            } else {
                              // Fallback visual si no hay asset: Icono o Placeholder
                              inner = Image.memory(
                                base64Decode(_placeholderPngBase64),
                                width: 100,
                                height: 100,
                                fit: BoxFit.contain,
                              );
                            }
                            return Center(child: inner);
                          },
                        ),
                      ),

                      const SizedBox(
                        height: 40,
                      ), // Espaciado ajustado al diseño
                      // -------------------------------------------------------
                      // TÍTULO
                      // -------------------------------------------------------
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

                      const SizedBox(
                        height: 40,
                      ), // Espaciado ajustado al diseño
                      // -------------------------------------------------------
                      // INPUT (CAMPO DE TEXTO)
                      // -------------------------------------------------------
                      _NameInput(controller: _nameController),

                      const SizedBox(height: 30),

                      // -------------------------------------------------------
                      // BOTÓN ACEPTAR
                      // -------------------------------------------------------
                      SizedBox(
                        width: 150, // Ancho fijo según diseño
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveUserAndNavigate,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF64E698,
                            ), // Verde menta brillante
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          child: const Text(
                            'Aceptar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
      ),
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
