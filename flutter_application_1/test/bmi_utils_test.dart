import 'package:flutter_application_1/utils/bmi_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BMI Asian risk action points', () {
    test('23.0 starts increased-risk advice', () {
      final data = bmiBandData(23.0);

      expect(data.band, BmiRiskBand.increasedRisk);
      expect(data.shortLabel, 'เริ่มเสี่ยง');
      expect(data.riskText, contains('เริ่มมีความเสี่ยงเพิ่ม'));
      expect(data.riskText, contains('ควรติดตาม'));
    });

    test('27.5 starts high-risk advice', () {
      final data = bmiBandData(27.5);

      expect(data.band, BmiRiskBand.highRisk);
      expect(data.shortLabel, 'เสี่ยงสูง');
      expect(data.riskText, contains('ความเสี่ยงสูงขึ้นชัดเจน'));
      expect(data.riskText, contains('ควรประเมินจริงจังขึ้น'));
    });

    test('boundaries remain stable around 23.0 and 27.5', () {
      expect(bmiStatusLabel(22.99), 'ปกติ');
      expect(bmiStatusLabel(23.00), 'เริ่มเสี่ยง');
      expect(bmiStatusLabel(27.49), 'เริ่มเสี่ยง');
      expect(bmiStatusLabel(27.50), 'เสี่ยงสูง');
    });
  });
}
