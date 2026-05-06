import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/user_data_provider.dart';
import '../../services/auth_service.dart';
import 'data_consent_screen.dart';
import 'forgot_password_screen.dart';
import 'gender_selection_screen.dart';
import 'register_screen.dart';
import 'verify_email_screen.dart';
import '../../widget/bottom_bar.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ───────────────────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  // ── State ─────────────────────────────────────────────────────
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePass = true;
  StreamSubscription<AuthState>? _authSub;
  bool _socialSyncing = false;

  // ── Animation ─────────────────────────────────────────────────
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // ── Colors ────────────────────────────────────────────────────
  static const _green = Color(0xFF4C6414);
  static const _bg = Color(0xFFF5F7F0);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();

    // OAuth (Google/Facebook) returns asynchronously via redirect — listen for
    // the session, then sync with backend. Without this, signInWithOAuth fires
    // and we navigate away before currentUser is populated.
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.event != AuthChangeEvent.signedIn) return;
      final user = event.session?.user;
      if (user == null || _socialSyncing) return;
      final providers = user.appMetadata['providers'];
      final isOAuth = providers is List &&
          providers.any((p) => p != 'email' && p != 'phone');
      if (!isOAuth) return;
      final provider = _oauthProviderFrom(user.appMetadata);
      _socialSyncing = true;
      _syncSocialBackend(
        email: user.email ?? '',
        name: (user.userMetadata?['full_name'] as String?) ??
            (user.userMetadata?['name'] as String?) ??
            user.email ??
            'User',
        uid: user.id,
        provider: provider,
      ).whenComplete(() => _socialSyncing = false);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Navigation helper ─────────────────────────────────────────
  void _navigateAfterAuthData(Map<String, dynamic> data) {
    if (!mounted) return;
    final shouldContinueOnboarding = data['onboarding_required'] == true;
    routeAfterAuth(
      context,
      ref,
      destination: (_) => shouldContinueOnboarding
          ? const GenderSelectionScreen()
          : const MainScreen(),
    );
  }

  void _showError(String msg) {
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(fontSize: 14))),
        ]),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        width: isWide ? 520 : null,
        margin: isWide ? null : const EdgeInsets.all(16),
      ),
    );
  }

  String _oauthProviderFrom(Map<String, dynamic> appMetadata) {
    final providers = appMetadata['providers'];
    if (providers is List) {
      for (final provider in providers) {
        final value = provider.toString();
        if (value != 'email' && value != 'phone') {
          return value;
        }
      }
    }
    final provider = appMetadata['provider']?.toString();
    return provider == null || provider.isEmpty ? 'google' : provider;
  }

  // ── Email / Password Login ────────────────────────────────────
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result =
        await _authService.login(_emailCtrl.text.trim(), _passCtrl.text);
    setState(() => _isLoading = false);

    if (result['success']) {
      final data = result['data'];
      ref.read(userDataProvider.notifier).setUserId(data['user_id'] as int);
      ref
          .read(userDataProvider.notifier)
          .setLoginInfo(_emailCtrl.text.trim(), _passCtrl.text);
      if (data['onboarding_required'] == true) {
        ref.read(userDataProvider.notifier).setPersonalInfo(
              name: (data['username'] as String?) ?? 'User',
              birthDate: DateTime.now(),
              height: 0,
              weight: 0,
            );
      }
      final refreshToken = data['refresh_token'] as String?;
      if (refreshToken != null) {
        try {
          await Supabase.instance.client.auth.setSession(refreshToken);
        } catch (_) {}
      }
      await Future.delayed(const Duration(milliseconds: 100));
      _navigateAfterAuthData(data);
    } else {
      if (result['needsEmailVerification'] == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(email: _emailCtrl.text.trim()),
          ),
        );
        return;
      }
      _showError(result['message'] ?? 'อีเมลหรือรหัสผ่านไม่ถูกต้อง');
    }
  }

  // ── Social Login helper (backend sync) ───────────────────────
  Future<void> _syncSocialBackend({
    required String email,
    required String name,
    required String uid,
    required String provider,
  }) async {
    final result = await _authService.socialLogin(
        email: email, name: name, uid: uid, provider: provider);
    if (result['success']) {
      final data = result['data'];
      ref.read(userDataProvider.notifier).setUserId(data['user_id'] as int);
      ref.read(userDataProvider.notifier).setLoginInfo(email, '');
      if (data['onboarding_required'] == true) {
        ref.read(userDataProvider.notifier).setPersonalInfo(
              name: (data['username'] as String?) ?? name,
              birthDate: DateTime.now(),
              height: 0,
              weight: 0,
            );
      }
      await Future.delayed(const Duration(milliseconds: 100));
      _navigateAfterAuthData(data);
    } else {
      _showError(result['message'] ?? 'ล็อกอินไม่สำเร็จ กรุณาลองใหม่');
    }
  }

  // ── Google Sign-In (via Supabase OAuth) ────────────────────────
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isGoogleLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _authService.oauthRedirectTo,
      );
      // The actual session arrives asynchronously on the OAuth redirect.
      // _authSub (initState) handles _syncSocialBackend when the session lands.
    } catch (e) {
      _showError('Google Sign-In ล้มเหลว: $e');
    }
    if (mounted) setState(() => _isGoogleLoading = false);
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            return FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 32 : 28,
                  ),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Form(
                          key: _formKey,
                          child: Column(children: [
                            const SizedBox(height: 40),

                            // ── App logo ──────────────────────────────────
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color: _green.withValues(alpha: 0.2),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6))
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Image.asset(
                                    'assets/images/icon/icon.png',
                                    fit: BoxFit.contain),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // ── Title ─────────────────────────────────────
                            Text(
                              l10n.tr('login.title'),
                              style: const TextStyle(
                                  fontFamily: 'Karla',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A2E0F)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'ลงชื่อเข้าใช้งาน Calories Guard',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Colors.grey.shade500),
                            ),

                            const SizedBox(height: 36),

                            // ── Email field ───────────────────────────────
                            _buildInputField(
                              controller: _emailCtrl,
                              hint: l10n.tr('login.email'),
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'กรุณากรอกอีเมล';
                                }
                                if (!v.contains('@')) {
                                  return 'รูปแบบอีเมลไม่ถูกต้อง';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 14),

                            // ── Password field ────────────────────────────
                            _buildInputField(
                              controller: _passCtrl,
                              hint: l10n.tr('login.password'),
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscurePass,
                              suffix: IconButton(
                                icon: Icon(
                                    _obscurePass
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: Colors.grey.shade400),
                                onPressed: () => setState(
                                    () => _obscurePass = !_obscurePass),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'กรุณากรอกรหัสผ่าน';
                                }
                                if (v.length < 6) {
                                  return 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร';
                                }
                                return null;
                              },
                            ),

                            // ── Forgot password ───────────────────────────
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const ForgotPasswordScreen())),
                                style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 6)),
                                child: Text(
                                  l10n.tr('login.forgot'),
                                  style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      color: _green,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ),

                            const SizedBox(height: 6),

                            // ── Login button ──────────────────────────────
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: (_isLoading || _isGoogleLoading)
                                    ? null
                                    : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _green,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey.shade300,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5))
                                    : Text(
                                        l10n.tr('login.cta'),
                                        style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // ── Divider ───────────────────────────────────
                            Row(children: [
                              Expanded(
                                  child: Divider(
                                      color: Colors.grey.shade300, height: 1)),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                child: Text(
                                  'หรือเข้าสู่ระบบด้วย',
                                  style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: Colors.grey.shade500),
                                ),
                              ),
                              Expanded(
                                  child: Divider(
                                      color: Colors.grey.shade300, height: 1)),
                            ]),

                            const SizedBox(height: 20),

                            // ── Google Sign-In Button (only) ──────────────
                            _buildSocialButton(
                              label: 'Google',
                              icon: const FaIcon(FontAwesomeIcons.google,
                                  size: 18, color: Color(0xFFEA4335)),
                              borderColor: const Color(0xFFEA4335)
                                  .withValues(alpha: 0.3),
                              isLoading: _isGoogleLoading,
                              onTap: (_isLoading || _isGoogleLoading)
                                  ? null
                                  : _handleGoogleSignIn,
                            ),

                            const SizedBox(height: 28),

                            // ── Divider before register ───────────────────
                            Divider(color: Colors.grey.shade200, height: 1),
                            const SizedBox(height: 20),

                            // ── Register button ───────────────────────────
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: OutlinedButton(
                                onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const RegisterScreen())),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _green,
                                  side: const BorderSide(
                                      color: _green, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_add_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'สร้างบัญชีใหม่',
                                      style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.2),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 40),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Input Field Widget ────────────────────────────────────────
  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
          fontFamily: 'Inter', fontSize: 15, color: Color(0xFF1A2E0F)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            fontFamily: 'Inter', fontSize: 15, color: Colors.grey.shade400),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, size: 20, color: Colors.grey.shade400),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _green, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }

  // ── Social Button Widget ──────────────────────────────────────
  Widget _buildSocialButton({
    required String label,
    required Widget icon,
    required Color borderColor,
    required bool isLoading,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 50,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.grey.shade400))
              : icon,
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A2E0F))),
        ]),
      ),
    );
  }
}
