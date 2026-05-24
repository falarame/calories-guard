import 'package:flutter/material.dart';
import '../../utils/bmi_utils.dart';

class BmiCategoryTable extends StatelessWidget {
  final double bmi;
  const BmiCategoryTable({super.key, required this.bmi});

  bool _isMe(int i) {
    if (bmi <= 0) return false;
    return bmiBands[i].contains(bmi);
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
            color: Colors.black.withOpacity(0.05),
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
          ...List.generate(bmiBands.length, (i) {
            final r = bmiBands[i];
            final isMe = _isMe(i);
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isMe
                    ? r.color.withOpacity(0.12)
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
                        fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
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
                        fontWeight: isMe ? FontWeight.w700 : FontWeight.normal,
                        fontFamily: 'Inter'),
                  ),
                ),
                if (isMe)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
