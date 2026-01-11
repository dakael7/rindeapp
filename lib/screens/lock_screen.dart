import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final Color _backgroundColor = const Color(0xFF071925);
  final Color _cardColor = const Color(0xFF132B3D);
  final Color _primaryGreen = const Color(0xFF4ADE80);
  final Color _expenseRed = const Color(0xFFFF5252);
  final Color _textGrey = const Color(0xFFB0BEC5);

  String _pin = '';
  String _confirmedPin = '';
  bool _isSetup = false;
  bool _isConfirming = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  Future<void> _checkPinStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString('app_pin');

    if (widget.mode == LockMode.disable) {
      await prefs.remove('app_pin');
      if (mounted) _onSuccess();
      return;
    }

    setState(() {
      if (widget.mode == LockMode.create) {
        _isSetup = true;
      } else {
        // Verify mode
        if (storedPin == null) {
          _isSetup = true; // Force setup if no PIN
        } else {
          _isSetup = false;
        }
      }
      _isLoading = false;
    });
  }

  void _onKeyPressed(String value) {
    if (_pin.length < 4) {
      setState(() {
        _pin += value;
      });
      if (_pin.length == 4) {
        _handlePinComplete();
      }
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _handlePinComplete() async {
    final prefs = await SharedPreferences.getInstance();

    if (_isSetup) {
      if (_isConfirming) {
        if (_pin == _confirmedPin) {
          await prefs.setString('app_pin', _pin);
          _onSuccess();
        } else {
          _showError('Los PIN no coinciden');
          setState(() {
            _pin = '';
            _confirmedPin = '';
            _isConfirming = false;
          });
        }
      } else {
        setState(() {
          _confirmedPin = _pin;
          _pin = '';
          _isConfirming = true;
        });
      }
    } else {
      final storedPin = prefs.getString('app_pin');
      if (_pin == storedPin) {
        _onSuccess();
      } else {
        _showError('PIN Incorrecto');
        setState(() {
          _pin = '';
        });
      }
    }
  }

  void _onSuccess() {
    if (widget.nextScreen != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => widget.nextScreen!),
      );
    } else {
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: _expenseRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: Center(child: CircularProgressIndicator(color: _primaryGreen)),
      );
    }

    String title = 'Ingresa tu PIN';
    if (_isSetup) {
      title = _isConfirming ? 'Confirma tu nuevo PIN' : 'Crea un PIN de acceso';
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, color: Colors.white, size: 50),
            const SizedBox(height: 24),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final filled = index < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? _primaryGreen : _cardColor,
                    border: Border.all(
                      color: filled ? _primaryGreen : Colors.white24,
                    ),
                  ),
                );
              }),
            ),
            const Spacer(),
            _buildKeypad(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _buildRow(['1', '2', '3']),
          const SizedBox(height: 24),
          _buildRow(['4', '5', '6']),
          const SizedBox(height: 24),
          _buildRow(['7', '8', '9']),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 70),
              _buildKey('0'),
              _buildBackspace(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((k) => _buildKey(k)).toList(),
    );
  }

  Widget _buildKey(String val) {
    return GestureDetector(
      onTap: () => _onKeyPressed(val),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: _cardColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          val,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildBackspace() {
    return GestureDetector(
      onTap: _onDelete,
      child: Container(
        width: 70,
        height: 70,
        alignment: Alignment.center,
        child: Icon(Icons.backspace_outlined, color: _textGrey),
      ),
    );
  }
}
