// ignore_for_file: dangling_library_doc_comments
/// ══════════════════════════════════════════════════════════════
/// E2E Integration Tests — CaloriesGuard
/// ══════════════════════════════════════════════════════════════
///
/// ทดสอบ flow จริงบน device/emulator ผ่าน WidgetTester
/// รัน: flutter test integration_test/app_e2e_test.dart -d <device_id>
///
/// ครอบคลุม:
///   1. Register Screen — email/password validation UI
///   2. Personal Info Screen — height/weight/age validation UI
///   3. BMI display — ค่าที่แสดงผลถูกต้องจาก provider
///
/// หมายเหตุ: tests เหล่านี้ pump widget โดยตรง (ไม่ต้องการ server)
/// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/login_register/screens/register_screen.dart';
import 'package:flutter_application_1/login_register/screens/personal_info_screen.dart';
import 'package:flutter_application_1/providers/user_data_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ── helper: pump screen ────────────────────────────────────
  Widget wrap(Widget child) => ProviderScope(
        child: MaterialApp(home: child),
      );

  // ────────────────────────────────────────────────────────────
  // 1. Register Screen — Validation UI
  // ────────────────────────────────────────────────────────────
  group('[E2E] Register Screen — Form Validation', () {
    testWidgets('กด Done โดยไม่กรอกข้อมูล → แสดง error "กรุณากรอกข้อมูล"',
        (tester) async {
      await tester.pumpWidget(wrap(const RegisterScreen()));
      await tester.pumpAndSettle();

      // กดปุ่ม Done ทันทีโดยไม่กรอก
      final doneBtn = find.text('Done');
      expect(doneBtn, findsOneWidget);
      await tester.tap(doneBtn);
      await tester.pumpAndSettle();

      // ต้องแสดง SnackBar error
      expect(find.text('กรุณากรอกข้อมูลให้ครบถ้วน'), findsOneWidget);
    });

    testWidgets('ใส่ email ไม่มี @ → แสดง error รูปแบบ email', (tester) async {
      await tester.pumpWidget(wrap(const RegisterScreen()));
      await tester.pumpAndSettle();

      // กรอกข้อมูลทุกช่อง แต่ email ผิด
      await tester.enterText(find.byType(TextField).at(0), 'สมชาย');
      await tester.enterText(find.byType(TextField).at(1), 'ใจดี');
      await tester.enterText(find.byType(TextField).at(2), 'notanemail');
      await tester.enterText(find.byType(TextField).at(3), 'Password1!');
      await tester.enterText(find.byType(TextField).at(4), 'Password1!');

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('กรุณากรอกอีเมลให้ถูกต้อง เช่น user@gmail.com'),
          findsOneWidget);
    });

    testWidgets('password < 8 ตัว → แสดง error ความยาว', (tester) async {
      await tester.pumpWidget(wrap(const RegisterScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'สมชาย');
      await tester.enterText(find.byType(TextField).at(1), 'ใจดี');
      await tester.enterText(find.byType(TextField).at(2), 'user@test.com');
      await tester.enterText(find.byType(TextField).at(3), 'abc');
      await tester.enterText(find.byType(TextField).at(4), 'abc');

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('รหัสผ่านต้องมีความยาวอย่างน้อย 8 ตัวอักษร'),
          findsOneWidget);
    });

    testWidgets('password ไม่มีตัวพิมพ์ใหญ่ → แสดง error', (tester) async {
      await tester.pumpWidget(wrap(const RegisterScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'สมชาย');
      await tester.enterText(find.byType(TextField).at(1), 'ใจดี');
      await tester.enterText(find.byType(TextField).at(2), 'user@test.com');
      await tester.enterText(find.byType(TextField).at(3), 'password1!');
      await tester.enterText(find.byType(TextField).at(4), 'password1!');

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('รหัสผ่านต้องมีตัวพิมพ์ใหญ่อย่างน้อย 1 ตัว (A-Z)'),
          findsOneWidget);
    });
  });

  // ────────────────────────────────────────────────────────────
  // 2. Personal Info Screen — Height/Weight/Age Validation UI
  // ────────────────────────────────────────────────────────────
  group('[E2E] Personal Info Screen — Validation', () {
    testWidgets('ไม่กรอกอะไร → แสดง error ข้อมูลไม่ครบ', (tester) async {
      await tester.pumpWidget(wrap(const PersonalInfoScreen()));
      await tester.pumpAndSettle();

      final nextBtn = find.text('ถัดไป');
      expect(nextBtn, findsOneWidget);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      expect(find.text('กรุณากรอกข้อมูลให้ครบถ้วน'), findsOneWidget);
    });

    testWidgets('ส่วนสูง 50 cm (ต่ำกว่า 100) → แสดง error ส่วนสูง',
        (tester) async {
      await tester.pumpWidget(wrap(const PersonalInfoScreen()));
      await tester.pumpAndSettle();

      // กรอกส่วนสูงไม่ถูกต้อง
      await tester.enterText(find.byType(TextField).at(0), '50');
      await tester.enterText(find.byType(TextField).at(1), '60');

      // เลือกวันเกิดก่อน (tap ปุ่ม date picker)
      final datePicker = find.byIcon(Icons.calendar_today);
      if (datePicker.evaluate().isNotEmpty) {
        await tester.tap(datePicker);
        await tester.pumpAndSettle();
        await tester.tap(find.text('ตกลง'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('ถัดไป'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ส่วนสูงต้องอยู่ระหว่าง 100–250 ซม.'), findsOneWidget);
    });

    testWidgets('น้ำหนัก 10 kg (ต่ำกว่า 20) → แสดง error น้ำหนัก',
        (tester) async {
      await tester.pumpWidget(wrap(const PersonalInfoScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), '165');
      await tester.enterText(find.byType(TextField).at(1), '10');

      final datePicker = find.byIcon(Icons.calendar_today);
      if (datePicker.evaluate().isNotEmpty) {
        await tester.tap(datePicker);
        await tester.pumpAndSettle();
        await tester.tap(find.text('ตกลง'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('ถัดไป'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('น้ำหนักต้องอยู่ระหว่าง 20–300 กก.'), findsOneWidget);
    });
  });

  // ────────────────────────────────────────────────────────────
  // 3. BMI Display — ค่าที่ render จาก UserData Provider
  // ────────────────────────────────────────────────────────────
  group('[E2E] BMI Provider Value', () {
    testWidgets('UserData ชาย 70kg 175cm → BMI = 22.86', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(userDataProvider.notifier).setPersonalInfo(
            name: 'ทดสอบ',
            birthDate: DateTime(1999, 1, 1),
            height: 175,
            weight: 70,
          );

      final userData = container.read(userDataProvider);
      expect(userData.bmi, closeTo(22.86, 0.1));
    });

    testWidgets('UserData ชาย 70kg 175cm → BMR = 1573.3 kcal (Asian ×0.94)',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(userDataProvider.notifier)
        ..setPersonalInfo(
          name: 'ทดสอบ',
          birthDate: DateTime(2000, 1, 1),
          height: 175,
          weight: 70,
        )
        ..setGender('male');

      final userData = container.read(userDataProvider);
      // raw Mifflin = 1673.75 × 0.94 = 1573.325
      expect(userData.bmr, closeTo(1573.3, 1.0));
    });

    testWidgets('BMR Asian ต่ำกว่า Mifflin-St Jeor ดิบ เสมอ', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(userDataProvider.notifier)
        ..setPersonalInfo(
          name: 'ทดสอบ',
          birthDate: DateTime(2000, 1, 1),
          height: 175,
          weight: 70,
        )
        ..setGender('male');

      final userData = container.read(userDataProvider);
      final rawMifflin = (10 * 70.0) + (6.25 * 175) - (5 * userData.age) + 5;
      expect(userData.bmr, lessThan(rawMifflin));
    });
  });
}
