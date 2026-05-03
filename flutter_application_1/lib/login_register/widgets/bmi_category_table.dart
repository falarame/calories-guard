import 'package:flutter/material.dart';

class _BmiCategoryRow {
  final String range;
  final String label;
  final Color color;
  const _BmiCategoryRow(this.range, this.label, this.color);
}

class BmiCategoryTable extends StatelessWidget {
  final double bmi;
  const BmiCategoryTable({super.key, required this.bmi});

  static const List<_BmiCategoryRow> _rows = [
    _BmiCategoryRow('< 18.5', 'ผอม / น้ำหนักน้อย', Color(0xFF3498DB)),
    _BmiCategoryRow('18.5 - 22.9', 'ปกติ', Color(0xFF628141)),
    _BmiCategoryRow('23.0 - 24.9', 'น้ำหนักเกิน', Color(0xFFF39C12)),
    _BmiCategoryRow('25.0 - 29.9', 'อ้วนระดับ 1', Color(0xFFE67E22)),
    _BmiCategoryRow('≥ 30.0', 'อ้วนระดับ 2', Color(0xFFE74C3C)),
  ];

  bool _isMe(int i) {
    if (bmi <= 0) return false;
    switch (i) {
      case 0:
        return bmi < 18.5;
      case 1:
        return bmi >= 18.5 && bmi < 23.0;
      case 2:
        return bmi >= 23.0 && bmi < 25.0;
      case 3:
        return bmi >= 25.0 && bmi < 30.0;
      case 4:
        return bmi >= 30.0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.speed_rounded, size: 16, color: Color(0xFF628141)),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'เกณฑ์ BMI (มาตรฐานสำหรับชาวเอเชีย)',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter'),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          ...List.generate(_rows.length, (i) {
            final r = _rows[i];
            final isMe = _isMe(i);
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isMe
                    ? r.color.withValues(alpha: 0.12)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: isMe ? Border.all(color: r.color, width: 1.4) : null,
              ),
              child: Row(children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration:
                      BoxDecoration(color: r.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 90,
                  child: Text(
                    r.range,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isMe ? FontWeight.bold : FontWeight.w500,
                        color: isMe ? r.color : Colors.black87,
                        fontFamily: 'Inter'),
                  ),
                ),
                Expanded(
                  child: Text(
                    r.label,
                    style: TextStyle(
                        fontSize: 12,
                        color: isMe ? r.color : Colors.grey.shade700,
                        fontWeight:
                            isMe ? FontWeight.w700 : FontWeight.normal,
                        fontFamily: 'Inter'),
                  ),
                ),
                if (isMe)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: r.color,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'คุณอยู่ตรงนี้',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter'),
                    ),
                  ),
              ]),
            );
          }),
        ],
      ),
    );
  }
}
