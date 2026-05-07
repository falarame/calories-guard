import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'l10n/app_localizations.dart';
import 'login_register/screens/data_consent_screen.dart';
import 'login_register/screens/gender_selection_screen.dart';
import 'login_register/screens/reset_password_screen.dart';
import 'login_register/screens/welcome_screen.dart';
import 'providers/settings_provider.dart';
import 'providers/user_data_provider.dart';
import 'services/auth_service.dart';
import 'services/notification_helper.dart';
import 'services/api_client.dart';
import 'theme/app_theme.dart';
import 'constants/constants.dart';
import 'widget/bottom_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConstants.supabaseAnonKey.isEmpty) {
    runApp(const _MissingConfigApp());
    return;
  }

  // Initialize Supabase (replaces Firebase)
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // Setup API client 401 handler
  ApiClient().onUnauthorized = () {
    // Will be connected to navigation once we have a global navigator key
    Supabase.instance.client.auth.signOut();
  };

  const sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

  if (sentryDsn.isEmpty) {
    runApp(const ProviderScope(child: MyApp()));
  } else {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 0.1;
        options.sendDefaultPii = false;
        options.environment = const String.fromEnvironment(
          'APP_ENV',
          defaultValue: 'development',
        );
      },
      appRunner: () => runApp(const ProviderScope(child: MyApp())),
    );
  }

  if (!kIsWeb) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initNotificationsAfterFirstFrame());
    });
  }
}

Future<void> _initNotificationsAfterFirstFrame() async {
  try {
    await NotificationHelper.init();
    await NotificationHelper.scheduleMealReminders();
    await NotificationHelper.scheduleDailyRecap();
    await NotificationHelper.scheduleMorningMotivation();
    await NotificationHelper.scheduleWaterReminders();
    await NotificationHelper.scheduleWeeklyWeightCheck();
  } catch (e, st) {
    debugPrint('Notification startup skipped: $e');
    debugPrintStack(stackTrace: st);
  }
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calories Guard',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF5F7F0),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Missing Supabase configuration. Rebuild the app with SUPABASE_ANON_KEY.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color(0xFF1A2E0F)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      title: 'Calories Guard',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => _EnvironmentBanner(child: child),
      home: const AuthBootstrap(),
    );
  }
}

class _EnvironmentBanner extends StatelessWidget {
  const _EnvironmentBanner({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (!AppConstants.isStaging) return child ?? const SizedBox.shrink();
    return Stack(
      children: [
        child ?? const SizedBox.shrink(),
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 12,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE67E22),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'STAGING',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthBootstrap extends ConsumerStatefulWidget {
  const AuthBootstrap({super.key});

  @override
  ConsumerState<AuthBootstrap> createState() => _AuthBootstrapState();
}

class _AuthBootstrapState extends ConsumerState<AuthBootstrap> {
  StreamSubscription<AuthState>? _authSub;
  bool _socialSyncing = false;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.passwordRecovery) {
        _openResetPasswordScreen();
        return;
      }
      if (event.event == AuthChangeEvent.initialSession ||
          event.event == AuthChangeEvent.signedIn) {
        _resumeOAuthSession(event.session);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resumeOAuthSession();
    });
  }

  void _openResetPasswordScreen() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        (route) => false,
      );
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _resumeOAuthSession([Session? session]) async {
    if (_socialSyncing || !mounted) return;
    final auth = Supabase.instance.client.auth;
    final user = (session ?? auth.currentSession)?.user;
    if (user == null || user.email == null || user.email!.isEmpty) return;

    final provider = _oauthProviderFrom(user.appMetadata);
    final isOAuthProvider =
        provider.isNotEmpty && provider != 'email' && provider != 'phone';
    if (!isOAuthProvider) return;

    _socialSyncing = true;
    final result = await AuthService().socialLogin(
      email: user.email!,
      name: (user.userMetadata?['full_name'] as String?) ??
          (user.userMetadata?['name'] as String?) ??
          user.email!,
      uid: user.id,
      provider: provider,
    );
    if (!mounted) return;
    if (result['success'] != true) {
      _socialSyncing = false;
      return;
    }

    final data = result['data'] as Map<String, dynamic>;
    ref.read(userDataProvider.notifier).setUserId(data['user_id'] as int);
    ref.read(userDataProvider.notifier).setLoginInfo(user.email!, '');

    final shouldContinueOnboarding = data['onboarding_required'] == true;
    if (shouldContinueOnboarding) {
      ref.read(userDataProvider.notifier).setPersonalInfo(
            name: (data['username'] as String?) ??
                (user.userMetadata?['full_name'] as String?) ??
                user.email!,
            birthDate: DateTime.now(),
            height: 0,
            weight: 0,
          );
    }
    routeAfterAuth(
      context,
      ref,
      destination: (_) => shouldContinueOnboarding
          ? const GenderSelectionScreen()
          : const MainScreen(),
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
    return appMetadata['provider']?.toString() ?? '';
  }

  @override
  Widget build(BuildContext context) => const WelcomeScreen();
}
