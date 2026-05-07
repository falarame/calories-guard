// Smoke tests for Calories Guard Flutter app.
//
// The full `MyApp` requires Supabase.initialize() and network access, so
// top-level smoke tests go in other files (e.g. models_test.dart). This file
// keeps a minimal always-green smoke test so `flutter test` has at least
// one suite to run.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp renders placeholder widget',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Calories Guard'))));
    expect(find.text('Calories Guard'), findsOneWidget);
  });
}
