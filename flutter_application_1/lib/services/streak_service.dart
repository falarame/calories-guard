import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_helper.dart';

class StreakService {
  static const _keyCount = 'streak_count';
  static const _keyLastDate = 'streak_last_date'; // format: yyyy-MM-dd

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// เรียกหลังบันทึกอาหารสำเร็จ — อัปเดต streak และ cancel streak warning
  static Future<int> updateStreak() async {
    if (kIsWeb) return 0;
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final lastDate = prefs.getString(_keyLastDate) ?? '';
    final count = prefs.getInt(_keyCount) ?? 0;

    int newCount = count;
    if (lastDate == today) {
      // บันทึกซ้ำวันนี้ — ไม่เปลี่ยน streak
      return count;
    }

    final yesterday = _dateKey(DateTime.now().subtract(const Duration(days: 1)));
    if (lastDate == yesterday || count == 0) {
      newCount = count + 1;
    } else {
      // ขาดไปมากกว่า 1 วัน — reset
      newCount = 1;
    }

    await prefs.setInt(_keyCount, newCount);
    await prefs.setString(_keyLastDate, today);

    // Cancel streak warning เพราะ user บันทึกแล้ววันนี้
    await NotificationHelper.cancelStreakWarning();

    return newCount;
  }

  static Future<int> getStreak() async {
    if (kIsWeb) return 0;
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(_keyLastDate) ?? '';
    final count = prefs.getInt(_keyCount) ?? 0;
    if (count == 0) return 0;

    // ถ้าหายไปมากกว่า 1 วัน แสดง 0 (streak ขาดแล้ว)
    final yesterday = _dateKey(DateTime.now().subtract(const Duration(days: 1)));
    final today = _dateKey(DateTime.now());
    if (lastDate != today && lastDate != yesterday) return 0;
    return count;
  }

  /// เรียกตอนเปิดแอปทุกครั้ง — schedule streak warning ถ้ายังไม่ได้บันทึกวันนี้
  static Future<void> scheduleWarningIfNeeded() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final today = _dateKey(DateTime.now());
    final lastDate = prefs.getString(_keyLastDate) ?? '';
    final count = prefs.getInt(_keyCount) ?? 0;

    if (lastDate == today) {
      // บันทึกแล้ววันนี้ ไม่ต้องเตือน
      await NotificationHelper.cancelStreakWarning();
    } else {
      // ยังไม่ได้บันทึกวันนี้ — schedule เตือน 20:00
      await NotificationHelper.scheduleStreakWarning(count);
    }
  }
}
