import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'l10n/app_localizations.dart';
import 'login_register/screens/welcome_screen.dart';
import 'services/notification_helper.dart';
import 'services/api_client.dart';
import 'constants/constants.dart';

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

  // เริ่มต้นและตั้งเวลาแจ้งเตือนในพื้นหลัง (เฉพาะ mobile)
  if (!kIsWeb) {
    NotificationHelper.init().then((_) async {
      await NotificationHelper.scheduleMealReminders();
      await NotificationHelper.scheduleDailyRecap();
      await NotificationHelper.scheduleMorningMotivation();
      await NotificationHelper.scheduleWaterReminders();
      await NotificationHelper.scheduleWeeklyWeightCheck();
    });
  }

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CalorieGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4C6414)),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      // L10n: follow system locale, fall back to Thai if system is neither
      // Thai nor English. See lib/l10n/app_localizations.dart for the hot-path
      // catalogue (task #17).
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (deviceLocale, supported) {
        if (deviceLocale == null) return const Locale('th');
        for (final l in supported) {
          if (l.languageCode == deviceLocale.languageCode) return l;
        }
        return const Locale('th');
      },
      home: const WelcomeScreen(),
    );
  }
}
