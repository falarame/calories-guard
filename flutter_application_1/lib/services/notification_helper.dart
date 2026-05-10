import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, ValueNotifier;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationHelper {
  static final _notification = FlutterLocalNotificationsPlugin();

  // Deep-link payload ที่รอ handle — MainScreen listen แล้วเปลี่ยน tab
  static final pendingPayload = ValueNotifier<String?>(null);

  static const _prefKeyEnabled = 'notifications_enabled';

  // ─── Persistence ─────────────────────────────────────────────────────────

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyEnabled) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyEnabled, value);
  }

  // ─── Init ──────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (kIsWeb) return;
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notification.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          pendingPayload.value = payload;
        }
      },
    );

    // ── Handle notification that launched the app from killed state ──────────
    final launchDetails = await _notification.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        pendingPayload.value = payload;
      }
    }

    await requestPermission();
  }

  static Future<void> requestPermission() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImpl = _notification.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
    }
  }

  // ─── Schedule / Cancel all ────────────────────────────────────────────────

  /// เรียกตอน toggle ON — reschedule ทุก recurring notifications
  static Future<void> scheduleAll() async {
    if (kIsWeb) return;
    await scheduleMealReminders();
    await scheduleWaterReminders();
    await scheduleMorningMotivation();
    await scheduleDailyRecap();
    await scheduleWeeklyWeightCheck();
  }

  /// เรียกตอน toggle OFF — ยกเลิกเฉพาะ scheduled (ไม่ยกเลิก immediate alerts)
  static Future<void> cancelAllScheduled() async {
    if (kIsWeb) return;
    const scheduledIds = [
      101, 102, 103, // meal reminders
      301, // daily recap
      401, // morning motivation
      500, 501, 502, 503, // water reminders
      601, // weekly weight
      901, 902, // re-engagement guard
      1001, // streak warning
    ];
    for (final id in scheduledIds) {
      await _notification.cancel(id);
    }
  }

  // ─── Immediate Notifications ───────────────────────────────────────────────

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await _notification.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_id_alert',
          'Alert Notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  // ─── Scheduled Notifications ───────────────────────────────────────────────

  static Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
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
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // ─── Recurring Reminder Sets ───────────────────────────────────────────────

  static Future<void> scheduleMealReminders() async {
    if (kIsWeb) return;
    await scheduleDailyNotification(
      id: 101,
      title: '🍳 มื้อเช้าสำคัญนะ!',
      body: 'อย่าลืมบันทึกอาหารเช้าลง CaloriesGuard นะครับ',
      hour: 8, minute: 0,
      payload: 'record_food',
    );
    await scheduleDailyNotification(
      id: 102,
      title: '🍱 เที่ยงแล้ว กินไรยัง?',
      body: 'ทานมื้อเที่ยงแล้วมาจดบันทึกกันเถอะ',
      hour: 12, minute: 0,
      payload: 'record_food',
    );
    await scheduleDailyNotification(
      id: 103,
      title: '🥗 มื้อเย็นเบาๆ กันเถอะ',
      body: 'จบวันแล้ว สรุปยอดแคลอรี่กันหน่อย',
      hour: 18, minute: 0,
      payload: 'record_food',
    );
  }

  static Future<void> scheduleDailyRecap() async {
    if (kIsWeb) return;
    await scheduleDailyNotification(
      id: 301,
      title: '🌙 สรุปผลวันนี้',
      body: 'มาดูกันว่าวันนี้คุณทำได้ตามเป้าหมายหรือไม่?',
      hour: 21, minute: 0,
      payload: 'home',
    );
  }

  static Future<void> scheduleMorningMotivation() async {
    if (kIsWeb) return;
    await scheduleDailyNotification(
      id: 401,
      title: '🔥 เช้าวันใหม่ สดใสกว่าเดิม',
      body: 'วินัยเริ่มต้นที่ตัวเรา วันนี้สู้ๆ นะครับ!',
      hour: 7, minute: 0,
      payload: 'home',
    );
  }

  static Future<void> scheduleWaterReminders() async {
    if (kIsWeb) return;
    final times = [10, 14, 16, 20];
    for (int i = 0; i < times.length; i++) {
      await scheduleDailyNotification(
        id: 500 + i,
        title: '💧 จิบน้ำหน่อยมั้ย?',
        body: 'ดื่มน้ำเพื่อสุขภาพผิวและการเผาผลาญที่ดีนะครับ',
        hour: times[i], minute: 0,
        payload: 'record_food',
      );
    }
  }

  static Future<void> scheduleWeeklyWeightCheck() async {
    if (kIsWeb) return;
    await _notification.zonedSchedule(
      601,
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
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: 'weight',
    );
  }

  static tz.TZDateTime _nextInstanceOfMondaySevenAM() {
    tz.TZDateTime scheduled = _nextInstanceOfTime(7, 0);
    while (scheduled.weekday != DateTime.monday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // ─── P1: Re-engagement Guard ───────────────────────────────────────────────
  // เรียกทุกครั้งที่ผู้ใช้เปิดแอป — reset timer ไปข้างหน้า 2/5 วัน
  // ถ้า user เปิดแอปก่อน 2 วัน notifications จะถูกยกเลิกและตั้งเวลาใหม่

  static Future<void> scheduleReEngagementGuard() async {
    if (kIsWeb) return;
    await _notification.cancel(901);
    await _notification.cancel(902);

    final now = tz.TZDateTime.now(tz.local);

    await _notification.zonedSchedule(
      901,
      '😔 เราคิดถึงคุณนะ!',
      'ผ่านมา 2 วันแล้วที่ไม่ได้บันทึกอาหาร มาเช็กความคืบหน้ากันดีกว่า 💪',
      now.add(const Duration(days: 2)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_id_reengagement',
          'Re-engagement',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'record_food',
    );

    await _notification.zonedSchedule(
      902,
      '🔥 Streak ของคุณกำลังจะหาย!',
      'ผ่านมา 5 วันแล้วที่ไม่ได้บันทึก อย่าปล่อยให้ความพยายามสูญเปล่านะ',
      now.add(const Duration(days: 5)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_id_reengagement',
          'Re-engagement',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'record_food',
    );
  }

  // ─── P3: Streak Warning ────────────────────────────────────────────────────
  // เรียกตอนเช้าเพื่อเตือนตอน 20:00 ถ้ายังไม่ได้บันทึกวันนี้
  // cancel ทิ้งตอนที่ user บันทึกอาหารสำเร็จ

  static Future<void> scheduleStreakWarning(int currentStreak) async {
    if (kIsWeb || currentStreak < 2) return;
    await _notification.cancel(1001);
    await _notification.zonedSchedule(
      1001,
      '🔥 Streak $currentStreak วันของคุณกำลังจะหาย!',
      'บันทึกอาหารวันนี้ก่อน 4 ทุ่มเพื่อรักษา streak ไว้นะ',
      _nextInstanceOfTime(20, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_id_streak',
          'Streak Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'record_food',
    );
  }

  static Future<void> cancelStreakWarning() async {
    await _notification.cancel(1001);
  }

  // ─── Calorie / Nutrition Alerts ────────────────────────────────────────────

  static Future<void> showCalorieAlert(int current, int target) async {
    if (kIsWeb) return;
    await showNotification(
      id: 201,
      title: '🚨 พลังงานเกินเป้าหมายแล้ว!',
      body: 'คุณทานไป $current / $target KCAL แนะนำให้ขยับร่างกายเพิ่มหน่อยนะครับ',
      payload: 'home',
    );
  }

  static Future<void> showCalorieWarning(int current, int target) async {
    if (kIsWeb) return;
    await showNotification(
      id: 202,
      title: '⚠️ ใกล้เต็มโควตาแล้วนะ',
      body: 'เหลืออีกแค่ ${target - current} KCAL มื้อถัดไปเน้นผักหน่อยดีมั้ย? 🥦',
      payload: 'home',
    );
  }

  static Future<void> showNutritionSafetyWarning(String title, String body) async {
    if (kIsWeb) return;
    await showNotification(id: 203, title: title, body: body, payload: 'home');
  }

  static Future<void> showWaterSafetyWarning(String title, String body) async {
    if (kIsWeb) return;
    await showNotification(id: 204, title: title, body: body, payload: 'record_food');
  }

  // ─── Lifecycle Notifications ───────────────────────────────────────────────

  static Future<void> showWeightReminderIfOverdue({
    required bool overdue,
    required int? daysSince,
  }) async {
    if (kIsWeb || !overdue) return;
    final since = daysSince != null ? ' (ผ่านมา $daysSince วันแล้ว)' : '';
    await showNotification(
      id: 602,
      title: '⚖️ อัปเดตน้ำหนักด้วยนะ!',
      body: 'ยังไม่ได้บันทึกน้ำหนักเลย$since ชั่งแล้วมาบันทึกเพื่อติดตามความก้าวหน้ากันเถอะ 💪',
      payload: 'weight',
    );
  }

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
        payload: 'home',
      );
    } else if (tdeeNeedsUpdate && newTargetCalories != null) {
      await showNotification(
        id: 702,
        title: '🔄 อัปเดตเป้าหมายแล้ว',
        body: 'คำนวณแคลอรี่ใหม่ตามอายุปีนี้ — โควตาใหม่: $newTargetCalories kcal/วัน',
        payload: 'home',
      );
    }
  }

  static Future<void> showMonthlySummary({
    required bool trigger,
    required int? goalDaysLeft,
    required bool? onTrack,
  }) async {
    if (kIsWeb || !trigger) return;
    String body;
    if (onTrack == true) {
      body = 'คุณอยู่ในเส้นทางที่ถูกต้อง! เหลืออีก ${goalDaysLeft ?? "?"} วันถึงเป้าหมาย 🎯';
    } else if (onTrack == false) {
      body = 'ต้องปรับแผนนิดนึงนะ เหลือ ${goalDaysLeft ?? "?"} วัน ลองดูรายงานความก้าวหน้าดู';
    } else {
      body = 'ผ่านมา 1 เดือนแล้ว มาดูว่าคุณทำได้ดีแค่ไหน!';
    }
    await showNotification(
      id: 801,
      title: '📊 สรุปความก้าวหน้ารายเดือน',
      body: body,
      payload: 'progress',
    );
  }
}
