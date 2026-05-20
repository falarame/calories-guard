import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/pedometer_service.dart';

final stepCountProvider = StreamProvider<int>((ref) {
  return PedometerService.instance.stepsStream;
});

final pedestrianStatusProvider = StreamProvider<String>((ref) {
  return PedometerService.instance.statusStream;
});
