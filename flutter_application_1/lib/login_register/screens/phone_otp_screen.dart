import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/settings_provider.dart';
import '../../providers/user_data_provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widget/bottom_bar.dart';
import 'data_consent_screen.dart';
import 'gender_selection_screen.dart';

const _green = Color(0xFF628141);
const _bg = Color(0xFFF5F7F0);

/// Handles phone-number entry → OTP verification using Supabase phone auth.
///
/// Flow:
///   PhoneEntryStep — user types phone number, taps "Send OTP"
///   OtpVerifyStep  — user types 6-digit code, taps "Verify"
///   → backend sync → consent / onboarding as needed
///
/// Setup requirements:
///   1. Supabase Dashboard → Auth → Providers → Phone: enable, set Twilio creds
///   2. (Optional) SendGrid for email OTP is separate; this uses SMS via Twilio
class PhoneOtpScreen extends ConsumerStatefulWidget {
  const PhoneOtpScreen({super.key});

  @override
  ConsumerState<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends ConsumerState<PhoneOtpScreen> {
  final _authService = AuthService();

  // ── step state ──
  bool _otpSent = false;
  String _phone = '';

  // ── controllers ──
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  // ── loading ──
  bool _sending = false;
  bool _verifying = false;

  // ── resend cooldown (60 s) ──
  int _resendCountdown = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // ── send OTP ─────────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final raw = _phoneCtrl.text.trim();
    // Normalize: ensure E.164 format; Thai numbers start with 0 → replace with +66
    String phone = raw;
    if (phone.startsWith('0') && phone.length == 10) {
      phone = '+66${phone.substring(1)}';
    }
    if (!RegExp(r'^\+\d{9,15}$').hasMatch(phone)) {
      _showError(AppLocalizations.of(context).tr('phone.error.invalid'));
      return;
    }

    setState(() => _sending = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(phone: phone);
      if (!mounted) return;
      setState(() {
        _phone = phone;
        _otpSent = true;
        _resendCountdown = 60;
      });
      _startResendTimer();
    } on AuthException catch (e) {
      if (mounted) {
        _showError(e.message.isNotEmpty
            ? e.message
            : AppLocalizations.of(context).tr('phone.error.send_failed'));
      }
    } catch (_) {
      if (mounted) {
        _showError(AppLocalizations.of(context).tr('phone.error.send_failed'));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── verify OTP ───────────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final token = _otpCtrl.text.trim();
    if (token.length != 6) {
      _showError(AppLocalizations.of(context).tr('phone.error.verify_failed'));
      return;
    }

    setState(() => _verifying = true);
    try {
      final res = await Supabase.instance.client.auth.verifyOTP(
        phone: _phone,
        token: token,
        type: OtpType.sms,
      );
      if (!mounted) return;
      final user = res.user;
      if (user == null) {
        _showError(AppLocalizations.of(context).tr('phone.error.verify_failed'));
        return;
      }
      await _syncBackend(user);
    } on AuthException catch (e) {
      if (mounted) {
        _showError(e.message.isNotEmpty
            ? e.message
            : AppLocalizations.of(context).tr('phone.error.verify_failed'));
      }
    } catch (_) {
      if (mounted) {
        _showError(AppLocalizations.of(context).tr('phone.error.verify_failed'));
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  // ── backend sync ─────────────────────────────────────────────────────────
  Future<void> _syncBackend(User user) async {
    // Phone users may not have an email — use phone as identifier
    final email = user.email ?? user.phone ?? _phone;
    final result = await _authService.socialLogin(
      email: email,
      name: user.phone ?? _phone,
      uid: user.id,
      provider: 'phone',
    );
    if (!mounted) return;
    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>;
      ref.read(userDataProvider.notifier).setUserId(data['user_id'] as int);
      ref.read(userDataProvider.notifier).setLoginInfo(email, '');
      final needsOnboarding = data['onboarding_required'] == true;
      if (needsOnboarding) {
        ref.read(userDataProvider.notifier).setPersonalInfo(
              name: (data['username'] as String?) ?? _phone,
              birthDate: DateTime.now(),
              height: 0,
              weight: 0,
            );
      }
      routeAfterAuth(
        context,
        ref,
        destination: (_) =>
            needsOnboarding ? const GenderSelectionScreen() : const MainScreen(),
        requireConsent: !needsOnboarding,
      );
    } else {
      _showError(result['message']?.toString() ??
          AppLocalizations.of(context).tr('phone.error.verify_failed'));
    }
  }

  // ── resend timer ─────────────────────────────────────────────────────────
  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) t.cancel();
      });
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = context.palette;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: palette.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _otpSent ? _buildOtpStep(l10n) : _buildPhoneStep(l10n),
          ),
        ),
      ),
    );
  }

  // ── step 1: phone entry ───────────────────────────────────────────────────
  Widget _buildPhoneStep(AppLocalizations l10n) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.phone_outlined, color: _green, size: 28),
      ),
      const SizedBox(height: 20),
      Text(l10n.tr('phone.title'),
          style: const TextStyle(
              fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1A2E0F))),
      const SizedBox(height: 8),
      Text(l10n.tr('phone.subtitle'),
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5)),
      const SizedBox(height: 32),
      Text(l10n.tr('phone.label'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A2E0F))),
      const SizedBox(height: 8),
      _buildInput(
        controller: _phoneCtrl,
        hint: l10n.tr('phone.hint'),
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[+\d\s]'))],
      ),
      const SizedBox(height: 28),
      SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _sending ? null : _sendOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _sending
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text(l10n.tr('phone.cta'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    ]);
  }

  // ── step 2: OTP entry ─────────────────────────────────────────────────────
  Widget _buildOtpStep(AppLocalizations l10n) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 16),
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.sms_outlined, color: _green, size: 28),
      ),
      const SizedBox(height: 20),
      Text(l10n.tr('phone.otp.title'),
          style: const TextStyle(
              fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1A2E0F))),
      const SizedBox(height: 8),
      Text(l10n.tr('phone.otp.subtitle', {'phone': _phone}),
          style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.5)),
      const SizedBox(height: 32),
      _buildInput(
        controller: _otpCtrl,
        hint: l10n.tr('phone.otp.hint'),
        icon: Icons.lock_outlined,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
      ),
      const SizedBox(height: 28),
      SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _verifying ? null : _verifyOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _verifying
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text(l10n.tr('phone.otp.cta'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
      const SizedBox(height: 20),
      Center(
        child: _resendCountdown > 0
            ? Text(
                l10n.tr('phone.otp.resend_in', {'sec': '$_resendCountdown'}),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500))
            : TextButton(
                onPressed: _sending ? null : _sendOtp,
                child: Text(l10n.tr('phone.otp.resend'),
                    style: const TextStyle(
                        fontSize: 14, color: _green, fontWeight: FontWeight.w600)),
              ),
      ),
      const SizedBox(height: 8),
      Center(
        child: TextButton(
          onPressed: () => setState(() {
            _otpSent = false;
            _otpCtrl.clear();
          }),
          child: Text(l10n.tr('phone.or_use'),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        ),
      ),
    ]);
  }

  // ── shared input field ────────────────────────────────────────────────────
  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 16, color: Color(0xFF1A2E0F)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 15, color: Colors.grey.shade400),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 10),
          child: Icon(icon, size: 20, color: Colors.grey.shade400),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
      ),
    );
  }
}
