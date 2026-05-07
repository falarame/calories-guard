import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationHelper {
  static final _notification = FlutterLocalNotificationsPlugin();

  // ตั้งค่าเริ่มต้น
  static Future<void> init() async {
    if (kIsWeb) return;
    tz.initializeTimeZones(); // โหลดฐานข้อมูลเวลา

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // ไอคอนแอป
    const iosSettings = DarwinInitializationSettings();

    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notification.initialize(settings);

    // ✅ 2. เรียกขออนุญาตทันทีที่ Init (สำคัญมากสำหรับ Android 13+)
    await requestPermission();
  }

  // ✅ 3. เพิ่มฟังก์ชันขออนุญาต
  static Future<void> requestPermission() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation =
          _notification.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }
  }

  // ฟังก์ชันพื้นฐานสำหรับแสดงแจ้งเตือนทันที
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await _notification.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_id_alert', // ตั้งชื่อ channel ให้ต่างกันสำหรับ Alert
          'Alert Notifications',
          importance: Importance.max, // ✅ ต้อง Max ถึงจะเด้งทับหน้าจอ
          priority: Priority.high, // ✅ ต้อง High
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  // ฟังก์ชันตั้งเวลาเตือน (ทำซ้ำทุกวัน)
  static Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (kIsWeb) return;
    await _notification.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_id_daily',
          'Daily Reminders',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      // ✅ 4. แก้เป็น inexact เพื่อเลี่ยงปัญหา Permission บน Android 12+
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          DateTimeComponents.time, // ให้เตือนซ้ำทุกวันเวลาเดิม
    );
  }

  // คำนวณเวลาถัดไปที่จะเตือน
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // ==========================================
  // 🔥 รวมมิตรฟังก์ชันเรียกใช้ตามโจทย์ 4 ข้อ
  // ==========================================

  // 1. แจ้งเตือนกันลืม (Time-based)
  static Future<void> scheduleMealReminders() async {
    if (kIsWeb) return;
    await scheduleDailyNotification(
        id: 101,
        title: '🍳 มื้อเช้าสำคัญนะ!',
        body: 'อย่าลืมบันทึกอาหารเช้าลง CleanGoal นะครับ',
        hour: 08,
        minute: 00);
    await scheduleDailyNotification(
        id: 102,
        title: '🍱 เที่ยงแล้ว กินไรยัง?',
        body: 'ทานมื้อเที่ยงแล้วมาจดบันทึกกันเถอะ',
        hour: 12,
        minute: 00);
    await scheduleDailyNotification(
        id: 103,
        title: '🥗 มื้อเย็นเบาๆ กันเถอะ',
        body: 'จบวันแล้ว สรุปยอดแคลอรี่กันหน่อย',
        hour: 18,
        minute: 00);
  }

  // 2. แจ้งเตือนเตือนภัย (Alert) - เรียกตอนแคลอรี่เกิน
  static Future<void> showCalorieAlert(int current, int target) async {
    if (kIsWeb) return;
    await showNotification(
      id: 201,
      title: '🚨 พลังงานเกินเป้าหมายแล้ว!',
      body:
          'คุณทานไป $current / $target KCAL แนะนำให้ขยับร่างกายเพิ่มหน่อยนะครับ',
    );
  }

  // 2.1 แจ้งเตือนใกล้เต็ม (Warning) - เรียกตอนใกล้ถึงเป้า
  static Future<void> showCalorieWarning(int current, int target) async {
    if (kIsWeb) return;
    await showNotification(
      id: 202,
      title: '⚠️ ใกล้เต็มโควตาแล้วนะ',
      body:
          'เหลืออีกแค่ ${target - current} KCAL มื้อถัดไปเน้นผักหน่อยดีมั้ย? 🥦',
    );
  }

  static Future<void> showNutritionSafetyWarning(
    String title,
    String body,
  ) async {
    if (kIsWeb) return;
    await showNotification(
      id: 203,
      title: title,
      body: body,
    );
  }

  static Future<void> showWaterSafetyWarning(
    String title,
    String body,
  ) async {
    if (kIsWeb) return;
    await showNotification(
      id: 204,
      title: title,
      body: body,
    );
  }

  // 3. แจ้งเตือนความคืบหน้า (Progress) - สรุปตอนค่ำ
  static Future<void> scheduleDailyRecap() async {
    if (kIsWeb) return;
    await scheduleDailyNotification(
        id: 301,
        title: '🌙 สรุปผลวันนี้',
        body: 'มาดูกันว่าวันนี้คุณทำได้ตามเป้าหมายหรือไม่?',
        hour: 21,
        minute: 00);
  }

  // 4. แจ้งเตือนปลุกใจ (Motivation) - ตอนเช้า
  static Future<void> scheduleMorningMotivation() async {
    if (kIsWeb) return;
    await scheduleDailyNotification(
        id: 401,
        title: '🔥 เช้าวันใหม่ สดใสกว่าเดิม',
        body: 'วินัยเริ่มต้นที่ตัวเรา วันนี้สู้ๆ นะครับ!',
        hour: 07,
        minute: 00);
  }

  static Future<void> scheduleWaterReminders() async {
    if (kIsWeb) return;
    // เตือนตอน 10:00, 14:00, 16:00, 20:00
    final times = [10, 14, 16, 20];
    for (int i = 0; i < times.length; i++) {
      await scheduleDailyNotification(
        id: 500 + i, // ID เริ่มที่ 500
        title: '💧 จิบน้ำหน่อยมั้ย?',
        body: 'ดื่มน้ำเพื่อสุขภาพผิวและการเผาผลาญที่ดีนะครับ',
        hour: times[i],
        minute: 0,
      );
    }
  }

  // 6. ⚖️ เตือนชั่งน้ำหนัก (ทุกวันจันทร์ 7 โมงเช้า)
  static Future<void> scheduleWeeklyWeightCheck() async {
    if (kIsWeb) return;
    await _notification.zonedSchedule(
      601, // ID
      '⚖️ ได้เวลาชั่งน้ำหนักแล้ว',
      'เช้าวันจันทร์แบบนี้ มาอัปเดตน้ำหนักล่าสุดกันเถอะ!',
      _nextInstanceOfMondaySevenAM(),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_id_weekly',
          'Weekly Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          DateTimeComponents.dayOfWeekAndTime, // ✅ เตือนซ้ำทุกสัปดาห์
    );
  }

  // Helper: หาเวลา 7 โมงเช้าวันจันทร์ถัดไป
  static tz.TZDateTime _nextInstanceOfMondaySevenAM() {
    tz.TZDateTime scheduledDate =
        _nextInstanceOfTime(7, 0); // เอา 7 โมงวันนี้มาก่อน
    while (scheduledDate.weekday != DateTime.monday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  // ═══════════════════════════════════════════════════════
  // Lifecycle Notifications — weight/birthday/monthly
  // ═══════════════════════════════════════════════════════

  /// แจ้งเตือนน้ำหนักทุก 2 สัปดาห์ (เรียกหลังจาก lifecycle_check API)
  static Future<void> showWeightReminderIfOverdue({
    required bool overdue,
    required int? daysSince,
  }) async {
    if (kIsWeb) return;
    if (!overdue) return;
    final since = daysSince != null ? ' (ผ่านมา $daysSince วันแล้ว)' : '';
    await showNotification(
      id: 602,
      title: '⚖️ อัปเดตน้ำหนักด้วยนะ!',
      body:
          'ยังไม่ได้บันทึกน้ำหนักเลย$since ชั่งแล้วมาบันทึกเพื่อติดตามความก้าวหน้ากันเถอะ 💪',
    );
  }

  /// แจ้งเตือนวันเกิด + แจ้งว่า TDEE จะถูกคำนวณใหม่
  static Future<void> showBirthdayAndTdeeUpdate({
    required bool isBirthday,
    required bool tdeeNeedsUpdate,
    required int? newTargetCalories,
  }) async {
    if (kIsWeb) return;
    if (isBirthday) {
      await showNotification(
        id: 701,
        title: '🎂 สุขสันต์วันเกิด!',
        body: 'ขอให้มีสุขภาพดีตลอดปีนะ!'
            '${newTargetCalories != null ? " เราได้อัปเดตโควตาแคลอรี่เป็น $newTargetCalories kcal/วัน" : ""}',
      );
    } else if (tdeeNeedsUpdate && newTargetCalories != null) {
      await showNotification(
        id: 702,
        title: '🔄 อัปเดตเป้าหมายแล้ว',
        body:
            'คำนวณแคลอรี่ใหม่ตามอายุปีนี้ — โควตาใหม่: $newTargetCalories kcal/วัน',
      );
    }
  }

  /// แจ้งเตือนสรุปรายเดือน (ครบ 30 วัน / ทุก 30 วัน)
  static Future<void> showMonthlySummary({
    required bool trigger,
    required int? goalDaysLeft,
    required bool? onTrack,
  }) async {
    if (kIsWeb) return;
    if (!trigger) return;
    String body;
    if (onTrack == true) {
      body =
          'คุณอยู่ในเส้นทางที่ถูกต้อง! เหลืออีก ${goalDaysLeft ?? "?"} วันถึงเป้าหมาย 🎯';
    } else if (onTrack == false) {
      body =
          'ต้องปรับแผนนิดนึงนะ เหลือ ${goalDaysLeft ?? "?"} วัน ลองดูรายงานความก้าวหน้าดู';
    } else {
      body = 'ผ่านมา 1 เดือนแล้ว มาดูว่าคุณทำได้ดีแค่ไหน!';
    }
    await showNotification(
      id: 801,
      title: '📊 สรุปความก้าวหน้ารายเดือน',
      body: body,
    );
  }
}
