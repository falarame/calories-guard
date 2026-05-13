import 'dart:math' as math;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, ValueNotifier, debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'error_reporter.dart';
import 'fcm_service.dart';
import 'streak_service.dart';

// ── Category ──────────────────────────────────────────────────────────────────

/// Granular notification categories for per-user preference control.
enum NotificationCategory {
  meal,
  water,
  motivation,
  recap,
  weight,
  streak,
  reEngagement,
}

// ── NotificationHelper ────────────────────────────────────────────────────────

class NotificationHelper {
  static final _notification = FlutterLocalNotificationsPlugin();
  static final _rng = math.Random();

  /// Deep-link payload waiting to be handled by the navigator.
  static final pendingPayload = ValueNotifier<String?>(null);

  // ── Pref keys ──────────────────────────────────────────────────────────────
  static const _prefKeyEnabled = 'notifications_enabled';
  static const _prefKeyWeighInDay = 'weigh_in_weekday';
  static const _prefKeyPermissionDenied = 'notification_permission_denied';

  // Quiet hours (stored as minutes since midnight, 0–1439)
  static const _prefKeyQuietEnabled = 'quiet_hours_enabled';
  static const _prefKeyQuietStartMin = 'quiet_hours_start_min'; // default 1320 (22:00)
  static const _prefKeyQuietEndMin = 'quiet_hours_end_min'; // default 420 (07:00)

  // Custom meal times (stored as hour*100 + minute)
  static const _prefKeyBreakfastHm = 'meal_breakfast_hm'; // default 800
  static const _prefKeyLunchHm = 'meal_lunch_hm'; // default 1200
  static const _prefKeyDinnerHm = 'meal_dinner_hm'; // default 1800

  // Custom water times (comma-separated hours, e.g. "10,14,16,20")
  static const _prefKeyWaterTimesHH = 'water_times_hh';

  // Per-category toggles
  static String _catKey(NotificationCategory cat) => 'notif_cat_${cat.name}';

  // Rate-limiting: last-shown timestamp per notification id
  static String _lastShownKey(int id) => 'notif_last_$id';

  // ── Category prefs ─────────────────────────────────────────────────────────

  static Future<bool> isCategoryEnabled(NotificationCategory cat) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_catKey(cat)) ?? true;
  }

  static Future<void> setCategoryEnabled(
      NotificationCategory cat, bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_catKey(cat), val);
    if (!val) {
      await _cancelCategory(cat);
    } else {
      if (await isEnabled()) {
        await _scheduleCategory(cat);
      }
    }
  }

  // ── Quiet hours ────────────────────────────────────────────────────────────

  static Future<bool> isQuietHoursEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyQuietEnabled) ?? false;
  }

  static Future<void> setQuietHoursEnabled(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyQuietEnabled, val);
  }

  static Future<int> getQuietHoursStartMin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefKeyQuietStartMin) ?? 1320; // 22:00
  }

  static Future<int> getQuietHoursEndMin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefKeyQuietEndMin) ?? 420; // 07:00
  }

  static Future<void> setQuietHours(
      {required int startMin, required int endMin}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyQuietStartMin, startMin);
    await prefs.setInt(_prefKeyQuietEndMin, endMin);
  }

  /// Returns true if [now] falls within the quiet period.
  /// Handles wrap-around midnight (e.g. 22:00 → 07:00).
  static bool _isInQuietHours(DateTime now, int startMin, int endMin) {
    final nowMin = now.hour * 60 + now.minute;
    if (startMin <= endMin) {
      return nowMin >= startMin && nowMin < endMin;
    } else {
      // Wrap-around (e.g. 22:00 → 07:00)
      return nowMin >= startMin || nowMin < endMin;
    }
  }

  /// Calculates the next datetime when quiet hours end.
  static tz.TZDateTime _nextQuietEnd(int endMin) {
    final now = tz.TZDateTime.now(tz.local);
    final endH = endMin ~/ 60;
    final endM = endMin % 60;
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, endH, endM);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  // ── Custom meal times ──────────────────────────────────────────────────────

  static Future<int> getBreakfastHm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefKeyBreakfastHm) ?? 800;
  }

  static Future<int> getLunchHm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefKeyLunchHm) ?? 1200;
  }

  static Future<int> getDinnerHm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefKeyDinnerHm) ?? 1800;
  }

  static Future<void> setBreakfastHm(int hm) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyBreakfastHm, hm);
  }

  static Future<void> setLunchHm(int hm) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyLunchHm, hm);
  }

  static Future<void> setDinnerHm(int hm) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyDinnerHm, hm);
  }

  // ── Custom water times ─────────────────────────────────────────────────────

  static Future<List<int>> getWaterTimesHH() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKeyWaterTimesHH) ?? '10,14,16,20';
    return raw
        .split(',')
        .map((s) => int.tryParse(s.trim()) ?? -1)
        .where((h) => h >= 0 && h < 24)
        .toList();
  }

  static Future<void> setWaterTimesHH(List<int> hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyWaterTimesHH, hours.join(','));
  }

  // ── Master toggle ──────────────────────────────────────────────────────────

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyEnabled) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyEnabled, value);
  }

  static Future<int> getWeighInDay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefKeyWeighInDay) ?? DateTime.monday;
  }

  static Future<void> setWeighInDay(int weekday) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyWeighInDay, weekday);
  }

  static Future<bool> isPermissionDenied() async {
    if (kIsWeb) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyPermissionDenied) ?? false;
  }

  // ── Rate limiting (Tier 3.5) ───────────────────────────────────────────────

  /// Returns false if this notification was shown within the last hour.
  /// Critical alert id 201 always bypasses this check.
  static Future<bool> _shouldShow(int id) async {
    if (id == 201) return true;
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_lastShownKey(id)) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - lastMs < 3600 * 1000) return false;
    await prefs.setInt(_lastShownKey(id), nowMs);
    return true;
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  static Future<void> init() async {
    if (kIsWeb) return;
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Register iOS categories with action buttons (Tier 3.3)
    final iosSettings = DarwinInitializationSettings(
      notificationCategories: [
        DarwinNotificationCategory(
          'MEAL_REMINDER',
          actions: [
            DarwinNotificationAction.plain('snooze_30m', 'เลื่อน 30 นาที'),
            DarwinNotificationAction.plain(
              'log_now',
              'บันทึกเลย',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
        DarwinNotificationCategory(
          'WATER_REMINDER',
          actions: [
            DarwinNotificationAction.plain('water_logged', 'ดื่มแล้ว ✓'),
            DarwinNotificationAction.plain('snooze_30m', 'เลื่อน'),
          ],
        ),
        DarwinNotificationCategory(
          'STREAK_WARNING',
          actions: [
            DarwinNotificationAction.plain(
              'log_now',
              'บันทึกเลย',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
      ],
    );

    final settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notification.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Handle notification that launched the app from killed state
    final launchDetails =
        await _notification.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails?.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        pendingPayload.value = payload;
        ErrorReporter.event('notification.tapped', data: {
          'id': launchDetails!.notificationResponse!.id,
          'payload': payload,
          'source': 'launch',
        });
      }
    }

    await requestPermission();
  }

  // ── Notification response handler (Tier 3.3) ──────────────────────────────

  static void _onNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId;
    final payload = response.payload;
    final notifId = response.id ?? 0;

    if (actionId == 'log_now') {
      pendingPayload.value = 'record_food';
      ErrorReporter.event('notification.action.log_now',
          data: {'id': notifId});
    } else if (actionId == 'snooze_30m') {
      _snooze30min(notifId, payload);
      ErrorReporter.event('notification.action.snooze',
          data: {'id': notifId});
    } else if (actionId == 'water_logged') {
      _notification.cancel(notifId);
      ErrorReporter.event('notification.action.water_logged',
          data: {'id': notifId});
    } else {
      // Normal tap
      if (payload != null && payload.isNotEmpty) {
        pendingPayload.value = payload;
      }
      ErrorReporter.event('notification.tapped', data: {
        'id': notifId,
        'payload': payload,
      });
    }
  }

  static Future<void> _snooze30min(int id, String? payload) async {
    if (kIsWeb) return;
    final snoozeTime =
        tz.TZDateTime.now(tz.local).add(const Duration(minutes: 30));
    await _notification.zonedSchedule(
      id,
      '🔔 เตือนอีกครั้ง',
      'แตะเพื่อบันทึก',
      snoozeTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_id_snooze',
          'Snoozed Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  static Future<void> requestPermission() async {
    if (kIsWeb) return;
    bool? granted;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImpl = _notification
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      granted = await androidImpl?.requestNotificationsPermission();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosImpl = _notification
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      granted = await iosImpl?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    if (granted == false) {
      await prefs.setBool(_prefKeyPermissionDenied, true);
      ErrorReporter.event('notification.permission.denied',
          data: {'platform': defaultTargetPlatform.name});
    } else if (granted == true) {
      await prefs.remove(_prefKeyPermissionDenied);
    }
  }

  // ── Schedule / Cancel all ─────────────────────────────────────────────────

  /// Reschedule all recurring notifications, gating each on its category.
  static Future<void> scheduleAll() async {
    if (kIsWeb) return;
    if (await isCategoryEnabled(NotificationCategory.meal)) {
      await scheduleMealReminders();
    }
    if (await isCategoryEnabled(NotificationCategory.water)) {
      await scheduleWaterReminders();
    }
    if (await isCategoryEnabled(NotificationCategory.motivation)) {
      await scheduleMorningMotivation();
    }
    if (await isCategoryEnabled(NotificationCategory.recap)) {
      await scheduleDailyRecap();
    }
    if (await isCategoryEnabled(NotificationCategory.weight)) {
      await scheduleWeeklyWeightCheck();
    }
    // streak and reEngagement are scheduled on-demand
  }

  static Future<void> _scheduleCategory(NotificationCategory cat) async {
    switch (cat) {
      case NotificationCategory.meal:
        await scheduleMealReminders();
      case NotificationCategory.water:
        await scheduleWaterReminders();
      case NotificationCategory.motivation:
        await scheduleMorningMotivation();
      case NotificationCategory.recap:
        await scheduleDailyRecap();
      case NotificationCategory.weight:
        await scheduleWeeklyWeightCheck();
      case NotificationCategory.streak:
        break; // scheduled by StreakService on demand
      case NotificationCategory.reEngagement:
        await scheduleReEngagementGuard();
    }
  }

  static Future<void> _cancelCategory(NotificationCategory cat) async {
    switch (cat) {
      case NotificationCategory.meal:
        for (final id in [101, 102, 103]) {
          await _notification.cancel(id);
        }
      case NotificationCategory.water:
        for (int i = 0; i < 8; i++) {
          await _notification.cancel(500 + i);
        }
      case NotificationCategory.motivation:
        await _notification.cancel(401);
      case NotificationCategory.recap:
        await _notification.cancel(301);
      case NotificationCategory.weight:
        await _notification.cancel(601);
      case NotificationCategory.streak:
        await _notification.cancel(1001);
      case NotificationCategory.reEngagement:
        await _notification.cancel(901);
        await _notification.cancel(902);
    }
  }

  /// Cancel every scheduled notification (used when master toggle is OFF).
  static Future<void> cancelAllScheduled() async {
    if (kIsWeb) return;
    const scheduledIds = [
      101, 102, 103, // meal
      301, // recap
      401, // motivation
      500, 501, 502, 503, 504, 505, 506, 507, // water (up to 8 slots)
      601, // weight
      901, 902, // re-engagement
      1001, // streak warning
    ];
    for (final id in scheduledIds) {
      await _notification.cancel(id);
    }
  }

  /// Full cleanup on logout / account delete.
  static Future<void> signOutCleanup(int userId) async {
    if (kIsWeb) return;
    await cancelAllScheduled();
    await FcmService.clearToken(userId);
    await StreakService.clear();
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _prefKeyEnabled,
      _prefKeyWeighInDay,
      _prefKeyPermissionDenied,
      _prefKeyQuietEnabled,
      _prefKeyQuietStartMin,
      _prefKeyQuietEndMin,
      _prefKeyBreakfastHm,
      _prefKeyLunchHm,
      _prefKeyDinnerHm,
      _prefKeyWaterTimesHH,
    ]) {
      await prefs.remove(key);
    }
    for (final cat in NotificationCategory.values) {
      await prefs.remove(_catKey(cat));
    }
  }

  // ── Smart suppression (Tier 2.4) ──────────────────────────────────────────

  /// Cancel today's meal reminder for [mealType] and reschedule it for
  /// the same time tomorrow — called when the user has already logged that meal.
  static Future<void> suppressTodayMealReminder(String mealType) async {
    if (kIsWeb) return;
    if (!await isEnabled()) return;
    if (!await isCategoryEnabled(NotificationCategory.meal)) return;

    final int id;
    switch (mealType) {
      case 'breakfast':
        id = 101;
      case 'lunch':
        id = 102;
      case 'dinner':
        id = 103;
      default:
        return;
    }

    await _notification.cancel(id);

    final prefs = await SharedPreferences.getInstance();
    final prefKey = mealType == 'breakfast'
        ? _prefKeyBreakfastHm
        : mealType == 'lunch'
            ? _prefKeyLunchHm
            : _prefKeyDinnerHm;
    final defaultHm = mealType == 'breakfast'
        ? 800
        : mealType == 'lunch'
            ? 1200
            : 1800;
    final hm = prefs.getInt(prefKey) ?? defaultHm;
    final hour = hm ~/ 100;
    final minute = hm % 100;

    final now = tz.TZDateTime.now(tz.local);
    var tomorrowTime = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    tomorrowTime = tomorrowTime.add(const Duration(days: 1));

    // Shift out of quiet hours if needed
    if (await isQuietHoursEnabled()) {
      final startMin = await getQuietHoursStartMin();
      final endMin = await getQuietHoursEndMin();
      if (_isInQuietHours(tomorrowTime.toLocal(), startMin, endMin)) {
        final quietEnd = _nextQuietEnd(endMin);
        tomorrowTime =
            quietEnd.isAfter(tomorrowTime) ? quietEnd : tomorrowTime;
      }
    }

    final copy = _mealCopy(mealType);
    await _notification.zonedSchedule(
      id,
      copy.$1,
      copy.$2,
      tomorrowTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_id_daily',
          'Daily Reminders',
          importance: Importance.max,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction('snooze_30m', 'เลื่อน 30 นาที'),
            AndroidNotificationAction('log_now', 'บันทึกเลย',
                showsUserInterface: true),
          ],
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: 'MEAL_REMINDER'),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'record_food',
    );
  }

  // ── Copy variation (Tier 4.4) ──────────────────────────────────────────────

  static (String, String) _mealCopy(String type) {
    const breakfast = [
      ('🍳 มื้อเช้าสำคัญนะ!', 'อย่าลืมบันทึกอาหารเช้าลง CaloriesGuard นะครับ'),
      ('☀️ เริ่มวันดีๆ ด้วยมื้อเช้า', 'บันทึกอาหารเช้าเพื่อเริ่มนับแคลอรี่วันนี้ได้เลย'),
      ('🥐 เช้าแล้ว อย่าลืมกิน!', 'มื้อเช้าช่วยเพิ่มพลังงานสำหรับวันใหม่ บันทึกเลย'),
    ];
    const lunch = [
      ('🍱 เที่ยงแล้ว กินไรยัง?', 'ทานมื้อเที่ยงแล้วมาจดบันทึกกันเถอะ'),
      ('🌞 มื้อกลางวันถึงแล้ว', 'อย่าลืมบันทึกอาหารเที่ยงเพื่อติดตามแคลอรี่'),
      ('🍜 ถึงเวลากินข้าวกลางวัน', 'จดบันทึกมื้อเที่ยงเพื่อรักษาเป้าหมาย'),
    ];
    const dinner = [
      ('🥗 มื้อเย็นเบาๆ กันเถอะ', 'จบวันแล้ว สรุปยอดแคลอรี่กันหน่อย'),
      ('🌙 ค่ำแล้ว บันทึกมื้อเย็น', 'อย่าลืมจดบันทึกอาหารเย็นก่อนนอน'),
      ('🍽️ มื้อสุดท้ายของวัน', 'บันทึกมื้อเย็นเพื่อดูสรุปแคลอรี่วันนี้'),
    ];
    final pool = type == 'breakfast'
        ? breakfast
        : type == 'lunch'
            ? lunch
            : dinner;
    return pool[_rng.nextInt(pool.length)];
  }

  static (String, String) _waterCopy() {
    const variants = [
      ('💧 จิบน้ำหน่อยมั้ย?',
          'ดื่มน้ำเพื่อสุขภาพผิวและการเผาผลาญที่ดีนะครับ'),
      ('🥤 ได้เวลาดื่มน้ำ!',
          'ดื่มน้ำอย่างน้อย 8 แก้วต่อวันช่วยให้ร่างกายสดชื่น'),
      ('💦 อย่าลืมดื่มน้ำ', 'น้ำช่วยเพิ่มประสิทธิภาพการเผาผลาญ ดื่มเลย!'),
    ];
    return variants[_rng.nextInt(variants.length)];
  }

  static (String, String) _motivationCopy() {
    const variants = [
      ('🔥 เช้าวันใหม่ สดใสกว่าเดิม',
          'วินัยเริ่มต้นที่ตัวเรา วันนี้สู้ๆ นะครับ!'),
      ('💪 วันใหม่ พลังใหม่',
          'เป้าหมายรอคุณอยู่ เริ่มวันนี้ให้ดีที่สุด'),
      ('⚡ ตื่นเช้า ร่างกายพร้อม',
          'วันนี้เป็นวันที่ดี เริ่มบันทึกอาหารตั้งแต่มื้อแรก'),
    ];
    return variants[_rng.nextInt(variants.length)];
  }

  // ── showNotification (with quiet hours + rate limiting) ───────────────────

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool bypassQuiet = false,
    bool bypassRateLimit = false,
  }) async {
    if (kIsWeb) return;

    // Rate limiting (skip for id 201 — critical calorie alert)
    if (!bypassRateLimit) {
      if (!await _shouldShow(id)) {
        debugPrint('[notif] rate-limited id=$id');
        return;
      }
    }

    // Quiet hours: defer non-critical notifications to quiet-hours end
    if (!bypassQuiet && id != 201 && await isQuietHoursEnabled()) {
      final now = DateTime.now();
      final startMin = await getQuietHoursStartMin();
      final endMin = await getQuietHoursEndMin();
      if (_isInQuietHours(now, startMin, endMin)) {
        await _notification.zonedSchedule(
          id,
          title,
          body,
          _nextQuietEnd(endMin),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'channel_id_alert',
              'Alert Notifications',
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
        ErrorReporter.event('notification.suppressed.quietHours',
            data: {'id': id, 'title': title});
        return;
      }
    }

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
    ErrorReporter.event('notification.shown',
        data: {'id': id, 'title': title});
  }

  // ── Scheduled notification base ────────────────────────────────────────────

  static Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
    List<AndroidNotificationAction>? androidActions,
    String? iosCategoryId,
  }) async {
    if (kIsWeb) return;

    var scheduledTime = _nextInstanceOfTime(hour, minute);

    // Shift out of quiet hours
    if (await isQuietHoursEnabled()) {
      final startMin = await getQuietHoursStartMin();
      final endMin = await getQuietHoursEndMin();
      if (_isInQuietHours(scheduledTime.toLocal(), startMin, endMin)) {
        scheduledTime = _nextQuietEnd(endMin);
      }
    }

    await _notification.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_id_daily',
          'Daily Reminders',
          importance: Importance.max,
          priority: Priority.high,
          actions: androidActions,
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: iosCategoryId),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
    ErrorReporter.event('notification.scheduled', data: {
      'id': id,
      'scheduledFor': scheduledTime.toIso8601String(),
    });
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // ── Meal reminders (Tier 2.3 custom times + Tier 3.3 actions + Tier 4.4 copy) ─

  static Future<void> scheduleMealReminders() async {
    if (kIsWeb) return;
    const actions = [
      AndroidNotificationAction('snooze_30m', 'เลื่อน 30 นาที'),
      AndroidNotificationAction('log_now', 'บันทึกเลย',
          showsUserInterface: true),
    ];

    final breakfastHm = await getBreakfastHm();
    final breakfastCopy = _mealCopy('breakfast');
    await scheduleDailyNotification(
      id: 101,
      title: breakfastCopy.$1,
      body: breakfastCopy.$2,
      hour: breakfastHm ~/ 100,
      minute: breakfastHm % 100,
      payload: 'record_food',
      androidActions: actions,
      iosCategoryId: 'MEAL_REMINDER',
    );

    final lunchHm = await getLunchHm();
    final lunchCopy = _mealCopy('lunch');
    await scheduleDailyNotification(
      id: 102,
      title: lunchCopy.$1,
      body: lunchCopy.$2,
      hour: lunchHm ~/ 100,
      minute: lunchHm % 100,
      payload: 'record_food',
      androidActions: actions,
      iosCategoryId: 'MEAL_REMINDER',
    );

    final dinnerHm = await getDinnerHm();
    final dinnerCopy = _mealCopy('dinner');
    await scheduleDailyNotification(
      id: 103,
      title: dinnerCopy.$1,
      body: dinnerCopy.$2,
      hour: dinnerHm ~/ 100,
      minute: dinnerHm % 100,
      payload: 'record_food',
      androidActions: actions,
      iosCategoryId: 'MEAL_REMINDER',
    );
  }

  static Future<void> scheduleDailyRecap() async {
    if (kIsWeb) return;
    await scheduleDailyNotification(
      id: 301,
      title: '🌙 สรุปผลวันนี้',
      body: 'มาดูกันว่าวันนี้คุณทำได้ตามเป้าหมายหรือไม่?',
      hour: 21,
      minute: 0,
      payload: 'home',
    );
  }

  static Future<void> scheduleMorningMotivation() async {
    if (kIsWeb) return;
    final copy = _motivationCopy();
    await scheduleDailyNotification(
      id: 401,
      title: copy.$1,
      body: copy.$2,
      hour: 7,
      minute: 0,
      payload: 'home',
    );
  }

  // ── Water reminders (Tier 2.3 custom + Tier 3.3 actions + Tier 4.4 copy) ──

  static Future<void> scheduleWaterReminders() async {
    if (kIsWeb) return;
    const actions = [
      AndroidNotificationAction('water_logged', 'ดื่มแล้ว ✓'),
      AndroidNotificationAction('snooze_30m', 'เลื่อน'),
    ];

    final times = await getWaterTimesHH();
    for (int i = 0; i < times.length && i < 8; i++) {
      final copy = _waterCopy();
      await scheduleDailyNotification(
        id: 500 + i,
        title: copy.$1,
        body: copy.$2,
        hour: times[i],
        minute: 0,
        payload: 'record_food',
        androidActions: actions,
        iosCategoryId: 'WATER_REMINDER',
      );
    }
    // Cancel any leftover slots from a previous larger schedule
    for (int i = times.length; i < 8; i++) {
      await _notification.cancel(500 + i);
    }
  }

  static Future<void> scheduleWeeklyWeightCheck() async {
    if (kIsWeb) return;
    final weekday = await getWeighInDay();
    final dayName = _thaiWeekdayName(weekday);

    var scheduledTime = _nextInstanceOfWeekdaySevenAM(weekday);
    if (await isQuietHoursEnabled()) {
      final startMin = await getQuietHoursStartMin();
      final endMin = await getQuietHoursEndMin();
      if (_isInQuietHours(scheduledTime.toLocal(), startMin, endMin)) {
        scheduledTime = _nextQuietEnd(endMin);
      }
    }

    await _notification.zonedSchedule(
      601,
      '⚖️ ได้เวลาชั่งน้ำหนักแล้ว',
      '$dayName นี้มาอัปเดตน้ำหนักล่าสุดกันเถอะ!',
      scheduledTime,
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
    ErrorReporter.event('notification.scheduled', data: {
      'id': 601,
      'type': 'weekly_weight',
      'weekday': weekday,
    });
  }

  static tz.TZDateTime _nextInstanceOfWeekdaySevenAM(int weekday) {
    tz.TZDateTime scheduled = _nextInstanceOfTime(7, 0);
    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  static String _thaiWeekdayName(int weekday) {
    const names = {
      DateTime.monday: 'วันจันทร์',
      DateTime.tuesday: 'วันอังคาร',
      DateTime.wednesday: 'วันพุธ',
      DateTime.thursday: 'วันพฤหัสบดี',
      DateTime.friday: 'วันศุกร์',
      DateTime.saturday: 'วันเสาร์',
      DateTime.sunday: 'วันอาทิตย์',
    };
    return names[weekday] ?? 'วันจันทร์';
  }

  // ── Re-engagement guard ────────────────────────────────────────────────────

  static Future<void> scheduleReEngagementGuard() async {
    if (kIsWeb) return;
    if (!await isCategoryEnabled(NotificationCategory.reEngagement)) return;

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
          actions: [
            AndroidNotificationAction('log_now', 'บันทึกเลย',
                showsUserInterface: true),
          ],
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: 'MEAL_REMINDER'),
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
          actions: [
            AndroidNotificationAction('log_now', 'บันทึกเลย',
                showsUserInterface: true),
          ],
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: 'MEAL_REMINDER'),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'record_food',
    );
  }

  // ── Streak warning ────────────────────────────────────────────────────────

  static Future<void> scheduleStreakWarning(int currentStreak) async {
    if (kIsWeb || currentStreak < 2) return;
    if (!await isCategoryEnabled(NotificationCategory.streak)) return;

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
          actions: [
            AndroidNotificationAction('log_now', 'บันทึกเลย',
                showsUserInterface: true),
          ],
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: 'STREAK_WARNING'),
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

  // ── Calorie / Nutrition alerts ─────────────────────────────────────────────

  static Future<void> showCalorieAlert(int current, int target) async {
    if (kIsWeb) return;
    await showNotification(
      id: 201,
      title: '🚨 พลังงานเกินเป้าหมายแล้ว!',
      body: 'คุณทานไป $current / $target KCAL แนะนำให้ขยับร่างกายเพิ่มหน่อยนะครับ',
      payload: 'home',
      bypassQuiet: true,
      bypassRateLimit: true,
    );
  }

  static Future<void> showCalorieWarning(int current, int target) async {
    if (kIsWeb) return;
    await showNotification(
      id: 202,
      title: '⚠️ ใกล้เต็มโควตาแล้วนะ',
      body:
          'เหลืออีกแค่ ${target - current} KCAL มื้อถัดไปเน้นผักหน่อยดีมั้ย? 🥦',
      payload: 'home',
    );
  }

  static Future<void> showNutritionSafetyWarning(
      String title, String body) async {
    if (kIsWeb) return;
    await showNotification(
        id: 203, title: title, body: body, payload: 'home');
  }

  static Future<void> showWaterSafetyWarning(
      String title, String body) async {
    if (kIsWeb) return;
    await showNotification(
        id: 204, title: title, body: body, payload: 'record_food');
  }

  // ── Lifecycle notifications ────────────────────────────────────────────────

  static Future<void> showWeightReminderIfOverdue({
    required bool overdue,
    required int? daysSince,
  }) async {
    if (kIsWeb || !overdue) return;
    final since = daysSince != null ? ' (ผ่านมา $daysSince วันแล้ว)' : '';
    await showNotification(
      id: 602,
      title: '⚖️ อัปเดตน้ำหนักด้วยนะ!',
      body:
          'ยังไม่ได้บันทึกน้ำหนักเลย$since ชั่งแล้วมาบันทึกเพื่อติดตามความก้าวหน้ากันเถอะ 💪',
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
        body:
            'คำนวณแคลอรี่ใหม่ตามอายุปีนี้ — โควตาใหม่: $newTargetCalories kcal/วัน',
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
      payload: 'progress',
    );
  }

  // ── Debug helpers (Tier 4.2) ───────────────────────────────────────────────

  /// Returns all currently pending notification requests (for debug screen).
  static Future<List<PendingNotificationRequest>>
      getPendingRequests() async {
    if (kIsWeb) return [];
    return _notification.pendingNotificationRequests();
  }

  /// Trigger a test notification immediately for the given type.
  static Future<void> triggerTestNotification(String type) async {
    if (kIsWeb) return;
    switch (type) {
      case 'meal':
        await showNotification(
          id: 9901,
          title: '🍳 [Test] มื้อเช้าสำคัญนะ!',
          body: 'นี่คือ test notification',
          payload: 'record_food',
          bypassRateLimit: true,
          bypassQuiet: true,
        );
      case 'water':
        await showNotification(
          id: 9902,
          title: '💧 [Test] จิบน้ำหน่อยมั้ย?',
          body: 'นี่คือ test notification',
          payload: 'record_food',
          bypassRateLimit: true,
          bypassQuiet: true,
        );
      case 'streak':
        await showNotification(
          id: 9903,
          title: '🔥 [Test] Streak ของคุณกำลังจะหาย!',
          body: 'นี่คือ test notification',
          payload: 'record_food',
          bypassRateLimit: true,
          bypassQuiet: true,
        );
      case 'reengagement':
        await showNotification(
          id: 9904,
          title: '😔 [Test] เราคิดถึงคุณนะ!',
          body: 'นี่คือ test notification',
          payload: 'record_food',
          bypassRateLimit: true,
          bypassQuiet: true,
        );
      case 'calorie':
        await showCalorieAlert(2000, 1800);
    }
  }
}
