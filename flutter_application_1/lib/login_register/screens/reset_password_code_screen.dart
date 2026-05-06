import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'login_screen.dart';

class ResetPasswordCodeScreen extends StatefulWidget {
  const ResetPasswordCodeScreen({super.key, required this.email});

  final String email;

  @override
  State<ResetPasswordCodeScreen> createState() =>
      _ResetPasswordCodeScreenState();
}

class _ResetPasswordCodeScreenState extends State<ResetPasswordCodeScreen> {
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _authService = AuthService();
  DateTime? _birthDate;
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF4C6414),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (selected != null) {
      setState(() => _birthDate = selected);
    }
  }

  String? _validatePassword(String password, String confirm) {
    if (password.length < 8) {
      return 'รหัสผ่านต้องมีความยาวอย่างน้อย 8 ตัวอักษร';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'รหัสผ่านต้องมีตัวพิมพ์ใหญ่อย่างน้อย 1 ตัว (A-Z)';
    }
    if (!password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) {
      return 'รหัสผ่านต้องมีอักขระพิเศษอย่างน้อย 1 ตัว';
    }
    if (password != confirm) {
      return 'รหัสผ่านยืนยันไม่ตรงกัน';
    }
    return null;
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (code.length != 6 || int.tryParse(code) == null) {
      _showMessage('กรุณากรอกรหัส 6 หลักจากอีเมล', isError: true);
      return;
    }
    if (_birthDate == null) {
      _showMessage('กรุณาเลือกวันเกิดเพื่อยืนยันตัวตน', isError: true);
      return;
    }
    final passwordError = _validatePassword(password, confirm);
    if (passwordError != null) {
      _showMessage(passwordError, isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final result = await _authService.confirmPasswordReset(
      email: widget.email,
      code: code,
      birthDate: _birthDate!,
      newPassword: password,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      _showMessage(result['message'] ?? 'รีเซ็ตรหัสผ่านสำเร็จ');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      return;
    }
    _showMessage(result['message'] ?? 'รีเซ็ตรหัสผ่านไม่สำเร็จ', isError: true);
  }

  Future<void> _resendCode() async {
    setState(() => _isLoading = true);
    final result = await _authService.requestPasswordReset(widget.email);
    if (!mounted) return;
    setState(() => _isLoading = false);
    _showMessage(
      result['message'] ?? 'ส่งรหัสใหม่แล้ว',
      isError: result['success'] != true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EFCF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4C6414),
        foregroundColor: Colors.white,
        title: const Text('ตั้งรหัสผ่านใหม่'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ยืนยันรหัสจากอีเมล',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2E0F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'กรอกรหัส 6 หลักที่ส่งไปยัง ${widget.email}\nพร้อมวันเกิดและรหัสผ่านใหม่',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'รหัส 6 หลัก',
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _pickBirthDate,
                    icon: const Icon(Icons.cake_outlined),
                    label: Text(
                      _birthDate == null
                          ? 'เลือกวันเกิด'
                          : 'วันเกิด: ${_formatDate(_birthDate!)}',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4C6414),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _passwordField(_passwordCtrl, 'รหัสผ่านใหม่'),
                  const SizedBox(height: 16),
                  _passwordField(_confirmCtrl, 'ยืนยันรหัสผ่านใหม่'),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4C6414),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'บันทึกรหัสผ่านใหม่',
                              style:
                                  TextStyle(fontSize: 16, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isLoading ? null : _resendCode,
                    child: const Text(
                      'ส่งรหัสใหม่',
                      style: TextStyle(color: Color(0xFF4C6414)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
