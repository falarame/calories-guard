// Hot-path localization for Calories Guard.
//
// Hand-rolled Map<String,String> keyed by [Locale.languageCode].
// Default locale is English; users can switch to Thai via Settings.
//
// Usage:
//   final l10n = AppLocalizations.of(context);
//   Text(l10n.tr('login.title'));
//
// Missing-key behaviour: falls back to English, then to the key itself.
// Never throws — a missing translation shouldn't break a production screen.
//
// TODO: catalogue is approaching the size where ARB + flutter gen-l10n
// becomes worthwhile. Migrate when adding ICU plurals or a third locale.

import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('th'),
  ];

  /// Look up a translation. Falls back to English, then to the key itself.
  /// Supports `{name}` placeholders via [params].
  String tr(String key, [Map<String, Object?>? params]) {
    final lang = locale.languageCode;
    final table = _catalogue[lang] ?? _catalogue['en']!;
    var value = table[key] ?? _catalogue['en']?[key] ?? key;
    if (params != null && params.isNotEmpty) {
      params.forEach((k, v) {
        value = value.replaceAll('{$k}', '${v ?? ''}');
      });
    }
    return value;
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

const Map<String, Map<String, String>> _catalogue = {
  'en': {
    // app-wide
    'app.name': 'Calories Guard',
    'common.cancel': 'Cancel',
    'common.confirm': 'Confirm',
    'common.loading': 'Loading…',
    'common.retry': 'Retry',
    'common.save': 'Save',
    'common.close': 'Close',
    'common.ok': 'OK',
    'common.delete': 'Delete',
    'common.error': 'Error',
    'common.not_set': 'Not set',
    'unit.kg': 'kg',
    'unit.kcal': 'kcal',
    'unit.day': 'day',
    'unit.days': 'days',
    'unit.month': 'month',
    'unit.months': 'months',

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

    // home
    'home.greeting': 'Hi',
    'home.today_calories': "Today's calories",
    'home.goal': 'Goal',
    'home.water': 'Water',
    'home.weight': 'Weight',
    'home.weight.target': 'Target',
    'home.weight.lose_more': 'Lose more',
    'home.weight.gain_more': 'Gain more',
    'home.bmi': 'BMI',
    'home.graph': 'Graph',
    'home.bmi_band_title': 'BMI ranges (for Asians)',

    // progress
    'progress.title': 'Progress',
    'progress.weight_chart': 'Weight chart',
    'progress.points_count': '{count} points',
    'progress.legend.actual': 'Actual weight',
    'progress.legend.target': 'Target',
    'progress.no_data.title': 'No weight data yet',
    'progress.no_data.body': 'Record your weight in profile to view the chart',
    'progress.goal.start': 'Start',
    'progress.goal.current': 'Current',
    'progress.goal.target': 'Target',
    'progress.goal.deadline': 'Deadline',
    'progress.goal.estimate': 'Estimate',
    'progress.goal.remaining': 'Remaining',
    'progress.goal.type.lose': 'Lose weight',
    'progress.goal.type.gain': 'Gain weight / muscle',
    'progress.goal.type.maintain': 'Maintain weight',
    'progress.goal.no_deadline': 'Not set',
    'progress.goal.in_days': 'in {days} days',
    'progress.goal.in_about_days': '~{days} days left',
    'progress.goal.in_about_months': '~{months} months left',

    // weight chart screen
    'weight.title': 'Weight',
    'weight.record_cta': 'Record weight',
    'weight.dialog.title': 'Record new weight',
    'weight.dialog.hint': 'e.g. 65.4',
    'weight.dialog.save': 'Save',
    'weight.dialog.error.invalid': 'Please enter a valid weight',
    'weight.dialog.success': 'Weight saved',
    'weight.dialog.error.failed': "Couldn't save weight",

    // settings
    'settings.title': 'Settings',
    'settings.group.general': 'General',
    'settings.group.display': 'Display',
    'settings.group.support': 'Support',
    'settings.group.about': 'About',
    'settings.group.account': 'Account',
    'settings.privacy': 'Privacy',
    'settings.privacy.body':
        'We protect your personal data securely under PDPA standards.',
    'settings.notifications': 'Notifications',
    'settings.language': 'Language',
    'settings.language.picker_title': 'Select Language',
    'settings.region': 'Food region',
    'settings.region.picker_title': 'Choose food region',
    'settings.region.use_central': 'Use central name',
    'settings.region.central': 'Central',
    'settings.region.northern': 'Northern',
    'settings.region.northeastern': 'Northeastern',
    'settings.region.southern': 'Southern',
    'settings.region.changed': 'Food region set to {label}',
    'settings.region.failed': "Couldn't save region ({code})",
    'settings.theme': 'Theme',
    'settings.theme.picker_title': 'Choose Theme',
    'settings.theme.light': 'Light',
    'settings.theme.dark': 'Dark',
    'settings.theme.system': 'System',
    'settings.theme.changed': 'Theme set to {label}',
    'settings.language.changed': 'Language set to {label}',
    'settings.suggest_feature': 'Suggest a feature',
    'settings.suggest_feature.body':
        'Send your feedback to support@caloriesguard.com',
    'settings.contact': 'Contact us',
    'settings.help': 'Get help',
    'settings.help.body': 'Quick start guide…',
    'settings.rate': 'Rate us',
    'settings.rate.thanks': 'Thanks for rating us ❤️',
    'settings.about': 'About',
    'settings.about.body': 'Calories Guard v1.0.0',
    'settings.switch_account': 'Switch account',
    'settings.delete_account': 'Delete account',
    'settings.delete_account.confirm_title': 'Confirm account deletion',
    'settings.delete_account.confirm_body':
        'This action is permanent. All your data will be lost. Continue?',
    'settings.delete_account.confirm_cta': 'Delete',
    'settings.delete_account.success': 'Account deleted',
    'settings.delete_account.error': 'Error: {message}',
    'settings.logout': 'Log out',
    'settings.loading': 'Loading',

    // consent
    'consent.title': 'Data Usage Consent',
    'consent.heading': 'Personal Data Usage Consent',
    'consent.body1':
        'This app collects personal data such as name, email, password, '
        'date of birth, gender, weight, and height to create your account '
        'and to compute BMI, BMR, and TDEE — used for health assessment '
        'and tailored food recommendations aligned with your weight goals.',
    'consent.body2':
        'The data you log is used to power features like meal-pattern '
        'tracking and health insights. It is stored securely and used '
        'only within this application.',
    'consent.checkbox': 'I agree to the data usage terms',
    'consent.cta': 'Save',
    'consent.error.must_accept': 'Please accept the terms to continue',

    // record food
    'record.title': 'Record meal',
    'record.search_hint': 'Search for a dish…',
    'record.add_item': 'Add item',
    'record.save': 'Save this meal',
    'record.meal.breakfast': 'Breakfast',
    'record.meal.lunch': 'Lunch',
    'record.meal.dinner': 'Dinner',
    'record.meal.snack': 'Snack',

    // api errors
    'error.network': "Can't reach the server. Please try again.",
    'error.timeout': 'The server took too long to respond. Please try again.',
    'error.server': 'Something went wrong on our end.',
    'error.ai_unavailable':
        'The AI coach is temporarily unavailable. We\'ll be back shortly.',
    'error.upgrade_required':
        'Your app is out of date. Please update to continue.',
  },
  'th': {
    // app-wide
    'app.name': 'Calories Guard',
    'common.cancel': 'ยกเลิก',
    'common.confirm': 'ยืนยัน',
    'common.loading': 'กำลังโหลด…',
    'common.retry': 'ลองใหม่',
    'common.save': 'บันทึก',
    'common.close': 'ปิด',
    'common.ok': 'ตกลง',
    'common.delete': 'ลบ',
    'common.error': 'เกิดข้อผิดพลาด',
    'common.not_set': 'ยังไม่ตั้งค่า',
    'unit.kg': 'กก.',
    'unit.kcal': 'แคล',
    'unit.day': 'วัน',
    'unit.days': 'วัน',
    'unit.month': 'เดือน',
    'unit.months': 'เดือน',

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

    // home
    'home.greeting': 'สวัสดี',
    'home.today_calories': 'แคลอรี่วันนี้',
    'home.goal': 'เป้าหมาย',
    'home.water': 'น้ำ',
    'home.weight': 'น้ำหนัก',
    'home.weight.target': 'เป้าหมาย',
    'home.weight.lose_more': 'ลดอีก',
    'home.weight.gain_more': 'เพิ่มอีก',
    'home.bmi': 'BMI',
    'home.graph': 'กราฟ',
    'home.bmi_band_title': 'เกณฑ์ BMI (สำหรับชาวเอเชีย)',

    // progress
    'progress.title': 'ความคืบหน้า',
    'progress.weight_chart': 'กราฟน้ำหนัก',
    'progress.points_count': '{count} จุด',
    'progress.legend.actual': 'น้ำหนักจริง',
    'progress.legend.target': 'เป้าหมาย',
    'progress.no_data.title': 'ยังไม่มีข้อมูลน้ำหนัก',
    'progress.no_data.body': 'บันทึกน้ำหนักในโปรไฟล์เพื่อดูกราฟ',
    'progress.goal.start': 'เริ่มต้น',
    'progress.goal.current': 'ปัจจุบัน',
    'progress.goal.target': 'เป้าหมาย',
    'progress.goal.deadline': 'กำหนดเส้นตาย',
    'progress.goal.estimate': 'คาดการณ์',
    'progress.goal.remaining': 'เหลืออีก',
    'progress.goal.type.lose': 'ลดน้ำหนัก',
    'progress.goal.type.gain': 'เพิ่มน้ำหนัก / กล้ามเนื้อ',
    'progress.goal.type.maintain': 'รักษาน้ำหนัก',
    'progress.goal.no_deadline': 'ไม่ได้กำหนด',
    'progress.goal.in_days': 'อีก {days} วัน',
    'progress.goal.in_about_days': 'อีก ~{days} วัน',
    'progress.goal.in_about_months': 'อีก ~{months} เดือน',

    // weight chart screen
    'weight.title': 'น้ำหนัก',
    'weight.record_cta': 'บันทึกน้ำหนัก',
    'weight.dialog.title': 'บันทึกน้ำหนักใหม่',
    'weight.dialog.hint': 'เช่น 65.4',
    'weight.dialog.save': 'บันทึก',
    'weight.dialog.error.invalid': 'กรุณาใส่น้ำหนักที่ถูกต้อง',
    'weight.dialog.success': 'บันทึกน้ำหนักแล้ว',
    'weight.dialog.error.failed': 'บันทึกน้ำหนักไม่สำเร็จ',

    // settings
    'settings.title': 'ตั้งค่า',
    'settings.group.general': 'ทั่วไป',
    'settings.group.display': 'การแสดงผล',
    'settings.group.support': 'สนับสนุน',
    'settings.group.about': 'เกี่ยวกับ',
    'settings.group.account': 'บัญชี',
    'settings.privacy': 'ความเป็นส่วนตัว',
    'settings.privacy.body':
        'เราเก็บรักษาข้อมูลส่วนบุคคลของคุณอย่างปลอดภัยตามมาตรฐาน PDPA',
    'settings.notifications': 'การแจ้งเตือน',
    'settings.language': 'ภาษา',
    'settings.language.picker_title': 'เลือกภาษา',
    'settings.region': 'ชื่ออาหารตามภูมิภาค',
    'settings.region.picker_title': 'เลือกภูมิภาคของชื่ออาหาร',
    'settings.region.use_central': 'ใช้ชื่อกลาง',
    'settings.region.central': 'ภาคกลาง',
    'settings.region.northern': 'ภาคเหนือ',
    'settings.region.northeastern': 'ภาคอีสาน',
    'settings.region.southern': 'ภาคใต้',
    'settings.region.changed': 'ตั้งชื่ออาหารเป็น {label} แล้ว',
    'settings.region.failed': 'บันทึกภูมิภาคไม่สำเร็จ ({code})',
    'settings.theme': 'ธีม',
    'settings.theme.picker_title': 'เลือกธีม',
    'settings.theme.light': 'สว่าง',
    'settings.theme.dark': 'มืด',
    'settings.theme.system': 'ตามระบบ',
    'settings.theme.changed': 'เปลี่ยนธีมเป็น {label} แล้ว',
    'settings.language.changed': 'เปลี่ยนภาษาเป็น {label} แล้ว',
    'settings.suggest_feature': 'เสนอฟีเจอร์ใหม่',
    'settings.suggest_feature.body':
        'ส่งข้อเสนอแนะได้ที่ support@caloriesguard.com',
    'settings.contact': 'ติดต่อเรา',
    'settings.help': 'ขอความช่วยเหลือ',
    'settings.help.body': 'คู่มือการใช้งานเบื้องต้น...',
    'settings.rate': 'ให้คะแนนเรา',
    'settings.rate.thanks': 'ขอบคุณที่ให้คะแนนเรา ❤️',
    'settings.about': 'เกี่ยวกับ',
    'settings.about.body': 'Calories Guard v1.0.0',
    'settings.switch_account': 'เปลี่ยนบัญชี',
    'settings.delete_account': 'ลบบัญชี',
    'settings.delete_account.confirm_title': 'ยืนยันการลบบัญชี',
    'settings.delete_account.confirm_body':
        'การกระทำนี้ไม่สามารถย้อนกลับได้ ข้อมูลทั้งหมดของคุณจะหายไป ยืนยันหรือไม่?',
    'settings.delete_account.confirm_cta': 'ยืนยันลบ',
    'settings.delete_account.success': 'ลบบัญชีเรียบร้อยแล้ว',
    'settings.delete_account.error': 'เกิดข้อผิดพลาด: {message}',
    'settings.logout': 'ออกจากระบบ',
    'settings.loading': 'กำลังโหลด',

    // consent
    'consent.title': 'การยินยอมการใช้ข้อมูล',
    'consent.heading': 'การยินยอมการใช้ข้อมูลส่วนบุคคล',
    'consent.body1':
        'แอปพลิเคชันนี้มีการเก็บข้อมูลส่วนบุคคลของผู้ใช้ เช่น ชื่อ-นามสกุล '
        'อีเมล รหัสผ่าน วันเกิด เพศ น้ำหนัก และส่วนสูง '
        'เพื่อใช้ในการสร้างบัญชีผู้ใช้ และนำข้อมูลไปคำนวณค่า BMI, BMR และ TDEE '
        'สำหรับการประเมินสุขภาพและแนะนำการรับประทานอาหารที่เหมาะสม'
        'กับเป้าหมายการควบคุมน้ำหนักของผู้ใช้',
    'consent.body2':
        'ข้อมูลที่ผู้ใช้บันทึกในแอปจะถูกนำไปใช้เพื่อการทำงานของระบบ เช่น '
        'การติดตามพฤติกรรมการรับประทานอาหาร '
        'และการแสดงผลข้อมูลสุขภาพของผู้ใช้ '
        'ทั้งนี้ข้อมูลจะถูกจัดเก็บอย่างเหมาะสมและใช้ภายในระบบของแอปพลิเคชันเท่านั้น',
    'consent.checkbox': 'ฉันยอมรับเงื่อนไขการใช้ข้อมูล',
    'consent.cta': 'บันทึก',
    'consent.error.must_accept': 'กรุณายอมรับเงื่อนไขก่อน',

    // record food
    'record.title': 'บันทึกอาหาร',
    'record.search_hint': 'ค้นหาเมนูอาหาร…',
    'record.add_item': 'เพิ่มเมนู',
    'record.save': 'บันทึกมื้อนี้',
    'record.meal.breakfast': 'มื้อเช้า',
    'record.meal.lunch': 'มื้อกลางวัน',
    'record.meal.dinner': 'มื้อเย็น',
    'record.meal.snack': 'ของว่าง',

    // api errors (mirrors api_client.dart)
    'error.network': 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาลองใหม่',
    'error.timeout': 'เซิร์ฟเวอร์ตอบช้าเกินไป กรุณาลองใหม่',
    'error.server': 'เกิดข้อผิดพลาดฝั่งเซิร์ฟเวอร์',
    'error.ai_unavailable':
        'ผู้ช่วย AI ไม่พร้อมให้บริการชั่วคราว เราจะกลับมาให้ใช้เร็วๆ นี้',
    'error.upgrade_required':
        'เวอร์ชันแอปของคุณเก่าเกินไป กรุณาอัปเดตแอปเพื่อใช้งานต่อ',
  },
};
