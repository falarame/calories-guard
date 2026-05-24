/// Unit tests for referral system client-side logic
///
/// ทดสอบ:
///   1. _LeaderboardEntry.tryParse  — parse JSON → model
///   2. Leaderboard streak subtitle — แสดง streak/login days ถูกต้อง
///   3. Gem buff multiplier logic   — earnedGems คูณ multiplier ถูก
///   4. Referral code format        — ตรวจ PREFIX-DDDD
///   5. Buff expiry display         — format วันที่หมดอายุ
library;

import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────
// Mirror structs (ไม่ import ตัวจริงเพื่อให้ test pure/isolated)
// ─────────────────────────────────────────────────────────────

class LeaderboardEntry {
  final int userId;
  final String username;
  final String? avatarUrl;
  final int weeklyXp;
  final int tierIdx;
  final int rank;
  final int streak;
  final int totalLoginDays;

  const LeaderboardEntry({
    required this.userId,
    required this.username,
    this.avatarUrl,
    required this.weeklyXp,
    required this.tierIdx,
    required this.rank,
    required this.streak,
    required this.totalLoginDays,
  });

  static LeaderboardEntry? tryParse(dynamic raw, int rank) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final uid = (m['user_id'] as num?)?.toInt();
    if (uid == null) return null;
    return LeaderboardEntry(
      userId: uid,
      username: (m['username'] ?? 'User').toString(),
      avatarUrl: m['avatar_url']?.toString(),
      weeklyXp: (m['weekly_xp'] as num?)?.toInt() ??
          (m['tama_points'] as num?)?.toInt() ??
          0,
      tierIdx: (m['tier_level'] as num?)?.toInt() ?? 0,
      rank: (m['rank'] as num?)?.toInt() ?? rank,
      streak: (m['current_streak'] as num?)?.toInt() ?? 0,
      totalLoginDays: (m['total_login_days'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Mirrors _formatExpiry in ReferralScreen
String formatExpiry(String? iso) {
  if (iso == null) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.day}/${dt.month}/${dt.year}';
  } catch (_) {
    return '';
  }
}

/// Mirrors gem buff application in _claimMission
int applyGemBuff(int baseGems, int multiplier) {
  if (baseGems > 0 && multiplier > 1) {
    return (baseGems * multiplier).clamp(0, 99999).toInt();
  }
  return baseGems;
}

/// Validates referral code format PREFIX-DDDD
bool isValidCodeFormat(String code) {
  final parts = code.split('-');
  if (parts.length != 2) return false;
  final prefix = parts[0];
  final digits = parts[1];
  const validPrefixes = ['RICE', 'MEAL', 'KCAL', 'SEED', 'GOAL'];
  return validPrefixes.contains(prefix) &&
      digits.length == 4 &&
      RegExp(r'^\d{4}$').hasMatch(digits);
}

// ─────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────

void main() {
  // ── LeaderboardEntry.tryParse ──────────────────────────────

  group('LeaderboardEntry.tryParse', () {
    test('parses full JSON correctly', () {
      final raw = {
        'user_id': 7,
        'username': 'somying',
        'avatar_url': 'https://example.com/avatar.png',
        'weekly_xp': 350,
        'tier_level': 2,
        'rank': 1,
        'current_streak': 14,
        'total_login_days': 60,
      };
      final entry = LeaderboardEntry.tryParse(raw, 1)!;
      expect(entry.userId, 7);
      expect(entry.username, 'somying');
      expect(entry.weeklyXp, 350);
      expect(entry.tierIdx, 2);
      expect(entry.rank, 1);
      expect(entry.streak, 14);
      expect(entry.totalLoginDays, 60);
    });

    test('falls back to tama_points when weekly_xp absent', () {
      final raw = {'user_id': 1, 'tama_points': 200};
      final entry = LeaderboardEntry.tryParse(raw, 1)!;
      expect(entry.weeklyXp, 200);
    });

    test('defaults missing numeric fields to 0', () {
      final entry = LeaderboardEntry.tryParse({'user_id': 1}, 3)!;
      expect(entry.weeklyXp, 0);
      expect(entry.streak, 0);
      expect(entry.totalLoginDays, 0);
      expect(entry.tierIdx, 0);
    });

    test('uses fallback rank when rank absent from JSON', () {
      final entry = LeaderboardEntry.tryParse({'user_id': 5}, 9)!;
      expect(entry.rank, 9);
    });

    test('returns null for non-map input', () {
      expect(LeaderboardEntry.tryParse('not a map', 1), isNull);
      expect(LeaderboardEntry.tryParse(42, 1), isNull);
    });

    test('returns null when user_id missing', () {
      expect(LeaderboardEntry.tryParse({'username': 'ghost'}, 1), isNull);
    });

    test('handles null avatar_url gracefully', () {
      final entry = LeaderboardEntry.tryParse({'user_id': 2}, 1)!;
      expect(entry.avatarUrl, isNull);
    });
  });

  // ── Leaderboard subtitle logic ─────────────────────────────

  group('Leaderboard subtitle', () {
    String streakSubtitle(LeaderboardEntry e) =>
        '🔥 ${e.streak} วันติดต่อกัน  •  ${e.totalLoginDays} วันทั้งหมด';

    String xpSubtitle(LeaderboardEntry e) {
      const tierEmojis = ['🌱', '🌿', '🌾', '🍚', '✨'];
      final emoji = tierEmojis[e.tierIdx.clamp(0, tierEmojis.length - 1)];
      return '$emoji  ${e.weeklyXp} XP สัปดาห์นี้';
    }

    test('streak subtitle shows streak and total days', () {
      final e = LeaderboardEntry.tryParse(
          {'user_id': 1, 'current_streak': 7, 'total_login_days': 30}, 1)!;
      expect(streakSubtitle(e), '🔥 7 วันติดต่อกัน  •  30 วันทั้งหมด');
    });

    test('xp subtitle shows correct tier emoji', () {
      final e = LeaderboardEntry.tryParse(
          {'user_id': 1, 'weekly_xp': 150, 'tier_level': 2}, 1)!;
      expect(xpSubtitle(e), contains('🌾'));
      expect(xpSubtitle(e), contains('150'));
    });

    test('tier_level clamped to emoji range', () {
      final e = LeaderboardEntry.tryParse(
          {'user_id': 1, 'weekly_xp': 0, 'tier_level': 99}, 1)!;
      // clamped to last index (✨)
      expect(xpSubtitle(e), contains('✨'));
    });
  });

  // ── Gem buff multiplier ────────────────────────────────────

  group('Gem buff multiplier', () {
    test('no buff: gems unchanged', () {
      expect(applyGemBuff(10, 1), 10);
    });

    test('x2 buff: gems doubled', () {
      expect(applyGemBuff(10, 2), 20);
    });

    test('x2 buff on zero gems: still zero', () {
      expect(applyGemBuff(0, 2), 0);
    });

    test('buff capped at 99999', () {
      expect(applyGemBuff(99999, 2), 99999);
    });

    test('large buff applied correctly', () {
      expect(applyGemBuff(100, 3), 300);
    });
  });

  // ── Referral code format validation ───────────────────────

  group('Referral code format', () {
    test('valid RICE code passes', () {
      expect(isValidCodeFormat('RICE-1234'), isTrue);
    });

    test('all valid prefixes accepted', () {
      for (final prefix in ['RICE', 'MEAL', 'KCAL', 'SEED', 'GOAL']) {
        expect(isValidCodeFormat('$prefix-0000'), isTrue,
            reason: '$prefix should be valid');
      }
    });

    test('unknown prefix rejected', () {
      expect(isValidCodeFormat('FOOD-1234'), isFalse);
    });

    test('non-digit suffix rejected', () {
      expect(isValidCodeFormat('RICE-ABCD'), isFalse);
    });

    test('too long suffix rejected', () {
      expect(isValidCodeFormat('RICE-12345'), isFalse);
    });

    test('missing dash rejected', () {
      expect(isValidCodeFormat('RICE1234'), isFalse);
    });

    test('empty string rejected', () {
      expect(isValidCodeFormat(''), isFalse);
    });
  });

  // ── Buff expiry display ────────────────────────────────────

  group('formatExpiry', () {
    test('formats ISO datetime to d/m/yyyy', () {
      final result = formatExpiry('2026-06-15T10:00:00.000Z');
      expect(result, contains('15'));
      expect(result, contains('6'));
      expect(result, contains('2026'));
    });

    test('returns empty string for null', () {
      expect(formatExpiry(null), '');
    });

    test('returns empty string for invalid ISO', () {
      expect(formatExpiry('not-a-date'), '');
    });
  });
}
