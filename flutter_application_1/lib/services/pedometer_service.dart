import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps the `pedometer` plugin to expose **daily** step count.
///
/// The plugin counts steps cumulatively since the last device reboot.
/// This service stores a baseline at the start of each day so callers
/// always receive today's step total, not the all-time counter.
class PedometerService {
  PedometerService._();
  static final PedometerService instance = PedometerService._();

  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<PedestrianStatus>? _statusSub;

  final _stepsController = StreamController<int>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  Stream<int> get stepsStream => _stepsController.stream;
  Stream<String> get statusStream => _statusController.stream;

  int _dailySteps = 0;
  int _baseline = 0;
  String _baselineDate = '';
  SharedPreferences? _prefs;

  bool _started = false;

  int get dailySteps => _dailySteps;

  static const _keyBaseline = 'pedometer_baseline';
  static const _keyBaselineDate = 'pedometer_baseline_date';

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Requests ACTIVITY_RECOGNITION permission (Android 10+).
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    final status = await Permission.activityRecognition.request();
    return status.isGranted;
  }

  /// Starts the pedometer stream. Safe to call multiple times — only
  /// initialises once. Silently does nothing on unsupported platforms.
  Future<void> start() async {
    if (_started) return;
    if (!_supported) {
      _stepsController.add(0);
      return;
    }

    final granted = await requestPermission();
    if (!granted) {
      _stepsController.add(0);
      return;
    }

    _prefs = await SharedPreferences.getInstance();
    _baseline = _prefs!.getInt(_keyBaseline) ?? 0;
    _baselineDate = _prefs!.getString(_keyBaselineDate) ?? '';

    _stepSub = Pedometer.stepCountStream.listen(
      _onStep,
      onError: (_) => _stepsController.add(_dailySteps),
      cancelOnError: false,
    );
    _statusSub = Pedometer.pedestrianStatusStream.listen(
      _onStatus,
      onError: (_) => _statusController.add('unknown'),
      cancelOnError: false,
    );

    _started = true;
    _stepsController.add(_dailySteps);
  }

  void _onStep(StepCount event) {
    final today = _dateKey(DateTime.now());

    if (_baselineDate != today) {
      // First step event of a new calendar day — reset the baseline.
      _baseline = event.steps;
      _baselineDate = today;
      _prefs?.setInt(_keyBaseline, _baseline);
      _prefs?.setString(_keyBaselineDate, today);
    } else if (event.steps < _baseline) {
      // Device rebooted mid-day: step counter rolled back to near zero.
      _baseline = 0;
      _prefs?.setInt(_keyBaseline, 0);
    }

    _dailySteps = event.steps - _baseline;
    _stepsController.add(_dailySteps);
  }

  void _onStatus(PedestrianStatus event) {
    _statusController.add(event.status);
  }

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  void stop() {
    _stepSub?.cancel();
    _statusSub?.cancel();
    _started = false;
  }

  // ─── Calorie Calculation (Research-backed) ────────────────────────────────
  //
  // Reference 1:
  //   Ludlow & Weyand (2004). "Energy expenditure of walking and running:
  //   comparison with prediction equations."
  //   Medicine & Science in Sports & Exercise, 36(12):2128-2134.
  //   https://pubmed.ncbi.nlm.nih.gov/15570150/
  //
  // Reference 2:
  //   McArdle, Katch & Katch. Exercise Physiology: Nutrition, Energy, and
  //   Human Performance (8th ed.). Chapter: Energy Expenditure During Rest
  //   and Physical Activity. Energy expenditure coefficient: 0.8 kcal/kg/km.
  //
  // Formula pipeline:
  //   1. StepLength (m) = height_cm × 0.00415  [male]
  //                     = height_cm × 0.00413  [female]
  //   2. Distance (km)  = (steps × stepLength) / 1000
  //   3. Calories (kcal)= distance × weight_kg × 0.8

  static StepCalcResult calculateCaloriesBurned({
    required int steps,
    required double weightKg,
    required double heightCm,
    required String gender,
  }) {
    if (steps <= 0 || weightKg <= 0 || heightCm <= 0) {
      return const StepCalcResult(distanceKm: 0, calories: 0);
    }
    final stepLengthM =
        gender == 'male' ? heightCm * 0.00415 : heightCm * 0.00413;
    final distanceKm = (steps * stepLengthM) / 1000;
    final calories = distanceKm * weightKg * 0.8;
    return StepCalcResult(distanceKm: distanceKm, calories: calories);
  }
}

class StepCalcResult {
  final double distanceKm;
  final double calories;
  const StepCalcResult({required this.distanceKm, required this.calories});
}
