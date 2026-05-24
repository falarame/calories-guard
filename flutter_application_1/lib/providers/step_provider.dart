import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/health_service.dart';
import '../services/pedometer_service.dart';

/// Combines Health Connect (full-day history) with live pedometer updates.
/// Health Connect covers steps taken before the app was opened;
/// the pedometer adds real-time increments on top.
final stepCountProvider = StreamProvider<int>((ref) async* {
  // Fetch today's steps already stored in Health Connect (background steps).
  int healthSteps = 0;
  try {
    healthSteps = await HealthService.fetchSteps(DateTime.now());
  } catch (_) {}

  // Emit Health Connect value first so the UI shows something immediately.
  yield healthSteps;

  // Then keep updating with pedometer stream, always showing the higher value.
  await for (final pedometerSteps in PedometerService.instance.stepsStream) {
    yield pedometerSteps > healthSteps ? pedometerSteps : healthSteps;
  }
});

final pedestrianStatusProvider = StreamProvider<String>((ref) {
  return PedometerService.instance.statusStream;
});
