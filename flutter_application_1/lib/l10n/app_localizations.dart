// Hot-path localization for Calories Guard.
//
// We deliberately do NOT use `flutter_localizations` + gen-l10n yet — that
// pipeline adds build steps (pubspec l10n config, codegen) that the team
// hasn't adopted. What we need today is:
//
//   1. English strings on the screens a non-Thai beta tester will see first
//      (welcome, login, register, record_food, home dashboard).
//   2. English-ified error messages coming out of api_client.dart, so an
//      English-locale device doesn't show Thai snackbars.
//
// That's small enough to hand-roll with Map<String,String> keyed by
// [Locale.languageCode]. When the catalogue grows past ~50 keys or designers
// start asking for ICU plurals, migrate this file to an `.arb` + gen-l10n
// setup. The public API below (`AppLocalizations.of(context).tr('key')` and
// the delegate wiring in main.dart) is compatible with what gen-l10n
// produces, so callers won't need to change.
//
// Usage:
//   final l10n = AppLocalizations.of(context);
//   Text(l10n.tr('login.title'));
//
// Missing-key behaviour: falls back to the English catalogue, then to the
// key itself. Never throws — a missing translation shouldn't break a
// production screen.

import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('th'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('th'),
    Locale('en'),
  ];

  /// Look up a translation. Falls back to English, then to the key itself.
  String tr(String key) {
    final lang = locale.languageCode;
    final table = _catalogue[lang] ?? _catalogue['en']!;
    return table[key] ?? _catalogue['en']?[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales
      .any((l) => l.languageCode == locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// -- Catalogue ---------------------------------------------------------------
// Keep keys grouped by screen. Order inside a group: title, primary CTA,
// form labels, errors. When adding a key, add BOTH th and en in the same
// commit so the fallback never silently kicks in.

const Map<String, Map<String, String>> _catalogue = {
  'th': {
    // app-wide
    'app.name': 'Calories Guard',
    'common.cancel': 'ยกเลิก',
    'common.confirm': 'ยืนยัน',
    'common.loading': 'กำลังโหลด…',
    'common.retry': 'ลองใหม่',
    'common.save': 'บันทึก',

    // welcome
    'welcome.tagline': 'ควบคุมแคลอรี่ได้ดั่งใจ',
    'welcome.cta.login': 'เข้าสู่ระบบ',
    'welcome.cta.register': 'สมัครสมาชิก',

    // login
    'login.title': 'ยินดีต้อนรับกลับ',
    'login.email': 'อีเมล',
    'login.password': 'รหัสผ่าน',
    'login.forgot': 'ลืมรหัสผ่าน?',
    'login.cta': 'เข้าสู่ระบบ',
    'login.error.invalid': 'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
    'login.error.password_min': 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร',

    // register
    'register.title': 'สมัครสมาชิก',
    'register.cta': 'ถัดไป',

    // record food
    'record.title': 'บันทึกอาหาร',
    'record.search_hint': 'ค้นหาเมนูอาหาร…',
    'record.add_item': 'เพิ่มเมนู',
    'record.save': 'บันทึกมื้อนี้',
    'record.meal.breakfast': 'มื้อเช้า',
    'record.meal.lunch': 'มื้อกลางวัน',
    'record.meal.dinner': 'มื้อเย็น',
    'record.meal.snack': 'ของว่าง',

    // home
    'home.greeting': 'สวัสดี',
    'home.today_calories': 'แคลอรี่วันนี้',
    'home.goal': 'เป้าหมาย',
    'home.water': 'น้ำ',

    // api errors (mirrors api_client.dart)
    'error.network': 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาลองใหม่',
    'error.timeout': 'เซิร์ฟเวอร์ตอบช้าเกินไป กรุณาลองใหม่',
    'error.server': 'เกิดข้อผิดพลาดฝั่งเซิร์ฟเวอร์',
    'error.ai_unavailable':
        'ผู้ช่วย AI ไม่พร้อมให้บริการชั่วคราว เราจะกลับมาให้ใช้เร็วๆ นี้',
    'error.upgrade_required':
        'เวอร์ชันแอปของคุณเก่าเกินไป กรุณาอัปเดตแอปเพื่อใช้งานต่อ',
  },
  'en': {
    // app-wide
    'app.name': 'Calories Guard',
    'common.cancel': 'Cancel',
    'common.confirm': 'Confirm',
    'common.loading': 'Loading…',
    'common.retry': 'Retry',
    'common.save': 'Save',

    // welcome
    'welcome.tagline': 'Take control of your calories',
    'welcome.cta.login': 'Log in',
    'welcome.cta.register': 'Sign up',

    // login
    'login.title': 'Welcome back',
    'login.email': 'Email',
    'login.password': 'Password',
    'login.forgot': 'Forgot password?',
    'login.cta': 'Log in',
    'login.error.invalid': 'Incorrect email or password',
    'login.error.password_min': 'Password must be at least 6 characters',

    // register
    'register.title': 'Create account',
    'register.cta': 'Next',

    // record food
    'record.title': 'Record meal',
    'record.search_hint': 'Search for a dish…',
    'record.add_item': 'Add item',
    'record.save': 'Save this meal',
    'record.meal.breakfast': 'Breakfast',
    'record.meal.lunch': 'Lunch',
    'record.meal.dinner': 'Dinner',
    'record.meal.snack': 'Snack',

    // home
    'home.greeting': 'Hi',
    'home.today_calories': "Today's calories",
    'home.goal': 'Goal',
    'home.water': 'Water',

    // api errors
    'error.network': "Can't reach the server. Please try again.",
    'error.timeout': 'The server took too long to respond. Please try again.',
    'error.server': 'Something went wrong on our end.',
    'error.ai_unavailable':
        'The AI coach is temporarily unavailable. We\'ll be back shortly.',
    'error.upgrade_required':
        'Your app is out of date. Please update to continue.',
  },
};
