import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({Key? key}) : super(key: key);

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
          'Términos y Condiciones',
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
              '1. Aceptación de los Términos',
              'Al descargar y utilizar RINDE, usted acepta estar sujeto a estos Términos y Condiciones. Si no está de acuerdo con alguna parte de los términos, no podrá acceder al servicio.',
            ),
            _buildSection(
              '2. Descripción del Servicio',
              'RINDE es una herramienta de gestión financiera personal que permite a los usuarios registrar y visualizar sus ingresos y gastos. La aplicación no ofrece asesoramiento financiero profesional, legal o fiscal.',
            ),
            _buildSection(
              '3. Responsabilidades del Usuario',
              'Usted es responsable de mantener la confidencialidad de su PIN y acceso biométrico. RINDE no se hace responsable por pérdidas derivadas del acceso no autorizado a su dispositivo o de la pérdida de datos por fallos del mismo.',
            ),
            _buildSection(
              '4. Propiedad Intelectual',
              'El servicio y su contenido original, características y funcionalidad son y seguirán siendo propiedad exclusiva de RINDE y sus licenciantes.',
            ),
            _buildSection(
              '5. Limitación de Responsabilidad',
              'En ningún caso RINDE será responsable por daños indirectos, incidentales, especiales, consecuentes o punitivos, incluyendo sin limitación, pérdida de beneficios o datos, que surjan de su uso del servicio.',
            ),
            _buildSection(
              '6. Modificaciones',
              'Nos reservamos el derecho de modificar o reemplazar estos términos en cualquier momento. Es su responsabilidad revisar estos términos periódicamente.',
            ),
            _buildSection(
              '7. Ley Aplicable',
              'Estos términos se regirán e interpretarán de acuerdo con las leyes vigentes en la República Bolivariana de Venezuela, sin tener en cuenta sus disposiciones sobre conflictos de leyes.',
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
