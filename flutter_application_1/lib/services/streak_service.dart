import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'error_reporter.dart';
import 'notification_helper.dart';

/// Lifetime continuous streak with 2-day grace period.
/// - Logged today/yesterday → grace 0 (ok)
/// - 1 day missed → grace 1 (warning)
/// - 2 days missed → grace 2 (last chance, repair available)
/// - 3+ days missed → expired (must repair to restore, or reset to 1 on next log)
class StreakService {
  static const _keyCount = 'streak_count';
  static const _keyLastDate = 'streak_last_date'; // format: yyyy-MM-dd

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// อัปเดต streak หลังบันทึกอาหาร — รักษาความต่อเนื่องถ้าอยู่ใน grace
  static Future<int> updateStreak() async {
    if (kIsWeb) return 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _dateKey(DateTime.now());
      final lastDate = prefs.getString(_keyLastDate) ?? '';
      final count = prefs.getInt(_keyCount) ?? 0;

      if (lastDate == today) return count; // already logged

      int newCount;
      if (lastDate.isEmpty || count == 0) {
        newCount = 1;
      } else {
        final last = DateTime.parse(lastDate);
        final now = DateTime.now();
        final daysSince = DateTime(now.year, now.month, now.day)
            .difference(DateTime(last.year, last.month, last.day))
            .inDays;
        if (daysSince <= 2) {
          // within grace — continue streak
          newCount = count + 1;
        } else {
          // beyond grace — reset
          newCount = 1;
        }
      }

      await prefs.setInt(_keyCount, newCount);
      await prefs.setString(_keyLastDate, today);

      // Cancel any pending streak warning since user logged today
      await NotificationHelper.cancelStreakWarning();

      return newCount;
    } catch (e, st) {
      ErrorReporter.report('streak.update', e, st);
      return 0;
    }
  }

  /// อ่าน streak ปัจจุบัน — คืน 0 ถ้าขาดเกิน grace
  static Future<int> getStreak() async {
    if (kIsWeb) return 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDate = prefs.getString(_keyLastDate) ?? '';
      final count = prefs.getInt(_keyCount) ?? 0;
      if (count == 0 || lastDate.isEmpty) return 0;

      final last = DateTime.parse(lastDate);
      final now = DateTime.now();
      final daysSince = DateTime(now.year, now.month, now.day)
          .difference(DateTime(last.year, last.month, last.day))
          .inDays;
      if (daysSince <= 2) return count; // ok or in grace
      return 0; // expired
    } catch (e, st) {
      ErrorReporter.report('streak.get', e, st);
      return 0;
    }
  }

  /// คืนสถานะ grace:
  /// - 0 = บันทึกแล้ววันนี้/เมื่อวาน (ok)
  /// - 1 = ขาด 1 วัน (เตือน)
  /// - 2 = ขาด 2 วัน (วันสุดท้าย, repair ได้)
  /// - -1 = หมดเวลา grace (ขาด >2 วัน, ต้องใช้ repair กู้คืน)
  static Future<int> getGraceStatus() async {
    if (kIsWeb) return 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastDate = prefs.getString(_keyLastDate) ?? '';
      if (lastDate.isEmpty) return 0;
      final last = DateTime.parse(lastDate);
      final now = DateTime.now();
      final daysSince = DateTime(now.year, now.month, now.day)
          .difference(DateTime(last.year, last.month, last.day))
          .inDays;
      if (daysSince <= 0) return 0;
      if (daysSince == 1) return 1;
      if (daysSince == 2) return 2;
      return -1;
    } catch (e, st) {
      ErrorReporter.report('streak.grace', e, st);
      return 0;
    }
  }

  /// กู้คืน streak ที่ขาดไป — set last_date เป็นเมื่อวาน
  /// เพื่อให้บันทึกวันนี้แล้ว streak ต่อเนื่อง (+1 จากเดิม)
  /// Caller ต้องจัดการเรื่อง gem cost / free quota เองก่อนเรียก
  static Future<void> repairStreak() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await prefs.setString(_keyLastDate, _dateKey(yesterday));
    } catch (e, st) {
      ErrorReporter.report('streak.repair', e, st);
    }
  }

  /// เรียกตอน logout — ลบ streak data ทั้งหมด
  static Future<void> clear() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCount);
    await prefs.remove(_keyLastDate);
    await NotificationHelper.cancelStreakWarning();
  }

  /// เรียกตอนเปิดแอป — schedule streak warning ถ้ายังไม่บันทึกวันนี้
  static Future<void> scheduleWarningIfNeeded() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _dateKey(DateTime.now());
      final lastDate = prefs.getString(_keyLastDate) ?? '';
      final count = prefs.getInt(_keyCount) ?? 0;

      if (lastDate == today) {
        await NotificationHelper.cancelStreakWarning();
      } else {
        final grace = await getGraceStatus();
        await NotificationHelper.scheduleStreakWarning(count,
            graceStatus: grace);
      }
    } catch (e, st) {
      ErrorReporter.report('streak.schedule_warning', e, st);
    }
  }
}
