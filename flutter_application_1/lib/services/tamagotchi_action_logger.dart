import 'package:shared_preferences/shared_preferences.dart';

/// Simple SharedPreferences-based "action inbox" that lets screens outside
/// TamagotchiScreen signal reward-worthy events (food suggestion, food review)
/// so the tamagotchi can award gems the next time it loads.
///
/// All keys include the current UTC date so they expire automatically
/// at midnight — no explicit cleanup needed.
class TamagotchiActionLogger {
  TamagotchiActionLogger._();

  static String _todayStr() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String _suggestKey(int uid) =>
      'tama_suggest_${uid}_${_todayStr()}';

  // Stores the normalized (lowercased) names submitted today for dedup.
  static String _suggestNamesKey(int uid) =>
      'tama_suggest_names_${uid}_${_todayStr()}';

  static String _reviewKey(int uid) =>
      'tama_review_${uid}_${_todayStr()}';

  // ── Food Suggestion ────────────────────────────────────────────────────────

  /// Call this right after a successful /foods/auto-add POST.
  /// Returns `true` if the food name was new (not already submitted today).
  /// Duplicate names (case-insensitive) are silently ignored.
  static Future<bool> logFoodSuggestion(int uid, String foodName) async {
    if (uid <= 0) return false;
    final name = foodName.trim().toLowerCase();
    if (name.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final namesKey = _suggestNamesKey(uid);
    final existing = prefs.getStringList(namesKey) ?? [];

    if (existing.contains(name)) return false; // duplicate — no reward

    final updated = [...existing, name];
    await prefs.setStringList(namesKey, updated);
    await prefs.setInt(_suggestKey(uid), updated.length);
    return true;
  }

  /// Returns how many unique food names the user has submitted today.
  static Future<int> getFoodSuggestionCount(int uid) async {
    if (uid <= 0) return 0;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_suggestKey(uid)) ?? 0;
  }

  // ── Food Review ────────────────────────────────────────────────────────────

  /// Call this right after a successful /recipes/{id}/review POST.
  static Future<void> logFoodReview(int uid) async {
    if (uid <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reviewKey(uid), true);
  }

  /// Returns whether the user has submitted at least one review today.
  static Future<bool> getFoodReviewDone(int uid) async {
    if (uid <= 0) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_reviewKey(uid)) ?? false;
  }
}
