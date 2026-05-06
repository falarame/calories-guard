import 'package:flutter/material.dart';

enum BmiRiskBand {
  unknown,
  underweight,
  normal,
  increasedRisk,
  highRisk,
}

class BmiBandData {
  final BmiRiskBand band;
  final double min;
  final double? maxExclusive;
  final String range;
  final String label;
  final String shortLabel;
  final String riskText;
  final String advice;
  final Color color;

  const BmiBandData({
    required this.band,
    required this.min,
    required this.maxExclusive,
    required this.range,
    required this.label,
    required this.shortLabel,
    required this.riskText,
    required this.advice,
    required this.color,
  });

  bool contains(double bmi) {
    if (bmi <= 0) return band == BmiRiskBand.unknown;
    if (bmi < min) return false;
    final max = maxExclusive;
    return max == null || bmi < max;
  }
}

const bmiUnknownBand = BmiBandData(
  band: BmiRiskBand.unknown,
  min: 0,
  maxExclusive: null,
  range: '-',
  label: 'ไม่ทราบ',
  shortLabel: '-',
  riskText: '-',
  advice: 'กรุณากรอกน้ำหนักและส่วนสูงให้ครบก่อนประเมิน BMI',
  color: Colors.grey,
);

const bmiBands = <BmiBandData>[
  BmiBandData(
    band: BmiRiskBand.underweight,
    min: 0,
    maxExclusive: 18.5,
    range: '< 18.5',
    label: 'น้ำหนักน้อยกว่าเกณฑ์',
    shortLabel: 'น้ำหนักน้อย',
    riskText: 'เสี่ยงภาวะขาดสารอาหาร ควรติดตามโภชนาการ',
    advice: 'เน้นพลังงานและโปรตีนให้พอ และติดตามน้ำหนักอย่างสม่ำเสมอ',
    color: Color(0xFF3498DB),
  ),
  BmiBandData(
    band: BmiRiskBand.normal,
    min: 18.5,
    maxExclusive: 23.0,
    range: '18.5 - 22.9',
    label: 'อยู่ในช่วงเหมาะสม',
    shortLabel: 'ปกติ',
    riskText: 'ความเสี่ยงโดยรวมอยู่ในระดับต่ำ',
    advice: 'รักษาพฤติกรรมการกิน การออกกำลังกาย และติดตามแนวโน้มต่อเนื่อง',
    color: Color(0xFF628141),
  ),
  BmiBandData(
    band: BmiRiskBand.increasedRisk,
    min: 23.0,
    maxExclusive: 27.5,
    range: '23.0 - 27.4',
    label: 'เริ่มมีความเสี่ยงเพิ่ม',
    shortLabel: 'เริ่มเสี่ยง',
    riskText: 'เริ่มมีความเสี่ยงเพิ่ม ควรติดตาม/ให้คำแนะนำ',
    advice:
        'ควรติดตามน้ำหนัก รอบเอว และพฤติกรรมการกิน พร้อมตั้งเป้าหมายแบบค่อยเป็นค่อยไป',
    color: Color(0xFFF39C12),
  ),
  BmiBandData(
    band: BmiRiskBand.highRisk,
    min: 27.5,
    maxExclusive: null,
    range: '>= 27.5',
    label: 'ความเสี่ยงสูงขึ้นชัดเจน',
    shortLabel: 'เสี่ยงสูง',
    riskText: 'ความเสี่ยงสูงขึ้นชัดเจน ควรประเมินจริงจังขึ้น',
    advice:
        'ควรประเมินร่วมกับรอบเอว ความดัน น้ำตาล ไขมันในเลือด หรือคำแนะนำจากบุคลากรสุขภาพ',
    color: Color(0xFFE74C3C),
  ),
];

BmiBandData bmiBandData(double bmi) {
  if (bmi <= 0) return bmiUnknownBand;
  for (final band in bmiBands) {
    if (band.contains(bmi)) return band;
  }
  return bmiUnknownBand;
}

String bmiStatusLabel(double bmi) => bmiBandData(bmi).shortLabel;

String bmiRiskAdvice(double bmi) => bmiBandData(bmi).advice;

Color bmiRiskColor(double bmi) => bmiBandData(bmi).color;
