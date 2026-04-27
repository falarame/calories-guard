import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service.dart';

/// Forgot-password flow is delegated to Supabase Auth.
///
/// Supabase sends a password-reset *link* (not an OTP) to the user's inbox.
/// Clicking the link returns to the app/web origin; AuthBootstrap listens for
/// the passwordRecovery event and opens ResetPasswordScreen.
///
/// The legacy OTP-based flow (backend `/password-reset/*`) is kept on the
/// server for backwards compatibility but is no longer called from the app.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: isError ? Colors.redAccent : Colors.green),
    );
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('กรุณากรอกอีเมล', isError: true);
      return;
    }
    final emailRegex =
        RegExp(r'^[\w\.\-\+]+@[\w\-]+(\.[\w\-]+)*\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      _showMessage('กรุณากรอกอีเมลให้ถูกต้อง', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    final result = await _authService.requestPasswordReset(email);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      setState(() => _sent = true);
      _showMessage(result['message'] ?? 'ส่งลิงก์รีเซ็ตรหัสผ่านไปที่อีเมลแล้ว');
    } else {
      _showMessage(result['message'] ?? 'ส่งลิงก์ไม่สำเร็จ', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EFCF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4C6414),
        foregroundColor: Colors.white,
        title: const Text('ลืมรหัสผ่าน'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'รีเซ็ตรหัสผ่านผ่านอีเมล',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D1B20),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'กรอกอีเมลที่ใช้สมัครบัญชี ระบบจะส่งลิงก์รีเซ็ตรหัสผ่าน\nไปที่อีเมลของคุณ คลิกลิงก์เพื่อตั้งรหัสผ่านใหม่',
                style:
                    TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_sent,
                decoration: InputDecoration(
                  labelText: 'อีเมล',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_sent)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF4C6414)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF4C6414)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ส่งลิงก์รีเซ็ตรหัสผ่านแล้ว\n'
                          'กรุณาตรวจสอบกล่องจดหมายและโฟลเดอร์สแปม',
                          style: TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Center(
                child: SizedBox(
                  width: 280,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4C6414),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isLoading ? null : _sendResetLink,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _sent
                                ? 'ส่งลิงก์อีกครั้ง'
                                : 'ส่งลิงก์รีเซ็ตรหัสผ่าน',
                            style: const TextStyle(
                                fontSize: 16, color: Colors.white),
                          ),
                  ),
                ),
              ),
              if (_sent) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'กลับไปหน้าเข้าสู่ระบบ',
                      style: TextStyle(color: Color(0xFF4C6414)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
