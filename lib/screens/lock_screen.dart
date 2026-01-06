import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';

enum LockMode { create, verify, disable }

class LockScreen extends StatefulWidget {
  final LockMode mode;
  final Widget? nextScreen;

  const LockScreen({Key? key, required this.mode, this.nextScreen})
    : super(key: key);

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    // Intentar autenticar automáticamente al iniciar si es modo verificación
    if (widget.mode == LockMode.verify) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      setState(() => _isAuthenticating = true);

      // Verificar disponibilidad de hardware
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        // Si el dispositivo no tiene seguridad, podrías decidir dejar pasar o bloquear.
        // Por defecto, local_auth maneja esto, pero es bueno saberlo.
      }

      authenticated = await auth.authenticate(
        localizedReason: 'Autentícate para acceder a RINDE',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // Permite PIN/Patrón si falla la huella
        ),
      );
    } on PlatformException catch (e) {
      debugPrint("Error Auth: $e");
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }

    if (authenticated && mounted) {
      if (widget.nextScreen != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => widget.nextScreen!),
        );
      } else {
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071925),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Color(0xFF4ADE80)),
            const SizedBox(height: 24),
            Text(
              'RINDE Bloqueado',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Toca el botón para desbloquear con tu huella o FaceID.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white54),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint, color: Color(0xFF071925)),
                label: Text(
                  'DESBLOQUEAR',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF071925),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4ADE80),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
