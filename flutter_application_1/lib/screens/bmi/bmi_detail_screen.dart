import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../utils/bmi_utils.dart';

class BmiDetailScreen extends StatefulWidget {
  final double currentBmi;
  final double weightKg;
  final double heightCm;

  const BmiDetailScreen({
    super.key,
    required this.currentBmi,
    required this.weightKg,
    required this.heightCm,
  });

  @override
  State<BmiDetailScreen> createState() => _BmiDetailScreenState();
}

class _BmiDetailScreenState extends State<BmiDetailScreen>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF628141);
  static const _greenDark = Color(0xFF3D5A27);

  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  double? _calcBmi;
  late AnimationController _gaugeAnim;
  late Animation<double> _gaugeValue;

  @override
  void initState() {
    super.initState();
    _weightCtrl.text = widget.weightKg.toStringAsFixed(1);
    _heightCtrl.text = widget.heightCm.toStringAsFixed(0);

    _gaugeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _gaugeValue = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _gaugeAnim, curve: Curves.easeOut),
    );
    _gaugeAnim.forward();
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _gaugeAnim.dispose();
    super.dispose();
  }

  // ─── BMI helpers ───────────────────────────────────────────────────────────

  double _computeBmi(double weight, double height) {
    if (height <= 0) return 0;
    final h = height / 100;
    return weight / (h * h);
  }

  Color _bmiColor(double bmi) => bmiRiskColor(bmi);

  void _calculate() {
    final w = double.tryParse(_weightCtrl.text);
    final h = double.tryParse(_heightCtrl.text);
    if (w != null && h != null && w > 0 && h > 0) {
      setState(() {
        _calcBmi = _computeBmi(w, h);
        _gaugeAnim.reset();
        _gaugeAnim.forward();
      });
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final displayBmi = _calcBmi ?? widget.currentBmi;
    final color = _bmiColor(displayBmi);
    final catData = bmiBandData(displayBmi);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F0),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(displayBmi, color, catData),
            const SizedBox(height: 20),
            _buildFormulaCard(),
            const SizedBox(height: 16),
            _buildGaugeCard(displayBmi, color, catData),
            const SizedBox(height: 16),
            _buildTableCard(),
            const SizedBox(height: 16),
            _buildCalculatorCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(double bmi, Color color, BmiBandData catData) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_greenDark, _green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 32),
      child: Column(children: [
        // Back row
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          const Text('ดัชนีมวลกาย (BMI)',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ]),
        const SizedBox(height: 28),
        // BMI big display
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Column(children: [
            Text(
              bmi > 0 ? bmi.toStringAsFixed(1) : '-',
              style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1),
            ),
            const Text('kg/m²',
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(width: 28),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(catData.label,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
            const SizedBox(height: 8),
            Text(catData.riskText,
                style: const TextStyle(fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 4),
            Text(
              '${widget.weightKg.toStringAsFixed(1)} กก. · ${widget.heightCm.toStringAsFixed(0)} ซม.',
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
          ]),
        ]),
      ]),
    );
  }

  // ─── Formula card ──────────────────────────────────────────────────────────

  Widget _buildFormulaCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: _green.withOpacity(0.1), shape: BoxShape.circle),
              child:
                  const Icon(Icons.calculate_outlined, size: 18, color: _green),
            ),
            const SizedBox(width: 12),
            const Text('สูตรคำนวณ BMI',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          // Formula box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7E8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _green.withOpacity(0.3)),
            ),
            child: Column(children: [
              const Text(
                'BMI  =  น้ำหนัก (กก.)',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _greenDark),
              ),
              Container(
                  width: 220,
                  height: 2,
                  color: _greenDark,
                  margin: const EdgeInsets.symmetric(vertical: 4)),
              const Text(
                'ส่วนสูง (ม.) × ส่วนสูง (ม.)',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _greenDark),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          // Example with user's data
          const Text('ตัวอย่างของคุณ:',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'BMI = ${widget.weightKg.toStringAsFixed(1)} ÷ '
              '(${(widget.heightCm / 100).toStringAsFixed(2)} × ${(widget.heightCm / 100).toStringAsFixed(2)})'
              '\n     = ${widget.currentBmi.toStringAsFixed(2)} kg/m²',
              style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                  color: Colors.black87,
                  height: 1.6),
            ),
          ),
        ]),
      ),
    );
  }

  // ─── Gauge card ────────────────────────────────────────────────────────────

  Widget _buildGaugeCard(double bmi, Color color, BmiBandData catData) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('ระดับ BMI ของคุณ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: AnimatedBuilder(
              animation: _gaugeValue,
              builder: (_, __) {
                return CustomPaint(
                  painter: _BmiGaugePainter(
                    bmi: bmi,
                    animValue: _gaugeValue.value,
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            bmi > 0 ? bmi.toStringAsFixed(1) : '-',
                            style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: color),
                          ),
                          Text(catData.label,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: color)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Scale labels
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('10', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('18.5',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('23', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('27.5',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text('40', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ─── Classification table ──────────────────────────────────────────────────

  Widget _buildTableCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: _green.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.table_chart_outlined,
                    size: 18, color: _green),
              ),
              const SizedBox(width: 12),
              const Text('เกณฑ์ค่า BMI (WHO อ้างอิงคนเอเชีย)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
          ),
          // Table header
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(children: [
              Expanded(
                  flex: 3,
                  child: Text('การแปรผล',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold))),
              Expanded(
                  flex: 2,
                  child: Text('ค่า BMI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold))),
            ]),
          ),
          const SizedBox(height: 8),
          // Table rows
          ...bmiBands.map((r) {
            final userBmi = _calcBmi ?? widget.currentBmi;
            final isUser = r.contains(userBmi);
            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? r.color.withOpacity(0.12)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: isUser ? Border.all(color: r.color, width: 1.5) : null,
              ),
              child: Row(children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: r.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(r.label,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isUser
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isUser ? r.color : Colors.black87)),
                        ),
                      ]),
                      Padding(
                        padding: const EdgeInsets.only(left: 16, top: 2),
                        child: Text(r.riskText,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade500)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(r.range,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isUser ? r.color : Colors.black54)),
                      if (isUser) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.person_pin_rounded,
                            size: 14, color: r.color),
                      ],
                    ],
                  ),
                ),
              ]),
            );
          }),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              '* เกณฑ์สำหรับผู้ใหญ่อายุ 18 ปีขึ้นไป อ้างอิง WHO / กรมอนามัย',
              style: TextStyle(
                  fontSize: 11, color: Colors.grey.shade400, height: 1.4),
            ),
          ),
        ]),
      ),
    );
  }

  // ─── Calculator card ────────────────────────────────────────────────────────

  Widget _buildCalculatorCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: _green.withOpacity(0.1), shape: BoxShape.circle),
              child:
                  const Icon(Icons.edit_note_rounded, size: 18, color: _green),
            ),
            const SizedBox(width: 12),
            const Text('คำนวณ BMI ด้วยตัวเอง',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 18),
          // Input fields
          Row(children: [
            Expanded(child: _inputField(_weightCtrl, 'น้ำหนัก (กก.)', 'kg')),
            const SizedBox(width: 12),
            Expanded(child: _inputField(_heightCtrl, 'ส่วนสูง (ซม.)', 'cm')),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.calculate_rounded),
              label: const Text('คำนวณ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
            ),
          ),
          if (_calcBmi != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _bmiColor(_calcBmi!).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _bmiColor(_calcBmi!).withOpacity(0.4)),
              ),
              child: Column(children: [
                Text(
                  'BMI ของคุณ = ${_calcBmi!.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _bmiColor(_calcBmi!)),
                ),
                const SizedBox(height: 4),
                Text(
                  bmiBandData(_calcBmi!).label,
                  style: TextStyle(
                      fontSize: 14,
                      color: _bmiColor(_calcBmi!),
                      fontWeight: FontWeight.w500),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String label, String suffix) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          suffixText: suffix,
          suffixStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          filled: true,
          fillColor: const Color(0xFFF5F7F0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _green, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    ]);
  }
}

// ─── BMI Gauge Painter ─────────────────────────────────────────────────────

class _BmiGaugePainter extends CustomPainter {
  final double bmi;
  final double animValue;

  _BmiGaugePainter({required this.bmi, required this.animValue});

  static const _zones = [
    _Zone(10.0, 18.5, Color(0xFF3498DB)), // underweight
    _Zone(18.5, 23.0, Color(0xFF628141)), // normal
    _Zone(23.0, 27.5, Color(0xFFF39C12)), // increased risk
    _Zone(27.5, 40.0, Color(0xFFE74C3C)), // high risk
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.85;
    final r = size.width * 0.42;
    const strokeW = 22.0;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);

    // Draw each zone arc
    for (final zone in _zones) {
      final startAngle = math.pi + math.pi * (zone.min - 10) / 30;
      final sweepAngle = math.pi * (zone.max - zone.min) / 30;
      final paint = Paint()
        ..color = zone.color.withOpacity(0.3)
        ..strokeWidth = strokeW
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }

    // Animated filled zones up to BMI
    final animBmi = 10.0 + (bmi.clamp(10.0, 40.0) - 10.0) * animValue;
    for (final zone in _zones) {
      if (animBmi <= zone.min) break;
      final zoneEnd = animBmi < zone.max ? animBmi : zone.max;
      final startAngle = math.pi + math.pi * (zone.min - 10) / 30;
      final sweepAngle = math.pi * (zoneEnd - zone.min) / 30;
      final paint = Paint()
        ..color = zone.color
        ..strokeWidth = strokeW
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }

    // Needle
    if (bmi > 0) {
      final angle = math.pi + math.pi * (animBmi - 10) / 30;
      final needleX = cx + (r) * math.cos(angle);
      final needleY = cy + (r) * math.sin(angle);
      final needlePaint = Paint()
        ..color = Colors.black87
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx, cy), Offset(needleX, needleY), needlePaint);
      canvas.drawCircle(Offset(cx, cy), 6, Paint()..color = Colors.black87);
      canvas.drawCircle(Offset(cx, cy), 4, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_BmiGaugePainter old) =>
      old.bmi != bmi || old.animValue != animValue;
}

class _Zone {
  final double min;
  final double max;
  final Color color;
  const _Zone(this.min, this.max, this.color);
}
