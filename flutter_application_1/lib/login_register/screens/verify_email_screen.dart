import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';
import 'data_consent_screen.dart';
import 'gender_selection_screen.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final TextEditingController _codeController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Timer? _timer;
  int _remainingTime = 60;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _remainingTime = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingTime > 0) {
        setState(() => _remainingTime--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _resendCode() async {
    setState(() => _isLoading = true);
    final result = await _authService.resendEmailVerification(widget.email);
    setState(() => _isLoading = false);

    if (result['success']) {
      // Use showSnackBar instead of _showError so it can be green if we want, or map _showError
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(result['message'] ?? 'ส่งรหัสใหม่สำเร็จ'),
              backgroundColor: Colors.green),
        );
      }
      _startTimer();
    } else {
      _showError(result['message'] ?? 'ส่งรหัสใหม่ไม่สำเร็จ');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _handleVerify() async {
    String code = _codeController.text.trim();
    if (code.isEmpty) {
      _showError('กรุณากรอกรหัสยืนยัน 6 หลัก');
      return;
    }

    setState(() => _isLoading = true);
    final result = await _authService.verifyEmail(widget.email, code);
    setState(() => _isLoading = false);

    if (result['success']) {
      if (mounted) {
        routeAfterAuth(
          context,
          ref,
          destination: (_) => const GenderSelectionScreen(),
        );
      }
    } else {
      _showError(result['message'] ?? 'ยืนยันรหัสไม่สำเร็จ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EFCF),
      appBar: AppBar(
        title: const Text('ยืนยันอีเมล'),
        backgroundColor: const Color(0xFF4C6414),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'กรุณากรอกรหัส OTP 6 หลัก',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'รหัสยืนยันถูกส่งไปยัง ${widget.email} แล้ว\nโปรดตรวจสอบกล่องจดหมาย (และโฟลเดอร์สแปม)',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: Colors.grey[800],
                    height: 1.4),
              ),
              const SizedBox(height: 40),
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16)),
                child: TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 10),
                  decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      hintText: '000000'),
                ),
              ),
              const SizedBox(height: 40),
              Center(
                child: GestureDetector(
                  onTap: _isLoading ? null : _handleVerify,
                  child: Container(
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF628141),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('ยืนยัน',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed:
                      _remainingTime > 0 || _isLoading ? null : _resendCode,
                  child: Text(
                    _remainingTime > 0
                        ? 'ส่งรหัสใหม่ใน $_remainingTime วิ'
                        : 'ส่งรหัสยืนยันอีกครั้ง',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: _remainingTime > 0
                          ? Colors.grey
                          : const Color(0xFF628141),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
