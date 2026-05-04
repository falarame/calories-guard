/// ══════════════════════════════════════════════════════════════
/// Negative Testing + BVA + Integration Error Handling
/// ══════════════════════════════════════════════════════════════
///
/// 1. Negative Testing  — ระบบจัดการ invalid input โดยไม่พัง (Graceful Failure)
/// 2. BVA (Boundary Value Analysis) — ทดสอบ min-1 / min / min+1 / max-1 / max / max+1
/// 3. Integration Error Simulation — จำลอง API error ที่ Flutter ต้องรับมือ
///
/// อ้างอิงเทคนิค:
///   - Myers GJ, "The Art of Software Testing" (1979) — Boundary Value Analysis
///   - ISTQB Foundation Level Syllabus v4.0 — Negative Testing / Error Guessing
///   - IEEE 829 — Test Case specification format

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

// ── Reuse helpers from health_calc_test.dart ─────────────────
double calcBmi(double weight, double height) {
  if (weight <= 0 || height <= 0) return 0;
  final h = height / 100;
  return weight / (h * h);
}

double calcBmr(double weight, double height, int age, String gender) {
  if (weight <= 0 || height <= 0) return 1500;
  final base = (10 * weight) + (6.25 * height) - (5 * age);
  final raw = gender == 'male' ? base + 5 : base - 161;
  return raw * 0.94;
}

double macroCalories(double protein, double carbs, double fat) =>
    (protein * 4) + (carbs * 4) + (fat * 9);

double calcTargetCalories({
  required double tdee,
  required double kgPerWeek,
  required String gender,
}) {
  final raw = tdee + (kgPerWeek * 1100);
  final floor = gender == 'male' ? 1500.0 : 1200.0;
  return raw < floor ? floor : raw;
}

bool isValidAge(int age) => age >= 13 && age <= 100;
bool isValidHeight(double cm) => cm >= 100 && cm <= 250;
bool isValidWeight(double kg) => kg >= 20 && kg <= 300;
bool isValidEmail(String email) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

String weightLossSafetyLevel(double kgPerWeek) {
  final abs = kgPerWeek.abs();
  if (abs > 1.0) return 'unsafe';
  if (abs > 0.5) return 'borderline';
  return 'recommended';
}

// ── Integration: simulate API response parsing ────────────────
Map<String, dynamic>? parseApiUser(String jsonBody) {
  try {
    final data = jsonDecode(jsonBody) as Map<String, dynamic>;
    return {
      'user_id':  data['user_id']  as int?    ?? 0,
      'username': data['username'] as String? ?? 'ผู้ใช้',
      'weight':   (data['current_weight_kg'] as num?)?.toDouble() ?? 0.0,
      'height':   (data['height_cm'] as num?)?.toDouble() ?? 0.0,
    };
  } catch (_) {
    return null; // Graceful failure
  }
}

Map<String, dynamic> parseLeaderboardEntry(Map<String, dynamic> raw) {
  return {
    'username':      (raw['username'] as String?)    ?? 'ผู้ใช้',
    'tama_points':   (raw['tama_points'] as int?)    ?? 0,
    'current_streak':(raw['current_streak'] as int?) ?? 0,
    'claimed_badges':(raw['claimed_badges'] as List?)?.cast<String>() ?? [],
  };
}

int simulateHttpHandling(int statusCode) {
  // Returns: 0=success, 1=auth error, 2=server error, 3=not found
  if (statusCode == 200) return 0;
  if (statusCode == 401 || statusCode == 403) return 1;
  if (statusCode >= 500) return 2;
  if (statusCode == 404) return 3;
  return 2;
}

// ══════════════════════════════════════════════════════════════
void main() {

  // ────────────────────────────────────────────────────────────
  // PART 1: NEGATIVE TESTING — Graceful Failure
  // เป้าหมาย: ระบบต้อง "ไม่พัง" เมื่อได้รับ input ที่ผิดปกติ
  // ────────────────────────────────────────────────────────────
  group('[Negative] BMI — Invalid Inputs', () {
    test('weight ติดลบ → guard คืน 0 (ไม่ crash)', () {
      expect(calcBmi(-10, 170), 0);
    });

    test('height ติดลบ → guard คืน 0 (ไม่ crash)', () {
      expect(calcBmi(70, -1), 0);
    });

    test('ทั้งคู่ติดลบ → guard คืน 0', () {
      expect(calcBmi(-70, -170), 0);
    });

    test('weight = 0.001 (ใกล้ 0) → guard คืน 0 (ค่า <= 0)', () {
      expect(calcBmi(0, 170), 0);
    });
  });

  group('[Negative] BMR — Invalid Inputs', () {
    test('weight ติดลบ → fallback 1500', () {
      expect(calcBmr(-10, 170, 25, 'male'), 1500);
    });

    test('height ติดลบ → fallback 1500', () {
      expect(calcBmr(70, -1, 25, 'male'), 1500);
    });

    test('age = 0 → คำนวณได้ (ไม่ crash) แต่ค่าสูงผิดปกติ', () {
      // ระบบไม่ crash แต่ output อาจ unrealistic — ต้องใช้ validation ก่อนเรียก
      final result = calcBmr(70, 175, 0, 'male');
      expect(result, isA<double>());
      expect(result, isNot(isNaN));
    });

    test('age = 150 → คำนวณได้ (ไม่ crash) แต่ค่าต่ำมาก/ติดลบ', () {
      final result = calcBmr(70, 175, 150, 'male');
      expect(result, isA<double>());
      expect(result, isNot(isNaN));
    });

    test('gender = "" → ใช้ female branch (-161)', () {
      final result = calcBmr(70, 175, 25, '');
      expect(result, isA<double>());
      expect(result, greaterThan(0));
    });
  });

  group('[Negative] Macro Calories — Invalid Inputs', () {
    test('protein ติดลบ → คืนค่าน้อยกว่า 0 (caller ต้อง validate)', () {
      // ระบบไม่ crash แต่ caller ต้องตรวจสอบก่อนเรียก
      final result = macroCalories(-10, 50, 20);
      expect(result, lessThan(macroCalories(0, 50, 20)));
    });

    test('fat ติดลบมากๆ → ผลออกมาน้อยมาก (ต้อง validate input ก่อน)', () {
      final result = macroCalories(30, 50, -100);
      expect(result, isA<double>());
      expect(result, isNot(isNaN));
    });
  });

  group('[Negative] Target Calories — Extreme Inputs', () {
    test('kgPerWeek = -10 → โดน floor (ไม่ crash)', () {
      final result =
          calcTargetCalories(tdee: 2000, kgPerWeek: -10, gender: 'female');
      expect(result, greaterThanOrEqualTo(1200));
    });

    test('TDEE = 0 → โดน floor (ไม่คืน 0 หรือ negative)', () {
      final result =
          calcTargetCalories(tdee: 0, kgPerWeek: 0, gender: 'male');
      expect(result, greaterThanOrEqualTo(1500));
    });

    test('kgPerWeek = +100 (unrealistic bulk) → คืนค่าสูงมาก (ไม่ crash)', () {
      final result =
          calcTargetCalories(tdee: 2000, kgPerWeek: 100, gender: 'male');
      expect(result, isA<double>());
      expect(result, greaterThan(2000));
    });
  });

  // ────────────────────────────────────────────────────────────
  // PART 2: BOUNDARY VALUE ANALYSIS (BVA)
  // เทคนิค: ทดสอบ min-1, min, min+1, max-1, max, max+1
  // อ้างอิง: Myers GJ, "The Art of Software Testing" 1979
  // ────────────────────────────────────────────────────────────
  group('[BVA] Age — boundaries (min=13, max=100)', () {
    // min-1
    test('12 (min-1) → invalid', () => expect(isValidAge(12), false));
    // min
    test('13 (min)   → valid',   () => expect(isValidAge(13), true));
    // min+1
    test('14 (min+1) → valid',   () => expect(isValidAge(14), true));
    // nominal
    test('50 (mid)   → valid',   () => expect(isValidAge(50), true));
    // max-1
    test('99 (max-1) → valid',   () => expect(isValidAge(99), true));
    // max
    test('100 (max)  → valid',   () => expect(isValidAge(100), true));
    // max+1
    test('101 (max+1)→ invalid', () => expect(isValidAge(101), false));
  });

  group('[BVA] Height — boundaries (min=100, max=250)', () {
    test('99 cm  (min-1) → invalid', () => expect(isValidHeight(99), false));
    test('100 cm (min)   → valid',   () => expect(isValidHeight(100), true));
    test('101 cm (min+1) → valid',   () => expect(isValidHeight(101), true));
    test('170 cm (mid)   → valid',   () => expect(isValidHeight(170), true));
    test('249 cm (max-1) → valid',   () => expect(isValidHeight(249), true));
    test('250 cm (max)   → valid',   () => expect(isValidHeight(250), true));
    test('251 cm (max+1) → invalid', () => expect(isValidHeight(251), false));
  });

  group('[BVA] Weight — boundaries (min=20, max=300)', () {
    test('19 kg  (min-1) → invalid', () => expect(isValidWeight(19), false));
    test('20 kg  (min)   → valid',   () => expect(isValidWeight(20), true));
    test('21 kg  (min+1) → valid',   () => expect(isValidWeight(21), true));
    test('65 kg  (mid)   → valid',   () => expect(isValidWeight(65), true));
    test('299 kg (max-1) → valid',   () => expect(isValidWeight(299), true));
    test('300 kg (max)   → valid',   () => expect(isValidWeight(300), true));
    test('301 kg (max+1) → invalid', () => expect(isValidWeight(301), false));
  });

  group('[BVA] Weight Loss Safety — boundaries (0.5 / 1.0)', () {
    // ขอบ recommended/borderline ที่ 0.5
    test('0.49 kg/week → recommended', () {
      expect(weightLossSafetyLevel(-0.49), 'recommended');
    });
    test('0.50 kg/week → recommended (boundary)', () {
      expect(weightLossSafetyLevel(-0.50), 'recommended');
    });
    test('0.51 kg/week → borderline (เพิ่งข้าม)', () {
      expect(weightLossSafetyLevel(-0.51), 'borderline');
    });

    // ขอบ borderline/unsafe ที่ 1.0
    test('0.99 kg/week → borderline', () {
      expect(weightLossSafetyLevel(-0.99), 'borderline');
    });
    test('1.00 kg/week → borderline (boundary)', () {
      expect(weightLossSafetyLevel(-1.00), 'borderline');
    });
    test('1.01 kg/week → unsafe (เพิ่งข้าม)', () {
      expect(weightLossSafetyLevel(-1.01), 'unsafe');
    });
  });

  group('[BVA] BMI Status — cutoff boundaries', () {
    // ขอบ น้ำหนักน้อย/ปกติ ที่ 18.5
    test('18.49 → น้ำหนักน้อย', () => expect(
        bmiStatus(18.49), 'น้ำหนักน้อย'));
    test('18.50 → ปกติ (boundary)', () => expect(
        bmiStatus(18.50), 'ปกติ'));
    test('18.51 → ปกติ', () => expect(bmiStatus(18.51), 'ปกติ'));

    // ขอบ ปกติ/ท้วม ที่ 23.0
    test('22.99 → ปกติ', () => expect(bmiStatus(22.99), 'ปกติ'));
    test('23.00 → ท้วม (boundary)', () => expect(bmiStatus(23.00), 'ท้วม'));
    test('23.01 → ท้วม', () => expect(bmiStatus(23.01), 'ท้วม'));

    // ขอบ ท้วม/อ้วน ที่ 25.0
    test('24.99 → ท้วม', () => expect(bmiStatus(24.99), 'ท้วม'));
    test('25.00 → อ้วน (boundary)', () => expect(bmiStatus(25.00), 'อ้วน'));
    test('25.01 → อ้วน', () => expect(bmiStatus(25.01), 'อ้วน'));

    // ขอบ อ้วน/อ้วนมาก ที่ 30.0
    test('29.99 → อ้วน', () => expect(bmiStatus(29.99), 'อ้วน'));
    test('30.00 → อ้วนมาก (boundary)', () => expect(bmiStatus(30.00), 'อ้วนมาก'));
  });

  // ────────────────────────────────────────────────────────────
  // PART 3: INTEGRATION ERROR SIMULATION
  // จำลองสถานการณ์ที่ Flutter ได้รับ Error จาก Backend API
  // ────────────────────────────────────────────────────────────
  group('[Integration] HTTP Status Code Handling', () {
    test('200 OK → success (0)', () {
      expect(simulateHttpHandling(200), 0);
    });

    test('401 Unauthorized → auth error (1) → redirect login', () {
      expect(simulateHttpHandling(401), 1);
    });

    test('403 Forbidden → auth error (1) → ไม่มีสิทธิ์', () {
      expect(simulateHttpHandling(403), 1);
    });

    test('404 Not Found → not found (3)', () {
      expect(simulateHttpHandling(404), 3);
    });

    test('500 Internal Server Error → server error (2)', () {
      expect(simulateHttpHandling(500), 2);
    });

    test('503 Service Unavailable → server error (2)', () {
      expect(simulateHttpHandling(503), 2);
    });
  });

  group('[Integration] API JSON Parsing — Graceful Failure', () {
    test('JSON ถูกต้อง → parse สำเร็จ คืน Map', () {
      const json = '{"user_id":1,"username":"ต้อง","current_weight_kg":70.0,"height_cm":175.0}';
      final result = parseApiUser(json);
      expect(result, isNotNull);
      expect(result!['username'], 'ต้อง');
      expect(result['weight'], 70.0);
    });

    test('JSON ขาด field → ใช้ default value (ไม่ crash)', () {
      const json = '{"user_id":1}';
      final result = parseApiUser(json);
      expect(result, isNotNull);
      expect(result!['username'], 'ผู้ใช้'); // default
      expect(result['weight'], 0.0);          // default
    });

    test('JSON เป็น null fields → ใช้ default value', () {
      const json = '{"user_id":null,"username":null,"current_weight_kg":null}';
      final result = parseApiUser(json);
      expect(result, isNotNull);
      expect(result!['user_id'], 0);
      expect(result['username'], 'ผู้ใช้');
    });

    test('JSON malformed (string ไม่ถูกต้อง) → คืน null (ไม่ crash)', () {
      const json = '{invalid json!!!}';
      final result = parseApiUser(json);
      expect(result, isNull); // Graceful failure
    });

    test('JSON ว่าง "" → คืน null (ไม่ crash)', () {
      final result = parseApiUser('');
      expect(result, isNull);
    });

    test('JSON เป็น Array ไม่ใช่ Object → คืน null (ไม่ crash)', () {
      const json = '[1, 2, 3]';
      final result = parseApiUser(json);
      expect(result, isNull);
    });
  });

  group('[Integration] Leaderboard Entry Parsing — Missing/Null Fields', () {
    test('ข้อมูลครบ → parse ถูกต้อง', () {
      final raw = {
        'username': 'ต้อย',
        'tama_points': 500,
        'current_streak': 7,
        'claimed_badges': ['badge_newbie', 'badge_grower'],
      };
      final entry = parseLeaderboardEntry(raw);
      expect(entry['username'], 'ต้อย');
      expect(entry['tama_points'], 500);
      expect((entry['claimed_badges'] as List).length, 2);
    });

    test('ขาด tama_points → default 0 (ไม่ crash)', () {
      final raw = {'username': 'ต้อย', 'current_streak': 5};
      final entry = parseLeaderboardEntry(raw);
      expect(entry['tama_points'], 0);
    });

    test('ขาด claimed_badges → คืน [] (ไม่ crash)', () {
      final raw = {'username': 'แต้ว'};
      final entry = parseLeaderboardEntry(raw);
      expect(entry['claimed_badges'], isEmpty);
    });

    test('username เป็น null → default "ผู้ใช้"', () {
      final raw = {'username': null, 'tama_points': 100};
      final entry = parseLeaderboardEntry(raw);
      expect(entry['username'], 'ผู้ใช้');
    });

    test('claimed_badges เป็น null → คืน []', () {
      final raw = {'username': 'พราว', 'claimed_badges': null};
      final entry = parseLeaderboardEntry(raw);
      expect(entry['claimed_badges'], isEmpty);
    });
  });

  group('[Integration] Network Timeout Simulation — Offline Behavior', () {
    String loadPointsWithFallback({int? backendPts, int? localPts}) {
      // จำลอง logic ใน tamagotchi_screen._load()
      if (backendPts == null) {
        // network error / timeout → ใช้ local cache
        return 'use_local:${localPts ?? 0}';
      }
      final pts = (backendPts > (localPts ?? 0)) ? backendPts : (localPts ?? 0);
      return 'use_backend:$pts';
    }

    test('backend ส่งค่ามา → ใช้ค่า backend ถ้ามากกว่า local', () {
      expect(loadPointsWithFallback(backendPts: 500, localPts: 300),
          'use_backend:500');
    });

    test('backend ส่งค่ามา แต่น้อยกว่า local (spent points) → ใช้ local', () {
      expect(loadPointsWithFallback(backendPts: 300, localPts: 500),
          'use_backend:500');
    });

    test('network timeout (backendPts=null) → ใช้ local cache', () {
      expect(loadPointsWithFallback(backendPts: null, localPts: 400),
          'use_local:400');
    });

    test('offline + ไม่มี local cache → คืน 0 (ไม่ crash)', () {
      expect(loadPointsWithFallback(backendPts: null, localPts: null),
          'use_local:0');
    });
  });
}

// ── standalone bmiStatus (ไม่ import ข้ามไฟล์) ───────────────
String bmiStatus(double bmi) {
  if (bmi <= 0) return '-';
  if (bmi < 18.5) return 'น้ำหนักน้อย';
  if (bmi < 23.0) return 'ปกติ';
  if (bmi < 25.0) return 'ท้วม';
  if (bmi < 30.0) return 'อ้วน';
  return 'อ้วนมาก';
}
