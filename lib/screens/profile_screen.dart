import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/simple_storage_service.dart';
import 'lock_screen.dart';
import 'welcome_screen.dart';
import 'settings_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_conditions_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String userName;

  const ProfileScreen({Key? key, required this.userName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF071925);
    const cardColor = Color(0xFF132B3D);
    const primaryGreen = Color(0xFF4ADE80);
    const textGrey = Color(0xFFB0BEC5);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Perfil',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar & Name
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: cardColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryGreen, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person, size: 50, color: textGrey),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userName,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Usuario RINDE',
                    style: GoogleFonts.poppins(color: textGrey, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Settings Section
            _buildSectionHeader('General'),
            _buildOptionTile(
              context,
              icon: Icons.settings_outlined,
              title: 'Configuraciones',
              subtitle: 'Moneda base, notificaciones',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
            _buildOptionTile(
              context,
              icon: Icons.lock_outline,
              title: 'Privacidad y Seguridad',
              onTap: () {},
            ),

            const SizedBox(height: 24),

            _buildSectionHeader('Información'),
            _buildOptionTile(
              context,
              icon: Icons.description_outlined,
              title: 'Términos y Condiciones',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsConditionsScreen(),
                  ),
                );
              },
            ),
            _buildOptionTile(
              context,
              icon: Icons.privacy_tip_outlined,
              title: 'Políticas de Privacidad',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyScreen(),
                  ),
                );
              },
            ),
            _buildOptionTile(
              context,
              icon: Icons.info_outline,
              title: 'Acerca de RINDE',
              subtitle: 'Versión 1.0.0',
              onTap: () {},
            ),

            const SizedBox(height: 40),

            // Logout / Reset
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _showLogoutDialog(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Cerrar Sesión',
                  style: GoogleFonts.poppins(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'RINDE App © 2024',
              style: GoogleFonts.poppins(color: Colors.white10, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: GoogleFonts.poppins(
            color: const Color(0xFF4ADE80),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF132B3D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
              )
            : null,
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white24,
          size: 16,
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF132B3D),
        title: Text(
          '¿Cerrar Sesión?',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        content: Text(
          'Se borrará tu nombre de usuario de este dispositivo. Tus datos financieros permanecerán guardados.',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ),
          TextButton(
            onPressed: () async {
              // 1. Verificar si hay bloqueo activado
              final prefs = await SharedPreferences.getInstance();
              final bool isLocked = prefs.getBool('app_lock_enabled') ?? false;

              if (isLocked && context.mounted) {
                final bool? authenticated = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const LockScreen(mode: LockMode.verify),
                  ),
                );
                if (authenticated != true) {
                  return; // Si cancela o falla, no cerrar sesión
                }
              }

              final storage = SimpleStorageService();
              await storage.clearUser();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const WelcomeScreen(),
                  ),
                  (route) => false,
                );
              }
            },
            child: const Text('Salir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
