import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LockMode { create, verify, disable }

class LockScreen extends StatefulWidget {
  final LockMode mode;
  final Widget? nextScreen; // Pantalla a la que ir si es éxito (para el inicio)

  const LockScreen({Key? key, required this.mode, this.nextScreen})
    : super(key: key);

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  String _pin = '';
  String _confirmPin = ''; // Para cuando se está creando
  bool _isConfirming = false; // Estado intermedio de creación
  String _message = 'Ingresa tu PIN';
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.mode == LockMode.create) {
      setState(() => _message = 'Crea un PIN de 4 dígitos');
    } else {
      // Verificar si hay biometría disponible
      try {
        final bool canAuthenticateWithBiometrics =
            await auth.canCheckBiometrics;
        final bool canAuthenticate =
            canAuthenticateWithBiometrics || await auth.isDeviceSupported();

        if (canAuthenticate && widget.mode == LockMode.verify) {
          setState(() => _canCheckBiometrics = true);
          _authenticateBiometric();
        }
      } catch (e) {
        debugPrint('Error biometría: $e');
      }
    }
  }

  Future<void> _authenticateBiometric() async {
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Desbloquea para acceder a RINDE',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (didAuthenticate) {
        _onSuccess();
      }
    } catch (e) {
      debugPrint('Auth error: $e');
    }
  }

  void _onKeyTap(String value) {
    if (_pin.length < 4) {
      HapticFeedback.lightImpact();
      setState(() {
        _pin += value;
      });
      if (_pin.length == 4) {
        _handlePinComplete();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _handlePinComplete() async {
    final prefs = await SharedPreferences.getInstance();

    if (widget.mode == LockMode.create) {
      if (!_isConfirming) {
        // Primera fase de creación
        setState(() {
          _confirmPin = _pin;
          _pin = '';
          _isConfirming = true;
          _message = 'Confirma tu PIN';
        });
      } else {
        // Fase de confirmación
        if (_pin == _confirmPin) {
          await prefs.setString('user_pin', _pin);
          _onSuccess();
        } else {
          _onError('Los PIN no coinciden. Intenta de nuevo.');
          setState(() {
            _pin = '';
            _confirmPin = '';
            _isConfirming = false;
          });
        }
      }
    } else {
      // Modo Verificar o Deshabilitar
      final storedPin = prefs.getString('user_pin');
      if (_pin == storedPin) {
        _onSuccess();
      } else {
        _onError('PIN Incorrecto');
        setState(() {
          _pin = '';
        });
      }
    }
  }

  void _onSuccess() {
    HapticFeedback.mediumImpact();
    if (widget.nextScreen != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => widget.nextScreen!),
      );
    } else {
      Navigator.pop(context, true);
    }
  }

  void _onError(String msg) {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFFFF5252),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF071925);
    const primaryGreen = Color(0xFF4ADE80);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.lock_outline, size: 50, color: Colors.white),
            const SizedBox(height: 20),
            Text(
              _message,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),

            // Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final filled = index < _pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: filled
                        ? primaryGreen
                        : Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: filled
                          ? primaryGreen
                          : Colors.white.withOpacity(0.3),
                    ),
                  ),
                );
              }),
            ),

            const Spacer(),

            // Keypad
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 12,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemBuilder: (context, index) {
                  if (index == 9) {
                    // Biometric Button (Bottom Left)
                    return _canCheckBiometrics && widget.mode != LockMode.create
                        ? InkWell(
                            onTap: _authenticateBiometric,
                            borderRadius: BorderRadius.circular(40),
                            child: const Icon(
                              Icons.fingerprint,
                              color: primaryGreen,
                              size: 32,
                            ),
                          )
                        : const SizedBox();
                  }
                  if (index == 11) {
                    // Backspace (Bottom Right)
                    return InkWell(
                      onTap: _onBackspace,
                      borderRadius: BorderRadius.circular(40),
                      child: const Icon(
                        Icons.backspace_outlined,
                        color: Colors.white,
                        size: 28,
                      ),
                    );
                  }

                  String val = '${index + 1}';
                  if (index == 10) val = '0';

                  return _buildKey(val);
                },
              ),
            ),
            const SizedBox(height: 40),
            if (widget.mode == LockMode.create ||
                widget.mode == LockMode.disable)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.poppins(color: Colors.white54),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(String val) {
    return InkWell(
      onTap: () => _onKeyTap(val),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
        ),
        child: Text(
          val,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
