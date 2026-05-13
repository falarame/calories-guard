import 'dart:convert';

import 'package:flutter_application_1/services/api_client.dart';
import 'package:flutter_application_1/services/error_reporter.dart';

/// True when [meals] has at least one non-empty menu but [meal_items] is
/// missing entries or lists are empty for any of those meal types.
bool mealItemsMissingForSummary(dynamic mealItemsRaw, dynamic mealsRaw) {
  if (mealsRaw is! Map || mealsRaw.isEmpty) return false;
  final mi = <String, dynamic>{};
  if (mealItemsRaw is Map) {
    mealItemsRaw.forEach((k, v) {
      mi[k.toString().trim().toLowerCase()] = v;
    });
  }
  for (final k in mealsRaw.keys) {
    final key = k.toString().trim().toLowerCase();
    final menu = mealsRaw[k]?.toString().trim() ?? '';
    if (menu.isEmpty || menu == '-') continue;
    final list = mi[key];
    if (list is! List || list.isEmpty) return true;
  }
  return false;
}

/// Fills [summaryData]['meal_items'] via [GET /meals/{userId}/detail] when
/// the summary omits per-item rows (older API) or parsing would leave the
/// home screen in the plain-text fallback.
Future<Map<String, dynamic>> ensureDailySummaryMealItems({
  required int userId,
  required String dateStr,
  required Map<String, dynamic> summaryData,
  Duration? detailTimeout,
}) async {
  if (!mealItemsMissingForSummary(summaryData['meal_items'], summaryData['meals'])) {
    return summaryData;
  }

  final meals = summaryData['meals'];
  if (meals is! Map) return summaryData;

  final out = Map<String, dynamic>.from(summaryData);
  final merged = <String, List<dynamic>>{};
  final existing = out['meal_items'];
  if (existing is Map) {
    for (final e in existing.entries) {
      final key = e.key.toString().trim().toLowerCase();
      final v = e.value;
      if (v is List && v.isNotEmpty) {
        merged[key] = List<dynamic>.from(v);
      }
    }
  }

  final client = ApiClient();
  Future<void> fetchOne(String mt) async {
    try {
      final res = await client.get(
        '/meals/$userId/detail',
        queryParams: {'date_record': dateStr, 'meal_type': mt},
        timeout: detailTimeout,
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return;
      final body = json.decode(utf8.decode(res.bodyBytes));
      if (body is! Map) return;
      final items = body['items'];
      if (items is List && items.isNotEmpty) {
        merged[mt] = List<dynamic>.from(items);
      }
    } catch (e, st) {
      ErrorReporter.report('home.fetch_daily_summary.$mt', e, st);
    }
  }

  final tasks = <Future<void>>[];
  for (final entry in meals.entries) {
    final mt = entry.key.toString().trim().toLowerCase();
    if (merged[mt] != null && merged[mt]!.isNotEmpty) continue;
    final menuName = entry.value?.toString().trim() ?? '';
    if (menuName.isEmpty || menuName == '-') continue;
    tasks.add(fetchOne(mt));
  }
  await Future.wait(tasks);

  out['meal_items'] = merged;
  return out;
}
