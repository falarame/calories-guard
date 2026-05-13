/// Background-isolate-safe localization for notification strings.
///
/// Does NOT require BuildContext — reads the saved locale from SharedPreferences
/// and looks up strings from an in-memory catalog identical to the entries in
/// AppLocalizations.  Call [init] once (before the first use) in both the main
/// isolate and in any background isolate that shows notifications.
///
/// Missing-key behaviour: falls back to Thai, then to the key itself.
library;

import 'package:shared_preferences/shared_preferences.dart';

class NotificationL10n {
  static const _prefKeyLocale = 'app_locale';
  static String _lang = 'th';

  /// Load locale from SharedPreferences.
  /// Call this in main() before runApp() and inside background handlers.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _lang = prefs.getString(_prefKeyLocale) ?? 'th';
  }

  /// Look up a translation key. Supports `{name}` placeholders.
  static String tr(String key, [Map<String, Object?>? params]) {
    final table = _catalogue[_lang] ?? _catalogue['th']!;
    var value = table[key] ?? _catalogue['th']?[key] ?? key;
    if (params != null) {
      params.forEach((k, v) {
        value = value.replaceAll('{$k}', '${v ?? ''}');
      });
    }
    return value;
  }
}

// ── Notification string catalog ───────────────────────────────────────────────
// Keys follow the notif.* namespace.
// Placeholders: {count}, {current}, {target}, {remaining}, {day}, {daysSince}.

const Map<String, Map<String, String>> _catalogue = {
  'en': {
    // Meal reminders
    'notif.meal.breakfast.title': '🍳 Don\'t skip breakfast!',
    'notif.meal.breakfast.body':
        'Remember to log your breakfast in CaloriesGuard',
    'notif.meal.lunch.title': '🍱 Lunchtime — did you eat yet?',
    'notif.meal.lunch.body': 'Log your lunch to keep tracking',
    'notif.meal.dinner.title': '🥗 Light dinner tonight?',
    'notif.meal.dinner.body': 'End of day — log your dinner and check your total',
    // Water
    'notif.water.title': '💧 Time for a sip!',
    'notif.water.body': 'Staying hydrated boosts your metabolism and skin health',
    // Motivation
    'notif.motivation.title': '🔥 New day, fresh start!',
    'notif.motivation.body': 'Discipline starts with you — let\'s crush it today!',
    // Recap
    'notif.recap.title': '🌙 Daily summary',
    'notif.recap.body': 'How did you do today? Tap to check your progress',
    // Streak warning
    'notif.streak.warning.title': '🔥 Your {count}-day streak is at risk!',
    'notif.streak.warning.body':
        'Log your meals before 8 PM to keep your streak alive',
    // Re-engagement
    'notif.reEngagement.day2.title': '😔 We miss you!',
    'notif.reEngagement.day2.body':
        'It\'s been 2 days since you logged. Come check your progress 💪',
    'notif.reEngagement.day5.title': '🔥 Your streak is about to disappear!',
    'notif.reEngagement.day5.body':
        '5 days without logging — don\'t let your hard work go to waste',
    // Calorie alerts
    'notif.calorie.alert.title': '🚨 You\'ve exceeded your calorie goal!',
    'notif.calorie.alert.body':
        'You\'ve consumed {current} / {target} kcal. Consider a short walk 🚶',
    'notif.calorie.warning.title': '⚠️ Almost at your limit',
    'notif.calorie.warning.body':
        'Only {remaining} kcal left — choose lighter options for your next meal 🥦',
    // Weight
    'notif.weight.weekly.title': '⚖️ Time to weigh in!',
    'notif.weight.weekly.body': 'Update your weight for {day} to track progress',
    'notif.weight.overdue.title': '⚖️ Update your weight!',
    'notif.weight.overdue.body':
        'You haven\'t logged weight yet{daysSince}. Weigh in and see your progress 💪',
    // Birthday / TDEE
    'notif.birthday.title': '🎂 Happy Birthday!',
    'notif.birthday.body':
        'Wishing you great health this year! We\'ve updated your calorie goal to {newCalories} kcal/day.',
    'notif.tdee.title': '🔄 Goal updated',
    'notif.tdee.body':
        'Calories recalculated for your new age — new target: {newCalories} kcal/day',
    // Monthly summary
    'notif.monthly.summary.title': '📊 Monthly progress report',
    'notif.monthly.summary.on_track':
        'You\'re on track! {goalDaysLeft} days to go 🎯',
    'notif.monthly.summary.off_track':
        'Let\'s adjust the plan — {goalDaysLeft} days left. Check your progress report',
    'notif.monthly.summary.neutral': 'One month in — let\'s see how you\'re doing!',
    // Permissions
    'notif.permission.denied.banner':
        'Enable notifications for a better experience',
    'notif.permission.denied.cta': 'Settings',
    // Action button labels
    'notif.action.snooze': 'Snooze 30 min',
    'notif.action.log_now': 'Log now',
    'notif.action.water_logged': 'Done ✓',
    'notif.action.snooze_short': 'Snooze',
  },
  'th': {
    // Meal reminders
    'notif.meal.breakfast.title': '🍳 มื้อเช้าสำคัญนะ!',
    'notif.meal.breakfast.body':
        'อย่าลืมบันทึกอาหารเช้าลง CaloriesGuard นะครับ',
    'notif.meal.lunch.title': '🍱 เที่ยงแล้ว กินไรยัง?',
    'notif.meal.lunch.body': 'ทานมื้อเที่ยงแล้วมาจดบันทึกกันเถอะ',
    'notif.meal.dinner.title': '🥗 มื้อเย็นเบาๆ กันเถอะ',
    'notif.meal.dinner.body': 'จบวันแล้ว สรุปยอดแคลอรี่กันหน่อย',
    // Water
    'notif.water.title': '💧 จิบน้ำหน่อยมั้ย?',
    'notif.water.body': 'ดื่มน้ำเพื่อสุขภาพผิวและการเผาผลาญที่ดีนะครับ',
    // Motivation
    'notif.motivation.title': '🔥 เช้าวันใหม่ สดใสกว่าเดิม',
    'notif.motivation.body': 'วินัยเริ่มต้นที่ตัวเรา วันนี้สู้ๆ นะครับ!',
    // Recap
    'notif.recap.title': '🌙 สรุปผลวันนี้',
    'notif.recap.body': 'มาดูกันว่าวันนี้คุณทำได้ตามเป้าหมายหรือไม่?',
    // Streak warning
    'notif.streak.warning.title': '🔥 Streak {count} วันของคุณกำลังจะหาย!',
    'notif.streak.warning.body':
        'บันทึกอาหารวันนี้ก่อน 4 ทุ่มเพื่อรักษา streak ไว้นะ',
    // Re-engagement
    'notif.reEngagement.day2.title': '😔 เราคิดถึงคุณนะ!',
    'notif.reEngagement.day2.body':
        'ผ่านมา 2 วันแล้วที่ไม่ได้บันทึกอาหาร มาเช็กความคืบหน้ากันดีกว่า 💪',
    'notif.reEngagement.day5.title': '🔥 Streak ของคุณกำลังจะหาย!',
    'notif.reEngagement.day5.body':
        'ผ่านมา 5 วันแล้วที่ไม่ได้บันทึก อย่าปล่อยให้ความพยายามสูญเปล่านะ',
    // Calorie alerts
    'notif.calorie.alert.title': '🚨 พลังงานเกินเป้าหมายแล้ว!',
    'notif.calorie.alert.body':
        'คุณทานไป {current} / {target} KCAL แนะนำให้ขยับร่างกายเพิ่มหน่อยนะครับ',
    'notif.calorie.warning.title': '⚠️ ใกล้เต็มโควตาแล้วนะ',
    'notif.calorie.warning.body':
        'เหลืออีกแค่ {remaining} KCAL มื้อถัดไปเน้นผักหน่อยดีมั้ย? 🥦',
    // Weight
    'notif.weight.weekly.title': '⚖️ ได้เวลาชั่งน้ำหนักแล้ว',
    'notif.weight.weekly.body': '{day} นี้มาอัปเดตน้ำหนักล่าสุดกันเถอะ!',
    'notif.weight.overdue.title': '⚖️ อัปเดตน้ำหนักด้วยนะ!',
    'notif.weight.overdue.body':
        'ยังไม่ได้บันทึกน้ำหนักเลย{daysSince} ชั่งแล้วมาบันทึกเพื่อติดตามความก้าวหน้ากันเถอะ 💪',
    // Birthday / TDEE
    'notif.birthday.title': '🎂 สุขสันต์วันเกิด!',
    'notif.birthday.body':
        'ขอให้มีสุขภาพดีตลอดปีนะ! เราได้อัปเดตโควตาแคลอรี่เป็น {newCalories} kcal/วัน',
    'notif.tdee.title': '🔄 อัปเดตเป้าหมายแล้ว',
    'notif.tdee.body':
        'คำนวณแคลอรี่ใหม่ตามอายุปีนี้ — โควตาใหม่: {newCalories} kcal/วัน',
    // Monthly summary
    'notif.monthly.summary.title': '📊 สรุปความก้าวหน้ารายเดือน',
    'notif.monthly.summary.on_track':
        'คุณอยู่ในเส้นทางที่ถูกต้อง! เหลืออีก {goalDaysLeft} วันถึงเป้าหมาย 🎯',
    'notif.monthly.summary.off_track':
        'ต้องปรับแผนนิดนึงนะ เหลือ {goalDaysLeft} วัน ลองดูรายงานความก้าวหน้าดู',
    'notif.monthly.summary.neutral':
        'ผ่านมา 1 เดือนแล้ว มาดูว่าคุณทำได้ดีแค่ไหน!',
    // Permissions
    'notif.permission.denied.banner':
        'เปิดการแจ้งเตือนเพื่อใช้งานเต็มประสิทธิภาพ',
    'notif.permission.denied.cta': 'ตั้งค่า',
    // Action button labels
    'notif.action.snooze': 'เลื่อน 30 นาที',
    'notif.action.log_now': 'บันทึกเลย',
    'notif.action.water_logged': 'ดื่มแล้ว ✓',
    'notif.action.snooze_short': 'เลื่อน',
  },
};
