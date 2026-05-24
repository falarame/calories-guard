/// Unit tests for pedometer daily-step calculation & buff logic
///
/// ทดสอบ:
///   1. PedometerService daily step calculation (baseline logic)
///   2. Step provider: max(healthSteps, pedometerSteps)
///   3. Gem buff application scenarios
library;

import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────
// Mirrors of pedometer & step logic (extracted as pure functions)
// ─────────────────────────────────────────────────────────────

/// Mirrors PedometerService._onStep daily-step calculation.
/// cumulativeSteps = total steps since device reboot
/// baseline = cumulative count at start of today
int calcDailySteps({
  required int cumulativeSteps,
  required int baseline,
}) {
  if (cumulativeSteps < baseline) {
    // Device rebooted or baseline stale → reset baseline
    return cumulativeSteps;
  }
  return cumulativeSteps - baseline;
}

/// Mirrors step_provider combine logic:
/// Take max of Health Connect full-day steps vs live pedometer.
int combineSteps({required int healthSteps, required int pedometerSteps}) {
  return healthSteps > pedometerSteps ? healthSteps : pedometerSteps;
}

/// Mirrors tamagotchi_screen.dart weekly XP clamp
int clampWeeklyXp(int current, int added) {
  return (current + added).clamp(0, 9999999).toInt();
}

/// Mirrors gems clamp
int clampGems(int current, int added) {
  return (current + added).clamp(0, 999999).toInt();
}

// ─────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────

void main() {
  // ── Pedometer daily steps ──────────────────────────────────

  group('calcDailySteps', () {
    test('normal increment: cumulative - baseline', () {
      expect(calcDailySteps(cumulativeSteps: 1500, baseline: 1000), 500);
    });

    test('zero daily steps when no new steps', () {
      expect(calcDailySteps(cumulativeSteps: 1000, baseline: 1000), 0);
    });

    test('device reboot: cumulative < baseline → returns cumulative', () {
      // After reboot, counter resets to low value
      expect(calcDailySteps(cumulativeSteps: 200, baseline: 5000), 200);
    });

    test('fresh start: cumulative and baseline both zero', () {
      expect(calcDailySteps(cumulativeSteps: 0, baseline: 0), 0);
    });

    test('first steps of day: baseline = 0', () {
      expect(calcDailySteps(cumulativeSteps: 300, baseline: 0), 300);
    });
  });

  // ── Step provider combine ──────────────────────────────────

  group('combineSteps', () {
    test('health steps higher → returns health steps', () {
      expect(combineSteps(healthSteps: 8000, pedometerSteps: 3000), 8000);
    });

    test('pedometer steps higher → returns pedometer steps', () {
      expect(combineSteps(healthSteps: 1000, pedometerSteps: 5000), 5000);
    });

    test('equal → returns either (same value)', () {
      expect(combineSteps(healthSteps: 4000, pedometerSteps: 4000), 4000);
    });

    test('both zero', () {
      expect(combineSteps(healthSteps: 0, pedometerSteps: 0), 0);
    });

    test('health zero, pedometer has data', () {
      // App just opened, Health Connect returns 0 but pedometer has live steps
      expect(combineSteps(healthSteps: 0, pedometerSteps: 120), 120);
    });
  });

  // ── Weekly XP clamp ────────────────────────────────────────

  group('clampWeeklyXp', () {
    test('normal addition', () {
      expect(clampWeeklyXp(100, 50), 150);
    });

    test('clamps at max 9999999', () {
      expect(clampWeeklyXp(9999990, 20), 9999999);
    });

    test('cannot go below zero', () {
      expect(clampWeeklyXp(0, 0), 0);
    });
  });

  // ── Gems clamp ─────────────────────────────────────────────

  group('clampGems', () {
    test('normal addition', () {
      expect(clampGems(50, 10), 60);
    });

    test('clamps at max 999999', () {
      expect(clampGems(999990, 20), 999999);
    });

    test('zero + zero = zero', () {
      expect(clampGems(0, 0), 0);
    });
  });

  // ── Gem buff scenarios (mission claim) ────────────────────

  group('Gem buff x2 scenarios', () {
    int applyBuff(int baseGems, int multiplier) {
      if (baseGems > 0 && multiplier > 1) {
        return (baseGems * multiplier).clamp(0, 99999).toInt();
      }
      return baseGems;
    }

    test('check_in mission: 5 gems x2 = 10', () {
      expect(applyBuff(5, 2), 10);
    });

    test('weight_log mission: 10 gems x2 = 20', () {
      expect(applyBuff(10, 2), 20);
    });

    test('streak_7 mission: 25 gems x2 = 50', () {
      expect(applyBuff(25, 2), 50);
    });

    test('invite_friend mission: 100 gems per person x2 = 200', () {
      expect(applyBuff(100, 2), 200);
    });

    test('no buff (multiplier 1): gems unchanged', () {
      expect(applyBuff(50, 1), 50);
    });

    test('buff does not apply to 0 gems', () {
      // XP-only missions (e.g. streak missions with baseGems=0)
      expect(applyBuff(0, 2), 0);
    });

    test('buff capped at 99999 per mission', () {
      expect(applyBuff(60000, 2), 99999);
    });
  });

  // ── Tiebreaker logic (client-side leaderboard sort mirror) ─

  group('Leaderboard tiebreaker logic', () {
    // Mirrors sort key for XP board
    List<Map<String, dynamic>> sortByXp(List<Map<String, dynamic>> rows) {
      final sorted = List<Map<String, dynamic>>.from(rows);
      sorted.sort((a, b) {
        int cmp = (b['tama_points'] as int).compareTo(a['tama_points'] as int);
        if (cmp != 0) return cmp;
        cmp = (b['tier_level'] as int).compareTo(a['tier_level'] as int);
        if (cmp != 0) return cmp;
        cmp = (b['badge_score'] as int).compareTo(a['badge_score'] as int);
        if (cmp != 0) return cmp;
        return (a['user_id'] as int).compareTo(b['user_id'] as int);
      });
      return sorted;
    }

    test('higher XP ranks first', () {
      final rows = [
        {'user_id': 1, 'tama_points': 100, 'tier_level': 0, 'badge_score': 0},
        {'user_id': 2, 'tama_points': 500, 'tier_level': 0, 'badge_score': 0},
      ];
      final result = sortByXp(rows);
      expect(result[0]['user_id'], 2);
    });

    test('tie on XP: higher tier wins', () {
      final rows = [
        {'user_id': 1, 'tama_points': 200, 'tier_level': 1, 'badge_score': 0},
        {'user_id': 2, 'tama_points': 200, 'tier_level': 3, 'badge_score': 0},
      ];
      expect(sortByXp(rows)[0]['user_id'], 2);
    });

    test('tie on XP+tier: higher badge_score wins', () {
      final rows = [
        {'user_id': 1, 'tama_points': 200, 'tier_level': 2, 'badge_score': 3},
        {'user_id': 2, 'tama_points': 200, 'tier_level': 2, 'badge_score': 100},
      ];
      expect(sortByXp(rows)[0]['user_id'], 2);
    });

    test('full tie: lower user_id wins', () {
      final rows = [
        {'user_id': 9, 'tama_points': 200, 'tier_level': 2, 'badge_score': 5},
        {'user_id': 3, 'tama_points': 200, 'tier_level': 2, 'badge_score': 5},
      ];
      expect(sortByXp(rows)[0]['user_id'], 3);
    });
  });
}
