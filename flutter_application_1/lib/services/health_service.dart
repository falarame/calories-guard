import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:url_launcher/url_launcher.dart';

/// Thin wrapper over the `health` plugin for syncing activity data from
/// Samsung Health / Google Fit / Apple Health.
///
/// On Android the data pipeline is:
///   Samsung Health / Google Fit  →  Health Connect  →  health plugin
/// The user must enable each source inside the Health Connect app once
/// (Health Connect → Apps → Samsung Health → Allow all) before this
/// service returns anything. [ensureReady] walks the user through that.
class HealthService {
  static final _health = Health();

  static const List<HealthDataType> _types = [
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.STEPS,
  ];

  static const List<HealthDataAccess> _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  static bool _configured = false;

  /// Call once before any other method. Cheap to call repeatedly.
  static Future<void> _ensureConfigured() async {
    if (kIsWeb) {
      throw UnsupportedError('Health sync is not available on web');
    }
    if (_configured) return;
    try {
      await _health.configure();
      _configured = true;
    } on PlatformException {
      // configure() only throws on unsupported platforms (web/desktop);
      // let the subsequent calls surface a clearer error.
    }
  }

  /// Android-only: returns the install status of Health Connect.
  ///
  /// Possible values from the plugin:
  ///   `HealthConnectSdkStatus.sdkAvailable` — good to go
  ///   `HealthConnectSdkStatus.sdkUnavailable` — device doesn't support it
  ///   `HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired`
  ///     → open Play Store so the user can install/update Health Connect.
  static Future<HealthConnectSdkStatus?> healthConnectStatus() async {
    await _ensureConfigured();
    try {
      return await _health.getHealthConnectSdkStatus();
    } catch (_) {
      return null;
    }
  }

  /// Deep-link to the Play Store listing for Health Connect so the user
  /// can install/update it.
  static Future<void> openHealthConnectInstall() async {
    await _health.installHealthConnect();
  }

  /// Request read permissions for calories/steps.
  ///
  /// Samsung Health syncs some exercise calorie entries to Health Connect as
  /// TOTAL_CALORIES_BURNED rather than ACTIVE_ENERGY_BURNED, so both calorie
  /// records are requested. WORKOUT is intentionally not part of the required
  /// permission set; if workout permission is denied, step/calorie sync should
  /// still work.
  static Future<bool> requestPermissions() async {
    await _ensureConfigured();
    try {
      // `hasPermissions` can return null if the plugin can't determine
      // the state — treat that as "not granted" and re-request.
      final has =
          await _health.hasPermissions(_types, permissions: _permissions);
      if (has == true) return true;
      return await _health.requestAuthorization(_types,
          permissions: _permissions);
    } catch (_) {
      return false;
    }
  }

  /// Bundled setup check. Returns a [HealthReadiness] describing exactly
  /// what the UI should do next so the caller doesn't have to re-derive
  /// "install / permission / ok" logic in every screen.
  static Future<HealthReadiness> ensureReady() async {
    if (kIsWeb) return HealthReadiness.unsupported;
    await _ensureConfigured();
    final status = await healthConnectStatus();
    if (status == HealthConnectSdkStatus.sdkUnavailable) {
      return HealthReadiness.unsupported;
    }
    if (status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
      return HealthReadiness.needsInstall;
    }
    final granted = await requestPermissions();
    return granted ? HealthReadiness.ok : HealthReadiness.permissionDenied;
  }

  static DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static double _sumNumericValues(List<HealthDataPoint> data) {
    double total = 0;
    for (final point in data) {
      final v = point.value;
      if (v is NumericHealthValue) {
        total += v.numericValue.toDouble();
      }
    }
    return total;
  }

  static Future<double> _fetchNumericTotal(
    DateTime date,
    HealthDataType type,
  ) async {
    await _ensureConfigured();
    try {
      final start = _startOfDay(date);
      final end = start.add(const Duration(days: 1));
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [type],
      );
      return _sumNumericValues(data);
    } catch (_) {
      return 0;
    }
  }

  /// Total activity kcal between 00:00 and 23:59:59 of [date] (device local).
  ///
  /// Prefer ACTIVE_ENERGY_BURNED when present. Samsung Health commonly exposes
  /// workout/exercise calories through TOTAL_CALORIES_BURNED, so use that as a
  /// fallback when active energy is empty.
  static Future<double> fetchCaloriesBurned(DateTime date) async {
    final active = await _fetchNumericTotal(
      date,
      HealthDataType.ACTIVE_ENERGY_BURNED,
    );
    if (active > 0) return active;
    return _fetchNumericTotal(date, HealthDataType.TOTAL_CALORIES_BURNED);
  }

  static Future<HealthActivitySummary> fetchActivitySummary(
    DateTime date,
  ) async {
    final activeCalories = await _fetchNumericTotal(
      date,
      HealthDataType.ACTIVE_ENERGY_BURNED,
    );
    final totalCalories = await _fetchNumericTotal(
      date,
      HealthDataType.TOTAL_CALORIES_BURNED,
    );
    final steps = await fetchSteps(date);
    final usesTotalCaloriesFallback = activeCalories <= 0 && totalCalories > 0;

    return HealthActivitySummary(
      caloriesBurned: activeCalories > 0 ? activeCalories : totalCalories,
      steps: steps,
      activeCalories: activeCalories,
      totalCalories: totalCalories,
      usesTotalCaloriesFallback: usesTotalCaloriesFallback,
    );
  }

  static Future<int> fetchSteps(DateTime date) async {
    await _ensureConfigured();
    try {
      final start = _startOfDay(date);
      final end = start.add(const Duration(days: 1));
      final steps = await _health.getTotalStepsInInterval(start, end);
      return steps ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<List<HealthDataPoint>> fetchWorkouts(DateTime date) async {
    await _ensureConfigured();
    try {
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));
      return await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: [HealthDataType.WORKOUT],
      );
    } catch (_) {
      return [];
    }
  }

  /// Open the Samsung Health Play Store listing — useful when [ensureReady]
  /// succeeds but fetchCaloriesBurned returns 0 because Samsung Health
  /// isn't linked to Health Connect yet.
  static Future<void> openSamsungHealthInstall() async {
    final uri = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.sec.android.app.shealth');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class HealthActivitySummary {
  final double caloriesBurned;
  final int steps;
  final double activeCalories;
  final double totalCalories;
  final bool usesTotalCaloriesFallback;

  const HealthActivitySummary({
    required this.caloriesBurned,
    required this.steps,
    required this.activeCalories,
    required this.totalCalories,
    required this.usesTotalCaloriesFallback,
  });
}

/// State machine describing what the app should do next before fetching
/// health data.
enum HealthReadiness {
  /// Device + permissions are good, fetchers will return real data.
  ok,

  /// Device supports Health Connect but it isn't installed / up to date.
  /// UI should surface a "Install Health Connect" CTA.
  needsInstall,

  /// User denied one or more of the required READ permissions.
  /// UI should prompt them to retry or open Health Connect settings.
  permissionDenied,

  /// Device can't run Health Connect at all (most likely <Android 9 or
  /// a non-Google-services build). UI should hide the sync button.
  unsupported,
}
