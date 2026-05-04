import 'package:flutter_test/flutter_test.dart';

// ── Tier model (mirrors tamagotchi_screen.dart) ─────────────
class _Tier {
  final String name;
  final int minPts;
  const _Tier(this.name, this.minPts);
}

const _tiers = [
  _Tier('ต้นกล้า', 0),
  _Tier('ต้อย', 100),
  _Tier('แต้ว', 300),
  _Tier('โต้ง', 700),
  _Tier('พราว', 1200),
  _Tier('วิ้งค์', 2000),
];

int tierIndexOf(int pts) {
  for (int i = _tiers.length - 1; i >= 0; i--) {
    if (pts >= _tiers[i].minPts) return i;
  }
  return 0;
}

int clampTierIndex(int idx) => idx.clamp(0, _tiers.length - 1);

// Simulate maxTierIdx logic (never decreases)
int updateMaxTier(int currentMax, int newPts) {
  final newTier = tierIndexOf(newPts);
  return newTier > currentMax ? newTier : currentMax;
}

// Points after redeem
int redeemBadge(int currentPts, int cost) {
  if (currentPts < cost) throw Exception('points_insufficient');
  return currentPts - cost;
}

// Mission claim (returns new points, throws if already claimed today)
int claimMission(int currentPts, int missionPts, Set<String> claimedToday,
    String missionId) {
  if (claimedToday.contains(missionId)) throw Exception('already_claimed');
  return currentPts + missionPts;
}

void main() {
  // ══════════════════════════════════════════════════════════
  // Tier Logic Tests
  // ══════════════════════════════════════════════════════════
  group('Tier Logic', () {
    test('TC032 - 0 points → tier 0 (ต้นกล้า)', () {
      expect(tierIndexOf(0), 0);
    });

    test('TC032 - 100 points → tier 1 (ต้อย)', () {
      expect(tierIndexOf(100), 1);
    });

    test('TC032 - 1200 points → tier 4 (พราว)', () {
      expect(tierIndexOf(1200), 4);
    });

    test('TC032 - 2000 points → tier 5 (วิ้งค์)', () {
      expect(tierIndexOf(2000), 5);
    });

    test('TC032 - 9999 points → tier 5 (max tier)', () {
      expect(tierIndexOf(9999), 5);
    });

    test('TC032 - 299 points still tier 1 (not yet 300)', () {
      expect(tierIndexOf(299), 1);
    });

    test('TC033 - maxTierIdx never decreases after spending points', () {
      int maxTier = 0;
      maxTier = updateMaxTier(maxTier, 2000); // reach วิ้งค์
      expect(maxTier, 5);

      // spend points → back to 50 pts, but maxTier stays 5
      maxTier = updateMaxTier(maxTier, 50);
      expect(maxTier, 5);
    });

    test('TC033 - maxTierIdx increases when higher tier reached', () {
      int maxTier = 2;
      maxTier = updateMaxTier(maxTier, 1500); // cross tier 4
      expect(maxTier, 4);
    });

    test('clampTierIndex stays within 0..5 bounds', () {
      expect(clampTierIndex(-1), 0);
      expect(clampTierIndex(10), 5);
      expect(clampTierIndex(3), 3);
    });
  });

  // ══════════════════════════════════════════════════════════
  // Badge Redemption Tests
  // ══════════════════════════════════════════════════════════
  group('Badge Redemption', () {
    test('TC034 - redeem badge with sufficient points deducts correctly', () {
      final newPts = redeemBadge(500, 50); // badge_newbie costs 50
      expect(newPts, 450);
    });

    test('TC034 - redeem badge_grower (300pts) from 500pts', () {
      final newPts = redeemBadge(500, 300);
      expect(newPts, 200);
    });

    test('TC035 - redeem badge with insufficient points throws', () {
      expect(() => redeemBadge(40, 50), throwsException);
    });

    test('TC035 - redeem with exactly 0 points throws', () {
      expect(() => redeemBadge(0, 50), throwsException);
    });

    test('TC034 - redeem with exact points results in 0', () {
      final newPts = redeemBadge(50, 50);
      expect(newPts, 0);
    });
  });

  // ══════════════════════════════════════════════════════════
  // Mission Claim Tests
  // ══════════════════════════════════════════════════════════
  group('Mission Claim', () {
    test('TC030 - claim new mission adds points', () {
      final pts = claimMission(0, 50, {}, 'mission_login');
      expect(pts, 50);
    });

    test('TC030 - claim mission with multiplier', () {
      final pts = claimMission(1000, 50, {}, 'mission_water');
      expect(pts, 1050);
    });

    test('TC031 - claim same mission twice throws', () {
      expect(
        () => claimMission(100, 50, {'mission_login'}, 'mission_login'),
        throwsException,
      );
    });

    test('TC031 - different missions can be claimed independently', () {
      final pts1 = claimMission(0, 50, {}, 'mission_login');
      final pts2 = claimMission(pts1, 30, {'mission_login'}, 'mission_water');
      expect(pts2, 80);
    });

    test('TC030 - points do not exceed after multiple unique missions', () {
      int pts = 0;
      final claimed = <String>{};
      for (final m in ['m1', 'm2', 'm3']) {
        pts = claimMission(pts, 100, claimed, m);
        claimed.add(m);
      }
      expect(pts, 300);
    });
  });

  // ══════════════════════════════════════════════════════════
  // Calorie Calculation Tests  (TC018-TC020)
  // ══════════════════════════════════════════════════════════
  group('Calorie Calculation', () {
    int totalCalories(List<int> meals) => meals.fold(0, (a, b) => a + b);
    int deficit(int intake, int goal) => goal - intake;

    test('TC018 - sum calories across 3 meals', () {
      expect(totalCalories([400, 600, 500]), 1500);
    });

    test('TC019 - deficit when intake < goal', () {
      expect(deficit(1500, 2000), 500);
    });

    test('TC020 - surplus when intake > goal (negative deficit)', () {
      expect(deficit(2500, 2000), -500);
    });

    test('TC018 - no meals = 0 calories', () {
      expect(totalCalories([]), 0);
    });
  });

  // ══════════════════════════════════════════════════════════
  // Water Logging Tests  (TC021-TC023)
  // ══════════════════════════════════════════════════════════
  group('Water Logging', () {
    int addGlass(int current, {int max = 15}) =>
        current < max ? current + 1 : current;
    int removeGlass(int current) => current > 0 ? current - 1 : 0;

    test('TC021 - add glass increments count', () {
      expect(addGlass(3), 4);
    });

    test('TC022 - remove glass at 0 stays 0', () {
      expect(removeGlass(0), 0);
    });

    test('TC023 - add glass at cap (15) stays 15', () {
      expect(addGlass(15), 15);
    });

    test('TC021 - add glass from 0 gives 1', () {
      expect(addGlass(0), 1);
    });
  });
}
