/// Syncs notification preferences between the device (SharedPreferences)
/// and the backend (PUT /users/{id}/notification_prefs).
///
/// Pull on login so preferences follow the user across devices.
/// Push (debounced 500 ms) whenever a pref changes.
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';
import 'notification_helper.dart';

class NotificationPrefsService {
  static Timer? _debounce;

  // ── Pull (on login) ────────────────────────────────────────────────────────

  /// Fetch stored prefs from backend and write them to SharedPreferences.
  /// Silently no-ops if the server returns nothing or is unavailable.
  static Future<void> pull(int userId) async {
    if (kIsWeb || userId == 0) return;
    try {
      final res = await ApiClient().get('/users/$userId/notification_prefs');
      if (res.statusCode != 200) return;
      final data = json.decode(res.body) as Map<String, dynamic>;
      final prefs = data['notification_prefs'] as Map<String, dynamic>?;
      if (prefs == null || prefs.isEmpty) return;

      final sp = await SharedPreferences.getInstance();

      if (prefs['enabled'] is bool) {
        await sp.setBool('notifications_enabled', prefs['enabled'] as bool);
      }
      if (prefs['weighInDay'] is int) {
        await sp.setInt('weigh_in_weekday', prefs['weighInDay'] as int);
      }

      final cats = prefs['categories'] as Map<String, dynamic>?;
      if (cats != null) {
        for (final cat in NotificationCategory.values) {
          if (cats[cat.name] is bool) {
            await sp.setBool('notif_cat_${cat.name}', cats[cat.name] as bool);
          }
        }
      }

      final qh = prefs['quietHours'] as Map<String, dynamic>?;
      if (qh != null) {
        if (qh['enabled'] is bool) {
          await sp.setBool('quiet_hours_enabled', qh['enabled'] as bool);
        }
        if (qh['startMin'] is int) {
          await sp.setInt('quiet_hours_start_min', qh['startMin'] as int);
        }
        if (qh['endMin'] is int) {
          await sp.setInt('quiet_hours_end_min', qh['endMin'] as int);
        }
      }

      final mt = prefs['mealTimes'] as Map<String, dynamic>?;
      if (mt != null) {
        if (mt['breakfastHm'] is int) {
          await sp.setInt('meal_breakfast_hm', mt['breakfastHm'] as int);
        }
        if (mt['lunchHm'] is int) {
          await sp.setInt('meal_lunch_hm', mt['lunchHm'] as int);
        }
        if (mt['dinnerHm'] is int) {
          await sp.setInt('meal_dinner_hm', mt['dinnerHm'] as int);
        }
      }

      final wt = prefs['waterTimesHH'] as List<dynamic>?;
      if (wt != null) {
        final hours = wt.whereType<int>().toList();
        await sp.setString('water_times_hh', hours.join(','));
      }

      // Feature 3 – Adaptive Timing: read smart_timing_enabled from stored prefs
      if (prefs['smart_timing_enabled'] is bool) {
        await sp.setBool('smart_timing_enabled', prefs['smart_timing_enabled'] as bool);
      }

      // Feature 3 – Adaptive Timing: persist suggested meal times from backend
      final suggested = data['suggested_meal_times'] as Map<String, dynamic>?;
      if (suggested != null) {
        if (suggested['breakfastHm'] is int) {
          await sp.setInt('smart_breakfast_hm', suggested['breakfastHm'] as int);
        }
        if (suggested['lunchHm'] is int) {
          await sp.setInt('smart_lunch_hm', suggested['lunchHm'] as int);
        }
        if (suggested['dinnerHm'] is int) {
          await sp.setInt('smart_dinner_hm', suggested['dinnerHm'] as int);
        }
      }

      debugPrint('[NotificationPrefsService] pulled prefs for user $userId');
    } catch (e) {
      debugPrint('[NotificationPrefsService] pull error: $e');
    }
  }

  // ── Push (debounced, called after any pref change) ─────────────────────────

  /// Collect current prefs from SharedPreferences and PUT them to backend.
  /// Debounced by 500 ms so rapid toggles don't spam the server.
  static void pushDebounced(int userId) {
    if (kIsWeb || userId == 0) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _push(userId));
  }

  static Future<void> _push(int userId) async {
    try {
      final sp = await SharedPreferences.getInstance();

      final categories = <String, bool>{};
      for (final cat in NotificationCategory.values) {
        categories[cat.name] = sp.getBool('notif_cat_${cat.name}') ?? true;
      }

      final qhEnabled = sp.getBool('quiet_hours_enabled') ?? false;
      final qhStart = sp.getInt('quiet_hours_start_min') ?? 1320;
      final qhEnd = sp.getInt('quiet_hours_end_min') ?? 420;

      final breakfastHm = sp.getInt('meal_breakfast_hm') ?? 800;
      final lunchHm = sp.getInt('meal_lunch_hm') ?? 1200;
      final dinnerHm = sp.getInt('meal_dinner_hm') ?? 1800;

      final waterRaw = sp.getString('water_times_hh') ?? '10,14,16,20';
      final waterTimes = waterRaw
          .split(',')
          .map((s) => int.tryParse(s.trim()) ?? -1)
          .where((h) => h >= 0)
          .toList();

      final body = {
        'enabled': sp.getBool('notifications_enabled') ?? true,
        'categories': categories,
        'quiet_hours': {
          'enabled': qhEnabled,
          'startMin': qhStart,
          'endMin': qhEnd,
        },
        'meal_times': {
          'breakfastHm': breakfastHm,
          'lunchHm': lunchHm,
          'dinnerHm': dinnerHm,
        },
        'water_times_hh': waterTimes,
        'weigh_in_day': sp.getInt('weigh_in_weekday') ?? 1,
        // Feature 3: persist smart-timing preference server-side
        'smart_timing_enabled': sp.getBool('smart_timing_enabled') ?? false,
      };

      await ApiClient().put('/users/$userId/notification_prefs', body: body);
      debugPrint('[NotificationPrefsService] pushed prefs for user $userId');
    } catch (e) {
      debugPrint('[NotificationPrefsService] push error: $e');
    }
  }
}
