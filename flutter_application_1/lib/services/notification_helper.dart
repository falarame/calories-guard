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

  // Feature 1: cached macro data written by app_home_screen after daily fetch
  static const _prefKeyCachedMacroDate = 'cached_macro_date';
  static const _prefKeyCachedProteinEaten = 'cached_protein_eaten';
  static const _prefKeyCachedProteinTarget = 'cached_protein_target';
  static const _prefKeyCachedCaloriesEaten = 'cached_calories_eaten';
  static const _prefKeyCachedCaloriesTarget = 'cached_calories_target';

  // Feature 3: smart / adaptive timing keys
  static const _prefKeySmartTimingEnabled = 'smart_timing_enabled';
  static const _prefKeySmartBreakfastHm = 'smart_breakfast_hm';
  static const _prefKeySmartLunchHm = 'smart_lunch_hm';
  static const _prefKeySmartDinnerHm = 'smart_dinner_hm';
  // Throttle daily re-personalisation to once per calendar day
  static const _prefKeyLastPersonalizedDate = 'last_personalized_date';

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
    if (prefs.getBool(_prefKeySmartTimingEnabled) ?? false) {
      final smart = prefs.getInt(_prefKeySmartBreakfastHm);
      if (smart != null && smart > 0) return smart;
    }
    return prefs.getInt(_prefKeyBreakfastHm) ?? 800;
  }

  static Future<int> getLunchHm() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKeySmartTimingEnabled) ?? false) {
      final smart = prefs.getInt(_prefKeySmartLunchHm);
      if (smart != null && smart > 0) return smart;
    }
    return prefs.getInt(_prefKeyLunchHm) ?? 1200;
  }

  static Future<int> getDinnerHm() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKeySmartTimingEnabled) ?? false) {
      final smart = prefs.getInt(_prefKeySmartDinnerHm);
      if (smart != null && smart > 0) return smart;
    }
    return prefs.getInt(_prefKeyDinnerHm) ?? 1800;
  }

  // Feature 3: smart timing toggle
  static Future<bool> isSmartTimingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeySmartTimingEnabled) ?? false;
  }

  static Future<void> setSmartTimingEnabled(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeySmartTimingEnabled, val);
    // Reschedule so new timing takes effect immediately
    if (await isEnabled()) await scheduleMealReminders();
  }

  // Feature 3: read smart suggestion times (for display in settings)
  static Future<Map<String, int>> getSmartSuggestedTimes() async {
    final prefs = await SharedPreferences.getInstance();
    final result = <String, int>{};
    final bf = prefs.getInt(_prefKeySmartBreakfastHm);
    final ln = prefs.getInt(_prefKeySmartLunchHm);
    final dn = prefs.getInt(_prefKeySmartDinnerHm);
    if (bf != null && bf > 0) result['breakfast'] = bf;
    if (ln != null && ln > 0) result['lunch'] = ln;
    if (dn != null && dn > 0) result['dinner'] = dn;
    return result;
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

  // ── Feature 2: meal type from notification ID ──────────────────────────────

  static String _mealTypeFromNotifId(int id) {
    switch (id) {
      case 101:
        return 'breakfast';
      case 102:
        return 'lunch';
      case 103:
        return 'dinner';
      default:
        return 'breakfast';
    }
  }

  // ── Feature 1: cache macro data (called from app_home_screen) ─────────────

  /// Saves today's eaten/target macros to SharedPreferences so that
  /// [scheduleMealReminders] can generate personalised notification copy.
  static Future<void> cacheHomeMacros({
    required int proteinEaten,
    required int proteinTarget,
    required int caloriesEaten,
    required int caloriesTarget,
  }) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await prefs.setString(_prefKeyCachedMacroDate, todayStr);
    await prefs.setInt(_prefKeyCachedProteinEaten, proteinEaten);
    await prefs.setInt(_prefKeyCachedProteinTarget, proteinTarget);
    await prefs.setInt(_prefKeyCachedCaloriesEaten, caloriesEaten);
    await prefs.setInt(_prefKeyCachedCaloriesTarget, caloriesTarget);
  }

  /// Re-schedule meal reminders with personalised copy once per calendar day.
  static Future<void> reschedulePersonalizedMeals() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if ((prefs.getString(_prefKeyLastPersonalizedDate) ?? '') == todayStr) {
      return; // already personalised today
    }
    if (!await isEnabled()) return;
    if (!await isCategoryEnabled(NotificationCategory.meal)) return;
    await scheduleMealReminders();
    await prefs.setString(_prefKeyLastPersonalizedDate, todayStr);
  }

  /// Returns a personalised (title, body) for dinner/lunch based on today's
  /// cached macro data.  Returns null when data is stale or insufficient.
  static Future<(String, String)?> _personalizedMealCopy(
      String mealType) async {
    if (kIsWeb) return null;
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if ((prefs.getString(_prefKeyCachedMacroDate) ?? '') != todayStr) {
      return null; // stale or missing cache
    }

    final proteinEaten = prefs.getInt(_prefKeyCachedProteinEaten) ?? 0;
    final proteinTarget = prefs.getInt(_prefKeyCachedProteinTarget) ?? 0;
    final calEaten = prefs.getInt(_prefKeyCachedCaloriesEaten) ?? 0;
    final calTarget = prefs.getInt(_prefKeyCachedCaloriesTarget) ?? 0;

    if (calTarget <= 0) return null;

    final proteinDeficit = proteinTarget - proteinEaten;
    final calRemaining = calTarget - calEaten;

    if (mealType == 'dinner') {
      if (proteinDeficit >= 15 && proteinTarget > 0) {
        return (
          '🥩 ขาดโปรตีนอยู่นะ!',
          'วันนี้ยังขาดโปรตีนอีก ${proteinDeficit}g ลองเพิ่มไข่ต้มหรือเนื้อมื้อเย็นด้วยนะ',
        );
      }
      if (calRemaining <= 100 && calEaten > 0) {
        return (
          '✋ เกือบเต็มโควตาแล้ว!',
          'เหลือพื้นที่อีกแค่ ~$calRemaining kcal มื้อเย็นเลือกเบาๆ นะครับ',
        );
      }
      if (calRemaining >= 500 && calEaten > 0) {
        return (
          '🍽️ ยังเหลืออีก $calRemaining kcal',
          'มื้อเย็นนี้ทานให้ครบตามเป้าหมายได้เลย 💪',
        );
      }
    } else if (mealType == 'lunch') {
      if (proteinDeficit >= 25 && proteinTarget > 0) {
        return (
          '🥗 มื้อเที่ยงเพิ่มโปรตีนหน่อยนะ',
          'ขาดโปรตีนอีก ${proteinDeficit}g ลองเพิ่มไข่หรือเนื้อสักอย่าง',
        );
      }
    }
    return null; // no specific insight → fall through to generic copy
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
            DarwinNotificationAction.plain(
              'copy_yesterday',
              'ทานเหมือนเดิม ✓',
            ),
            DarwinNotificationAction.plain(
              'log_now',
              'บันทึกเอง',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain('snooze_30m', 'เลื่อน 30 นาที'),
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

    if (actionId == 'copy_yesterday') {
      // Feature 2: Micro-Interactions — "same as yesterday?"
      final mealType = _mealTypeFromNotifId(notifId);
      pendingPayload.value = 'copy_yesterday:$mealType';
      ErrorReporter.event('notification.action.copy_yesterday',
          data: {'id': notifId, 'mealType': mealType});
    } else if (actionId == 'log_now') {
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
        for (final id in [101, 102, 103, 111, 112, 113]) {
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

  // ── Gap Filling (Notification Hierarchy: Urgent type) ─────────────────────
  // IDs 111/112/113 = gap-fill one-shots (separate from recurring 101/102/103)

  static const _gapIds = {'breakfast': 111, 'lunch': 112, 'dinner': 113};

  // Deadlines (hhmm format) after which gap-fill fires if meal not logged
  static const _gapDeadlines = {
    'breakfast': 930,  // 09:30
    'lunch': 1400,     // 14:00
    'dinner': 2030,    // 20:30
  };

  /// Schedule a one-shot "Urgent" gap-fill notification for [mealType] at the
  /// deadline time — only if the deadline is in the future and no notification
  /// is already pending for that ID.  Cancelled automatically by
  /// [suppressTodayMealReminder] when the user logs the meal.
  static Future<void> scheduleGapFillIfNeeded(String mealType) async {
    if (kIsWeb) return;
    if (!await isEnabled()) return;
    if (!await isCategoryEnabled(NotificationCategory.meal)) return;

    final id = _gapIds[mealType];
    final deadlineHm = _gapDeadlines[mealType];
    if (id == null || deadlineHm == null) return;

    final now = tz.TZDateTime.now(tz.local);
    final deadlineH = deadlineHm ~/ 100;
    final deadlineM = deadlineHm % 100;
    var deadline = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, deadlineH, deadlineM);

    if (!deadline.isAfter(now)) return; // deadline already passed today

    // Shift out of quiet hours
    if (await isQuietHoursEnabled()) {
      final startMin = await getQuietHoursStartMin();
      final endMin = await getQuietHoursEndMin();
      if (_isInQuietHours(deadline.toLocal(), startMin, endMin)) return;
    }

    final (String title, String body) = switch (mealType) {
      'breakfast' => ('🍳 ยังไม่ได้บันทึกมื้อเช้าเลยนะ',
          'กินเช้าแล้วหรือยัง? บันทึกไว้เพื่อเริ่มนับแคลอรี่วันนี้'),
      'lunch' => ('🍱 ยังไม่เห็นมื้อเที่ยงเลยนะ',
          'กินข้าวกลางวันแล้วหรือยัง? บันทึกเร็วๆ นี้เลย'),
      _ => ('🌙 มื้อเย็นยังไม่มีข้อมูลเลยนะ',
          'วันนี้ยังขาดมื้อเย็น บันทึกก่อนนอนเพื่อดูสรุปแคลอรี่ทั้งวัน'),
    };

    await _notification.zonedSchedule(
      id,
      title,
      body,
      deadline,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_id_urgent',
          'Urgent Reminders',
          importance: Importance.max,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction('log_now', 'บันทึกเลย',
                showsUserInterface: true),
            AndroidNotificationAction('copy_yesterday', 'ทานเหมือนเดิม ✓'),
          ],
        ),
        iOS: DarwinNotificationDetails(categoryIdentifier: 'MEAL_REMINDER'),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: 'record_food',
    );
    ErrorReporter.event('notification.gap_fill.scheduled', data: {
      'mealType': mealType,
      'deadline': deadline.toIso8601String(),
    });
  }

  /// Cancel the gap-fill notification for [mealType] (called when meal is logged).
  static Future<void> cancelGapFill(String mealType) async {
    final id = _gapIds[mealType];
    if (id != null) await _notification.cancel(id);
  }

  /// Cancel ALL cancel gap-fill notifications.
  static Future<void> cancelAllGapFills() async {
    for (final id in _gapIds.values) {
      await _notification.cancel(id);
    }
  }

  /// Cancel every scheduled notification (used when master toggle is OFF).
  static Future<void> cancelAllScheduled() async {
    if (kIsWeb) return;
    const scheduledIds = [
      101, 102, 103, // meal (recurring)
      111, 112, 113, // meal gap-fill (one-shot urgent)
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
    await cancelAllScheduled(); // includes gap-fill IDs via cancelAllScheduled
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
      // Feature 1: cached macros
      _prefKeyCachedMacroDate,
      _prefKeyCachedProteinEaten,
      _prefKeyCachedProteinTarget,
      _prefKeyCachedCaloriesEaten,
      _prefKeyCachedCaloriesTarget,
      // Feature 3: smart timing
      _prefKeySmartTimingEnabled,
      _prefKeySmartBreakfastHm,
      _prefKeySmartLunchHm,
      _prefKeySmartDinnerHm,
      _prefKeyLastPersonalizedDate,
      // Celebration dedup
      'goal_celebrated_date',
    ]) {
      await prefs.remove(key);
    }
    for (final cat in NotificationCategory.values) {
      await prefs.remove(_catKey(cat));
    }
    // Tamagotchi V2.1 per-user keys
    for (final key in [
      'tama_gems_$userId',
      'tama_weekly_xp_$userId',
      'tama_weekly_week_$userId',
      'tama_achievements_$userId',
      'tama_last_reward_week_$userId',
      'tama_free_repairs_$userId',
      'tama_shop_repairs_$userId',
      'tama_pending_food_credits_$userId',
      'tama_invitee_count_$userId',
      'streak_freeze_until_$userId',
    ]) {
      await prefs.remove(key);
    }
    // Daily-scoped tama keys (date suffix) — wipe all that match prefix
    final allKeys = prefs.getKeys();
    for (final k in allKeys) {
      if (k.startsWith('tama_claimed_${userId}_') ||
          k.startsWith('tama_perfect_day_${userId}_')) {
        await prefs.remove(k);
      }
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
    await cancelGapFill(mealType); // Gap Filling: cancel urgent one-shot too

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
            AndroidNotificationAction('copy_yesterday', 'ทานเหมือนเดิม ✓'),
            AndroidNotificationAction('log_now', 'บันทึกเอง',
                showsUserInterface: true),
            AndroidNotificationAction('snooze_30m', 'เลื่อน 30 นาที'),
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

  // ── Copy variation — Empathic Tone (Feature 3) ────────────────────────────

  static (String, String) _mealCopy(String type) {
    // Empathic, conversational tone; avoids commands like "อย่าลืม"
    const breakfast = [
      ('☀️ เริ่มวันดีๆ กันเลยนะ', 'กินข้าวเช้าแล้วหรือยัง? จดบันทึกเอาไว้สักหน่อยนะ'),
      ('🍳 มื้อเช้าเป็นยังไงบ้าง?', 'พลังงานดีๆ เริ่มจากมื้อเช้า บันทึกเดี๋ยวนี้เลย'),
      ('🥐 ตื่นมาแล้วต้องกิน!', 'มื้อเช้าช่วยให้สมองตื่นตัวตลอดเช้า บันทึกไว้นะครับ'),
    ];
    const lunch = [
      ('🍱 มื้อเที่ยงวันนี้เป็นไง?', 'พลังงานเพียงพอสำหรับช่วงบ่ายไหม? จดบันทึกเลยนะ'),
      ('🌞 กินข้าวกลางวันแล้วหรือยัง?', 'บันทึกมื้อเที่ยงเพื่อเช็กว่าบ่ายนี้ยังเหลือโควตาอีกแค่ไหน'),
      ('🍜 หิวแล้วใช่ไหม?', 'ทานให้อร่อยนะ แล้วอย่าลืมบันทึกหลังกินเสร็จด้วยล่ะ'),
    ];
    const dinner = [
      ('🌙 วันนี้เป็นยังไงบ้าง?', 'มื้อเย็นเบาๆ ก็โอเคนะ จดบันทึกก่อนพักผ่อนสักหน่อย'),
      ('🥗 จวนจะจบวันแล้ว', 'บันทึกมื้อเย็นเพื่อดูสรุปแคลอรี่ทั้งวันนะ'),
      ('🍽️ มื้อสุดท้ายวันนี้', 'กินเสร็จแล้วแวะมาบันทึกที่นี่ก่อนนอนเลยนะ'),
    ];
    final pool = type == 'breakfast'
        ? breakfast
        : type == 'lunch'
            ? lunch
            : dinner;
    return pool[_rng.nextInt(pool.length)];
  }

  static (String, String) _waterCopy() {
    // Insight-driven: mix of hydration facts and direct encouragement
    const variants = [
      ('💧 จิบน้ำหน่อยนะ', 'การดื่มน้ำพอช่วยลดความอยากของว่างได้ด้วยนะครับ'),
      ('🥤 น้ำช่วยได้มากกว่าที่คิด', 'ดื่มน้ำเยอะๆ ช่วยให้เผาผลาญดีและผิวสวยขึ้นด้วย'),
      ('💦 ร่างกายต้องการน้ำตอนนี้', 'บ่ายนี้ดื่มน้ำให้ครบนะ ช่วยให้ไม่ง่วงและลดความหิวด้วย'),
      ('🌊 ไม่ต้องรอกระหายก่อนก็ได้', 'ดื่มน้ำสม่ำเสมอดีกว่ารอให้ปากแห้ง ร่างกายขอบคุณนะ'),
    ];
    return variants[_rng.nextInt(variants.length)];
  }

  static (String, String) _motivationCopy() {
    const variants = [
      ('🔥 วันใหม่ โอกาสใหม่', 'วินัยสร้างได้ทุกวัน เริ่มบันทึกมื้อแรกกันเลยนะ'),
      ('💪 ทำได้อีกวัน!', 'คุณทำมาต่อเนื่องแล้ว วันนี้รักษาโมเมนตัมนี้ไว้นะครับ'),
      ('⚡ ตื่นเช้า พร้อมเริ่ม', 'เป้าหมายรอคุณอยู่ เริ่มบันทึกอาหารมื้อแรกกันเลย'),
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
    // Feature 2: add "ทานเหมือนเดิม" quick-copy action on all meal notifications
    const actions = [
      AndroidNotificationAction('copy_yesterday', 'ทานเหมือนเดิม ✓'),
      AndroidNotificationAction('log_now', 'บันทึกเอง',
          showsUserInterface: true),
      AndroidNotificationAction('snooze_30m', 'เลื่อน 30 นาที'),
    ];

    // Breakfast (ID 101) — always generic: no prior-day data at 8am
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

    // Lunch (ID 102) — Feature 1: personalised if morning data available
    final lunchHm = await getLunchHm();
    final lunchPersonal = await _personalizedMealCopy('lunch');
    final lunchCopy = lunchPersonal ?? _mealCopy('lunch');
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

    // Dinner (ID 103) — Feature 1: personalised with current-day macro deficit
    final dinnerHm = await getDinnerHm();
    final dinnerPersonal = await _personalizedMealCopy('dinner');
    final dinnerCopy = dinnerPersonal ?? _mealCopy('dinner');
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

  /// Schedule a daily streak warning. Message wording depends on the grace
  /// status (0 = ok, 1 = first miss, 2 = last chance, -1 = expired).
  /// Pass [graceStatus] from `StreakService.getGraceStatus()`.
  static Future<void> scheduleStreakWarning(int currentStreak,
      {int graceStatus = 0}) async {
    if (kIsWeb || currentStreak < 2) return;
    if (!await isCategoryEnabled(NotificationCategory.streak)) return;

    final String title;
    final String body;
    if (graceStatus == -1) {
      title = '💔 Streak ขาดแล้ว';
      body = 'กู้คืน streak $currentStreak วันได้ในแอป (ฟรี 1 ครั้ง/เดือน หรือซื้อร้าน 300 🌾)';
    } else if (graceStatus == 2) {
      title = '🚨 วันสุดท้าย! Streak $currentStreak วันจะหาย';
      body = 'บันทึกวันนี้เพื่อรักษา streak ไว้ก่อนเที่ยงคืน';
    } else if (graceStatus == 1) {
      title = '🌱 คุณรอดตัวไป!';
      body = 'บันทึกอาหารวันนี้เพื่อรักษา streak $currentStreak วัน';
    } else {
      title = '🔥 Streak $currentStreak วันของคุณกำลังจะหาย!';
      body = 'บันทึกอาหารวันนี้ก่อน 4 ทุ่มเพื่อรักษา streak ไว้นะ';
    }

    await _notification.cancel(1001);
    await _notification.zonedSchedule(
      1001,
      title,
      body,
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

  // ── Celebration notifications (Notification Hierarchy) ────────────────────

  /// Fired when user hits their daily calorie goal (within ±10%).
  /// Uses ID 901 = same as re-engagement day-2 slot (mutually exclusive).
  static Future<void> showGoalAchievedNotification(int calories) async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    // Celebrate once per day
    if ((prefs.getString('goal_celebrated_date') ?? '') == todayStr) return;
    await prefs.setString('goal_celebrated_date', todayStr);

    const celebrations = [
      ('🎉 เป้าหมายวันนี้ครบแล้ว!', 'สุดยอดมาก! วันนี้คุณทำตามแผนโภชนาการได้ดีมากเลยนะ 💪'),
      ('✅ ทำได้แล้ววันนี้!', 'คุณกินพลังงานตรงตามเป้าหมายวันนี้ รักษาโมเมนตัมนี้ไว้นะ!'),
      ('🌟 วันดีๆ อีกวัน', 'แคลอรี่วันนี้ครบแล้ว ขอบคุณที่รักษาสุขภาพของตัวเองนะ'),
    ];
    final copy = celebrations[DateTime.now().millisecondsSinceEpoch % celebrations.length];
    await showNotification(
      id: 9001,
      title: copy.$1,
      body: copy.$2,
      payload: 'home',
      bypassRateLimit: true,
    );
    ErrorReporter.event('notification.celebration.goal_achieved',
        data: {'calories': calories});
  }

  /// Fired when user reaches a new streak milestone (3, 7, 14, 30 days).
  static Future<void> showStreakCelebration(int streak) async {
    if (kIsWeb) return;
    if (streak < 3) return;
    if (![3, 7, 14, 30].contains(streak) && streak % 30 != 0) return;

    final emoji = streak >= 30 ? '🏆' : streak >= 14 ? '🥇' : streak >= 7 ? '🥈' : '🎯';
    await showNotification(
      id: 9002,
      title: '$emoji Streak $streak วัน! ยอดเยี่ยมมาก!',
      body: 'คุณบันทึกอาหารต่อเนื่อง $streak วันแล้ว! '
          '${streak >= 30 ? "นั่นคือเกือบเดือนเต็มๆ เลย!" : streak >= 7 ? "ครบสัปดาห์แล้วนะ!" : "รักษาไว้นะ!"}',
      payload: 'home',
      bypassRateLimit: true,
    );
    ErrorReporter.event('notification.celebration.streak',
        data: {'streak': streak});
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

      // ── New feature tests ────────────────────────────────────────────────
      case 'meal_actions':
        // Test meal notification WITH action buttons (copy_yesterday, log_now, snooze)
        await _notification.show(
          9905,
          '🍱 [Test] มื้อเที่ยงวันนี้เป็นไง?',
          'พลังงานพอไหม? กด "ทานเหมือนเดิม" หรือ "บันทึกเอง"',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'channel_id_daily',
              'Daily Reminders',
              importance: Importance.max,
              priority: Priority.high,
              actions: [
                AndroidNotificationAction('copy_yesterday', 'ทานเหมือนเดิม ✓'),
                AndroidNotificationAction('log_now', 'บันทึกเอง',
                    showsUserInterface: true),
                AndroidNotificationAction('snooze_30m', 'เลื่อน 30 นาที'),
              ],
            ),
            iOS: DarwinNotificationDetails(categoryIdentifier: 'MEAL_REMINDER'),
          ),
          payload: 'record_food',
        );

      case 'gap_fill':
        // Schedule gap-fill 10 seconds from now (for quick testing)
        final testTime = tz.TZDateTime.now(tz.local)
            .add(const Duration(seconds: 10));
        await _notification.zonedSchedule(
          9906,
          '🍽️ [Test] ยังไม่เห็นมื้อเย็นเลยนะ',
          'วันนี้ยังขาดมื้อเย็น บันทึกก่อนนอนเพื่อดูสรุปแคลอรี่ทั้งวัน',
          testTime,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'channel_id_urgent',
              'Urgent Reminders',
              importance: Importance.max,
              priority: Priority.high,
              actions: [
                AndroidNotificationAction('log_now', 'บันทึกเลย',
                    showsUserInterface: true),
                AndroidNotificationAction('copy_yesterday', 'ทานเหมือนเดิม ✓'),
              ],
            ),
            iOS: DarwinNotificationDetails(categoryIdentifier: 'MEAL_REMINDER'),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'record_food',
        );

      case 'celebration_goal':
        // Test goal-achieved celebration
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('goal_celebrated_date'); // reset dedup
        await showGoalAchievedNotification(1500);

      case 'celebration_streak':
        // Test streak milestone celebration
        await showStreakCelebration(7);

      case 'personalized_dinner':
        // Test personalized dinner copy (protein deficit scenario)
        await showNotification(
          id: 9907,
          title: '🥩 ขาดโปรตีนอยู่นะ!',
          body: 'วันนี้ยังขาดโปรตีนอีก 25g ลองเพิ่มไข่ต้มหรือเนื้อมื้อเย็นด้วยนะ',
          payload: 'record_food',
          bypassRateLimit: true,
          bypassQuiet: true,
        );
    }
  }
}
