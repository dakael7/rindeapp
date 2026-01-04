import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class RateHistoryScreen extends StatefulWidget {
  const RateHistoryScreen({Key? key}) : super(key: key);

  @override
  State<RateHistoryScreen> createState() => _RateHistoryScreenState();
}

class _RateHistoryScreenState extends State<RateHistoryScreen> {
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString('rates_history_data');
    if (data != null) {
      final List<dynamic> decoded = jsonDecode(data);
      setState(() {
        _history = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        // Ordenar: más reciente primero
        _history.sort((a, b) => b['date'].compareTo(a['date']));
      });
    }
  }

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
        title: Text(
          'Histórico de Tasas',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _history.isEmpty
          ? Center(
              child: Text(
                'No hay historial disponible',
                style: GoogleFonts.poppins(color: textGrey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final item = _history[index];
                final date = DateTime.parse(item['date']);
                final rates = item['rates'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy - HH:mm').format(date),
                        style: GoogleFonts.poppins(
                          color: textGrey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildRateItem('BCV', rates['BCV'], primaryGreen),
                          _buildRateItem('USDT', rates['USDT'], Colors.white),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildRateItem(String label, dynamic value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: const Color(0xFFB0BEC5),
            fontSize: 10,
          ),
        ),
        Text(
          'Bs ${value?.toStringAsFixed(2) ?? '0.00'}',
          style: GoogleFonts.poppins(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
