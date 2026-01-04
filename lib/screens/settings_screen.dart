import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lock_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Color _backgroundColor = const Color(0xFF071925);
  final Color _cardColor = const Color(0xFF132B3D);
  final Color _primaryGreen = const Color(0xFF4ADE80);
  final Color _textGrey = const Color(0xFFB0BEC5);

  bool _obscureBalances = false;
  String _defaultCurrency = 'BCV';
  bool _notificationsEnabled = true;
  bool _appLockEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _obscureBalances = prefs.getBool('obscure_balances') ?? false;
      _defaultCurrency = prefs.getString('default_currency') ?? 'BCV';
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _appLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
    });
  }

  Future<void> _updateObscureBalances(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('obscure_balances', value);
    setState(() {
      _obscureBalances = value;
    });
  }

  Future<void> _updateDefaultCurrency(String? value) async {
    if (value == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_currency', value);
    setState(() {
      _defaultCurrency = value;
    });
  }

  Future<void> _updateNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() {
      _notificationsEnabled = value;
    });
  }

  Future<void> _toggleAppLock(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    if (value) {
      // Activar: Ir a crear PIN
      final success = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LockScreen(mode: LockMode.create),
        ),
      );
      if (success == true) {
        await prefs.setBool('app_lock_enabled', true);
        setState(() => _appLockEnabled = true);
      }
    } else {
      // Desactivar: Verificar PIN actual antes de quitar
      final success = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LockScreen(mode: LockMode.verify),
        ),
      );
      if (success == true) {
        await prefs.setBool('app_lock_enabled', false);
        await prefs.remove(
          'user_pin',
        ); // Opcional: borrar PIN o dejarlo guardado
        setState(() => _appLockEnabled = false);
      }
    }
  }

  Future<void> _clearData(String key, String label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(
          '¿Estás seguro?',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        content: Text(
          'Esta acción eliminará permanentemente $label. No se puede deshacer.',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: _textGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 1. Verificar autenticación antes de borrar
      if (_appLockEnabled) {
        final bool? authenticated = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LockScreen(mode: LockMode.verify),
          ),
        );
        if (authenticated != true) return; // Cancelar borrado
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label eliminados correctamente'),
            backgroundColor: _primaryGreen,
          ),
        );
      }
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
          'Configuración',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionHeader('Apariencia'),
          _buildSwitchTile(
            title: 'Ocultar Saldos',
            subtitle: 'Muestra asteriscos en lugar de montos en el inicio',
            value: _obscureBalances,
            onChanged: _updateObscureBalances,
            icon: Icons.visibility_off_outlined,
          ),
          _buildSwitchTile(
            title: 'Bloqueo de Aplicación',
            subtitle: 'Solicitar PIN o Biometría al iniciar',
            value: _appLockEnabled,
            onChanged: _toggleAppLock,
            icon: Icons.lock_outline,
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('Funcionamiento'),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.monetization_on_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Moneda Principal',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Visualización por defecto en inicio',
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _defaultCurrency,
                    dropdownColor: _cardColor,
                    icon: Icon(Icons.arrow_drop_down, color: _primaryGreen),
                    style: GoogleFonts.poppins(
                      color: _primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                    items: ['BCV', 'USDT', 'VES'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: _updateDefaultCurrency,
                  ),
                ),
              ],
            ),
          ),
          _buildSwitchTile(
            title: 'Notificaciones',
            subtitle: 'Recordatorios y alertas de la app',
            value: _notificationsEnabled,
            onChanged: _updateNotifications,
            icon: Icons.notifications_outlined,
          ),
          const SizedBox(height: 24),

          _buildSectionHeader('Zona de Peligro'),
          _buildActionTile(
            title: 'Borrar Transacciones',
            subtitle: 'Elimina todo el historial de movimientos',
            icon: Icons.delete_forever_outlined,
            color: Colors.red,
            onTap: () => _clearData('transactions_data', 'Las transacciones'),
          ),
          _buildActionTile(
            title: 'Borrar Historial de Tasas',
            subtitle: 'Elimina el registro histórico del dólar',
            icon: Icons.history_toggle_off,
            color: Colors.orange,
            onTap: () =>
                _clearData('rates_history_data', 'El historial de tasas'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: _primaryGreen,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: _primaryGreen,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        secondary: Container(
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
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
        ),
      ),
    );
  }
}
