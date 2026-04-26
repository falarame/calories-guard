import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/user_data_provider.dart';
import 'verify_email_screen.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // --- Live email availability check ---
  Timer? _emailDebounce;
  String? _emailStatusText; // e.g. 'อีเมลนี้ถูกใช้งานแล้ว'
  Color _emailStatusColor = Colors.grey;
  bool _isEmailChecking = false;
  bool _isEmailTaken = false;
  String _lastCheckedEmail = '';

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onEmailChanged);
  }

  @override
  void dispose() {
    _emailDebounce?.cancel();
    _emailController.removeListener(_onEmailChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onEmailChanged() {
    _emailDebounce?.cancel();
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _emailStatusText = null;
        _isEmailTaken = false;
      });
      return;
    }
    final emailRegex =
        RegExp(r'^[\w\.\-\+]+@[\w\-]+(\.[\w\-]+)*\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      setState(() {
        _emailStatusText = null;
        _isEmailTaken = false;
      });
      return;
    }
    _emailDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted || email == _lastCheckedEmail) return;
      setState(() {
        _isEmailChecking = true;
        _emailStatusText = 'กำลังตรวจสอบ...';
        _emailStatusColor = Colors.grey;
      });
      final result = await _authService.checkEmailAvailable(email);
      if (!mounted) return;
      _lastCheckedEmail = email;
      setState(() {
        _isEmailChecking = false;
        if (result['networkError'] == true) {
          _emailStatusText = null;
          _isEmailTaken = false;
        } else if (result['available'] == true) {
          _emailStatusText = '✓ อีเมลนี้สามารถใช้งานได้';
          _emailStatusColor = const Color(0xFF2E7D32);
          _isEmailTaken = false;
        } else if (result['reason'] == 'taken') {
          _emailStatusText = 'อีเมลนี้ถูกใช้งานแล้ว';
          _emailStatusColor = Colors.redAccent;
          _isEmailTaken = true;
        } else {
          _emailStatusText = null;
          _isEmailTaken = false;
        }
      });
    });
  }

  void _showError(String message) {
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        width: isWide ? 520 : null,
        margin: isWide ? null : const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleRegister() async {
    String firstName = _firstNameController.text.trim();
    String lastName = _lastNameController.text.trim();
    String fullName = '$firstName $lastName';
    String email = _emailController.text.trim();
    String password = _passwordController.text;
    String confirmPassword = _confirmPasswordController.text;

    // Validation
    if (firstName.isEmpty ||
        lastName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showError('กรุณากรอกข้อมูลให้ครบถ้วน');
      return;
    }
    if (firstName.length < 2) {
      _showError('ชื่อต้องมีความยาวอย่างน้อย 2 ตัวอักษร');
      return;
    }
    if (lastName.length < 2) {
      _showError('นามสกุลต้องมีความยาวอย่างน้อย 2 ตัวอักษร');
      return;
    }
    if (!RegExp(r'^[\w\.\-\+]+@[\w\-]+(\.[\w\-]+)*\.[a-zA-Z]{2,}$')
        .hasMatch(email)) {
      _showError('กรุณากรอกอีเมลให้ถูกต้อง เช่น user@gmail.com');
      return;
    }
    if (_isEmailTaken) {
      _showError('อีเมลนี้ถูกใช้งานแล้ว กรุณาใช้อีเมลอื่น');
      return;
    }
    if (_isEmailChecking) {
      _showError('กำลังตรวจสอบอีเมล กรุณารอสักครู่');
      return;
    }
    if (password.length < 8) {
      _showError('รหัสผ่านต้องมีความยาวอย่างน้อย 8 ตัวอักษร');
      return;
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      _showError('รหัสผ่านต้องมีตัวพิมพ์ใหญ่อย่างน้อย 1 ตัว (A-Z)');
      return;
    }
    if (!password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) {
      _showError('รหัสผ่านต้องมีอักขระพิเศษอย่างน้อย 1 ตัว');
      return;
    }
    if (password != confirmPassword) {
      _showError('รหัสผ่านยืนยันไม่ตรงกัน');
      return;
    }

    // Call API
    setState(() => _isLoading = true);

    final result = await _authService.register(fullName, email, password);

    setState(() => _isLoading = false);

    if (result['success']) {
      final data = result['data'];

      // ✅ หัวใจสำคัญ: ดึง ID จาก Backend แล้วยัดใส่ Provider ทันที
      // เช็ค Structure ให้ชัวร์: Backend ส่งกลับมาเป็น {"message": "...", "user": {"user_id": 1, ...}}
      // AuthService ของเรามักจะห่อเป็น {'success': true, 'data': response_body}
      final int newId = data['user']['user_id'];

      ref.read(userDataProvider.notifier).setUserId(newId);
      ref.read(userDataProvider.notifier).setLoginInfo(email, password);
      ref.read(userDataProvider.notifier).setPersonalInfo(
          name: fullName,
          birthDate: DateTime.now(), // ค่าชั่วคราว เดี๋ยวไปแก้หน้า PersonalInfo
          height: 0,
          weight: 0);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => VerifyEmailScreen(email: email)),
        );
      }
    } else {
      if (mounted) {
        _showError(result['message'] ?? 'สมัครสมาชิกไม่สำเร็จ');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFE8EFCF),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: isWide ? 32 : 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: isWide ? 24 : 16),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios,
                              color: Color(0xFF1D1B20)),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      SizedBox(height: isWide ? 18 : 10),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'สร้างบัญชีผู้ใช้ใหม่',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 30,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black),
                              ),
                              SizedBox(height: isWide ? 48 : 36),
                              _buildLabel('ชื่อ *'),
                              _buildTextField(_firstNameController),
                              const SizedBox(height: 20),
                              _buildLabel('นามสกุล *'),
                              _buildTextField(_lastNameController),
                              const SizedBox(height: 20),
                              _buildLabel('E-mail *'),
                              _buildTextField(
                                _emailController,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              if (_emailStatusText != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 8, top: 4, right: 8),
                                  child: Row(
                                    children: [
                                      if (_isEmailChecking)
                                        const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFF628141)),
                                        )
                                      else
                                        Icon(
                                          _isEmailTaken
                                              ? Icons.error_outline
                                              : Icons.check_circle_outline,
                                          size: 16,
                                          color: _emailStatusColor,
                                        ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _emailStatusText!,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 13,
                                            color: _emailStatusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 20),
                              _buildLabel('Password *'),
                              _buildTextField(_passwordController,
                                  isPassword: true),
                              const Padding(
                                padding:
                                    EdgeInsets.only(left: 8, top: 6, right: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'เงื่อนไขรหัสผ่าน:',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '• ความยาวอย่างน้อย 8 ตัวอักษร',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: Colors.redAccent,
                                        height: 1.4,
                                      ),
                                    ),
                                    Text(
                                      '• มีตัวพิมพ์ใหญ่ (A-Z) อย่างน้อย 1 ตัว',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: Colors.redAccent,
                                        height: 1.4,
                                      ),
                                    ),
                                    Text(
                                      '• มีอักขระพิเศษ (เช่น !, @, #) อย่างน้อย 1 ตัว',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: Colors.redAccent,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildLabel('Confirm password *'),
                              _buildTextField(_confirmPasswordController,
                                  isPassword: true),
                              SizedBox(height: isWide ? 48 : 36),
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed:
                                      _isLoading ? null : _handleRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF628141),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        Colors.grey.shade300,
                                    elevation: 2,
                                    shadowColor:
                                        Colors.black.withValues(alpha: 0.24),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5),
                                        )
                                      : const Text('Done',
                                          style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white)),
                                ),
                              ),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, {VoidCallback? onInfoTap}) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 6),
      child: Row(
        children: [
          Text(text,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.black.withValues(alpha: 0.5))),
          if (onInfoTap != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onInfoTap,
              child: const Icon(Icons.help_outline,
                  size: 20, color: Color(0xFF628141)),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, {
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Center(
        child: TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
          decoration:
              const InputDecoration(border: InputBorder.none, isDense: true),
          style: const TextStyle(
              fontFamily: 'Inter', fontSize: 16, color: Colors.black),
        ),
      ),
    );
  }
}
