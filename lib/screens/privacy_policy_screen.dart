import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071925),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Políticas de Privacidad',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              '1. Introducción',
              'Bienvenido a RINDE. Valoramos su privacidad y estamos comprometidos a proteger su información personal. Esta Política de Privacidad explica cómo recopilamos, usamos y protegemos sus datos.',
            ),
            _buildSection(
              '2. Recopilación de Información',
              'RINDE es una aplicación diseñada para funcionar principalmente de manera local en su dispositivo. Recopilamos la siguiente información:\n\n• Datos de Registro: Nombre de usuario.\n• Datos Financieros: Ingresos, gastos, deudas y metas de ahorro ingresados manualmente.\n• Datos de Uso: Preferencias de configuración y moneda.',
            ),
            _buildSection(
              '3. Uso de la Información',
              'La información recopilada se utiliza exclusivamente para:\n\n• Proporcionar y mantener el servicio de gestión financiera.\n• Calcular balances y proyecciones.\n• Personalizar su experiencia de usuario.',
            ),
            _buildSection(
              '4. Almacenamiento de Datos',
              'Todos sus datos financieros y personales se almacenan localmente en su dispositivo utilizando tecnologías de almacenamiento seguro (SQLite y Shared Preferences). RINDE no transmite sus datos financieros a servidores externos ni a terceros.',
            ),
            _buildSection(
              '5. Seguridad',
              'Implementamos medidas de seguridad como el bloqueo por PIN y autenticación biométrica para proteger el acceso a la aplicación. Sin embargo, recuerde que ningún método de almacenamiento electrónico es 100% seguro y depende en gran medida de la seguridad de su propio dispositivo.',
            ),
            _buildSection(
              '6. Cambios a esta Política',
              'Podemos actualizar nuestra Política de Privacidad periódicamente. Le notificaremos cualquier cambio publicando la nueva política en esta página.',
            ),
            _buildSection(
              '7. Contacto',
              'Si tiene alguna pregunta sobre esta Política de Privacidad, por favor contáctenos a través de los canales de soporte de la aplicación.',
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              color: const Color(0xFF4ADE80),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
