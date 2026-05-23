import 'package:flutter/material.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  // ── Animation Controllers ──────────────────────────────────────
  late final AnimationController _introCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _pulseCtrl;

  // ── Intro animations (staggered) ──────────────────────────────
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _titleFade;
  late final Animation<double> _titleScale;
  late final Animation<double> _badgeFade;
  late final Animation<double> _imageFade;
  late final Animation<double> _imageScale;
  late final Animation<double> _btnFade;
  late final Animation<Offset> _btnSlide;

  // ── Float & Pulse ──────────────────────────────────────────────
  late final Animation<double> _float;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    // --- Intro controller (1.4 s total) ---
    _introCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));

    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut)));
    _subtitleSlide =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _introCtrl,
                curve: const Interval(0.0, 0.35, curve: Curves.easeOut)));

    _titleFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.15, 0.5, curve: Curves.easeOut)));
    _titleScale = Tween<double>(begin: 0.75, end: 1.0).animate(CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.15, 0.5, curve: Curves.elasticOut)));

    _badgeFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.3, 0.55, curve: Curves.easeOut)));

    _imageFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.35, 0.7, curve: Curves.easeOut)));
    _imageScale = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOutBack)));

    _btnFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOut)));
    _btnSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _introCtrl,
            curve: const Interval(0.65, 1.0, curve: Curves.easeOut)));

    // --- Float controller (looping up/down) ---
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
    _float = Tween<double>(begin: -6, end: 6)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    // --- Pulse controller for button glow ---
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Start intro after a tiny delay
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _introCtrl.forward();
    });
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF0F5E0), Color(0xFFE8EFCF), Color(0xFFDCE8B8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  const SizedBox(height: 64),

                  // ── "ยินดีต้อนรับเข้าสู่" ──────────────────────
                  FadeTransition(
                    opacity: _subtitleFade,
                    child: SlideTransition(
                      position: _subtitleSlide,
                      child: const Text(
                        'ยินดีต้อนรับเข้าสู่',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF5A5A5A),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── App Name: Calories Guard ────────────────────
                  FadeTransition(
                    opacity: _titleFade,
                    child: ScaleTransition(
                      scale: _titleScale,
                      child: Column(children: [
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Calories ',
                                style: TextStyle(
                                  fontFamily: 'Karla',
                                  fontSize: 40,
                                  fontWeight: FontWeight.w300,
                                  color: Color(0xFF3D5A27),
                                  letterSpacing: 1,
                                ),
                              ),
                              TextSpan(
                                text: 'Guard',
                                style: TextStyle(
                                  fontFamily: 'Karla',
                                  fontSize: 40,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF628141),
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // ── Tagline badge ──────────────────────────────
                  FadeTransition(
                    opacity: _badgeFade,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF628141).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color:
                                const Color(0xFF628141).withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        '🌿  ติดตามแคลอรี่ • ใส่ใจสุขภาพ',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4C6414),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 44),

                  // ── Floating Image ─────────────────────────────
                  FadeTransition(
                    opacity: _imageFade,
                    child: ScaleTransition(
                      scale: _imageScale,
                      child: AnimatedBuilder(
                        animation: _float,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(0, _float.value),
                          child: child,
                        ),
                        child: Container(
                          width: 240,
                          height: 230,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF628141)
                                    .withValues(alpha: 0.15),
                                blurRadius: 30,
                                offset: const Offset(0, 16),
                                spreadRadius: 4,
                              ),
                            ],
                            image: const DecorationImage(
                              image: AssetImage(
                                  'assets/images/picture/welcome.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 56),

                  // ── CTA Button ─────────────────────────────────
                  FadeTransition(
                    opacity: _btnFade,
                    child: SlideTransition(
                      position: _btnSlide,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: AnimatedBuilder(
                          animation: _pulse,
                          builder: (_, child) => Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF628141)
                                      .withValues(alpha: 0.35 * _pulse.value),
                                  blurRadius: 20 * _pulse.value,
                                  spreadRadius: 2 * _pulse.value,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: child,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, a1, a2) =>
                                        const LoginScreen(),
                                    transitionsBuilder: (_, anim, __, child) =>
                                        FadeTransition(
                                            opacity: anim, child: child),
                                    transitionDuration:
                                        const Duration(milliseconds: 350),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4C6414),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'เข้าสู่ระบบ / สร้างบัญชีใหม่',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 16,
                                        color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Footer hint ────────────────────────────────
                  FadeTransition(
                    opacity: _btnFade,
                    child: Text(
                      'เริ่มต้นดูแลสุขภาพวันนี้ได้เลย',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
