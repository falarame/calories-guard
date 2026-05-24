import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/providers/user_data_provider.dart';

class TdeeFormulaScreen extends ConsumerWidget {
  const TdeeFormulaScreen({super.key});

  // Brand / structural colors
  static const _green = Color(0xFF628141); // brand green — goals / final target
  static const _stepBmr =
      Color(0xFF0369A1); // blue-700 — BMR (physiological baseline)
  static const _stepTdee =
      Color(0xFF7C3AED); // violet-700 — TDEE (activity multiplier)

  // Macro semantic colors — must match recommend_food_screen & home screen
  static const _macroProtein = Color(0xFF2563EB); // blue-600 — muscle/protein
  static const _macroCarbs = Color(0xFFD97706); // amber-600 — energy/carbs
  static const _macroFat = Color(0xFFEA580C); // orange-600 — fat/warmth

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(userDataProvider);

    final String gender = u.gender;
    final int age = u.age;
    final double weight = u.weight;
    final double height = u.height;
    final double bmr = u.bmr;
    final double tdee = u.tdee;
    final int targetCal = u.targetCalories.toInt();
    final int targetProtein = u.targetProtein;
    final int targetCarbs = u.targetCarbs;
    final int targetFat = u.targetFat;
    final String actLevel = u.activityLevel;
    final GoalOption? goal = u.goal;
    final double factor = bmr > 0 ? tdee / bmr : 1.2;
    final double calAdjust = targetCal - tdee;
    final bool fromBackend = u.hasBackendTargetCalories;

    final goalLabel = goal == GoalOption.loseWeight
        ? 'ลดน้ำหนัก'
        : goal == GoalOption.buildMuscle
            ? 'เพิ่มกล้ามเนื้อ'
            : 'คงน้ำหนัก';

    final goalIcon = goal == GoalOption.loseWeight
        ? '📉'
        : goal == GoalOption.buildMuscle
            ? '💪'
            : '⚖️';

    final goalColor = goal == GoalOption.loseWeight
        ? const Color(0xFFE53935)
        : goal == GoalOption.buildMuscle
            ? const Color(0xFF1E88E5)
            : _green;

    final macroP = goal == GoalOption.maintainWeight ? 25 : 30;
    final macroC = goal == GoalOption.loseWeight
        ? 40
        : goal == GoalOption.buildMuscle
            ? 50
            : 45;
    final macroF = goal == GoalOption.buildMuscle ? 20 : 30;

    final actLabelMap = {
      'sedentary': 'นั่งทำงาน ไม่ค่อยเคลื่อนไหว',
      'lightly_active': 'เคลื่อนไหวเล็กน้อย',
      'moderately_active': 'ออกกำลังกายปานกลาง',
      'very_active': 'ออกกำลังกายหนัก',
      'extra_active': 'หนักมาก / งานที่ใช้แรง',
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F8F2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'สูตรคำนวณเป้าหมาย',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Source badge
          if (fromBackend)
            _infoBanner('✅ ค่าเป้าหมายนี้คำนวณจากระบบโดยตรง',
                const Color(0xFFE8EFCF), _green)
          else
            _infoBanner(
                '⚠️ ค่านี้ประมาณจากข้อมูลในเครื่อง อาจแตกต่างจากค่าจริงเล็กน้อย',
                const Color(0xFFFFF8E1),
                const Color(
                    0xFFB45309)), // amber-700 — distinct from carbs color

          const SizedBox(height: 20),

          // ── STEP 1: BMR ──────────────────────────────────────
          _stepCard(
            step: '1',
            title: 'BMR — พลังงานขั้นพื้นฐาน',
            subtitle: 'Mifflin–St Jeor Equation (Asian ×0.94)',
            color: _stepBmr,
            icon: '🔥',
            children: [
              _inputRow('เพศ', gender == 'female' ? '♀ หญิง' : '♂ ชาย'),
              _inputRow('อายุ', '$age ปี'),
              _inputRow('น้ำหนัก', '${weight.toStringAsFixed(1)} กก.'),
              _inputRow('ส่วนสูง', '${height.toStringAsFixed(1)} ซม.'),
              const Divider(height: 20),
              _formulaBox(
                gender == 'female'
                    ? '(10×${weight.toStringAsFixed(0)}) + (6.25×${height.toStringAsFixed(0)}) − (5×$age) − 161'
                    : '(10×${weight.toStringAsFixed(0)}) + (6.25×${height.toStringAsFixed(0)}) − (5×$age) + 5',
              ),
              const SizedBox(height: 4),
              _formulaBox('× 0.94  (Asian BMR correction)'),
              const SizedBox(height: 12),
              _resultRow('BMR', '${bmr.toStringAsFixed(0)} kcal/วัน', _stepBmr),
            ],
          ),

          // ── STEP 2: TDEE ─────────────────────────────────────
          _stepCard(
            step: '2',
            title: 'TDEE — พลังงานที่ใช้จริงต่อวัน',
            subtitle: 'BMR × Activity Factor',
            color: _stepTdee,
            icon: '⚡',
            children: [
              _inputRow('ระดับกิจกรรม', actLabelMap[actLevel] ?? actLevel),
              _inputRow('ตัวคูณ', '×${factor.toStringAsFixed(3)}'),
              const Divider(height: 20),
              _formulaBox(
                  '${bmr.toStringAsFixed(0)} × ${factor.toStringAsFixed(3)}'),
              const SizedBox(height: 12),
              _resultRow(
                  'TDEE', '${tdee.toStringAsFixed(0)} kcal/วัน', _stepTdee),
            ],
          ),

          // ── STEP 3: Goal Adjustment ───────────────────────────
          _stepCard(
            step: '3',
            title: 'การปรับตามเป้าหมาย',
            subtitle: goalLabel,
            color: goalColor,
            icon: goalIcon,
            children: [
              _inputRow('เป้าหมาย', '$goalIcon $goalLabel'),
              if (goal != GoalOption.maintainWeight) ...[
                _inputRow(
                  'การปรับแคลอรี่',
                  calAdjust >= 0
                      ? '+${calAdjust.toStringAsFixed(0)} kcal/วัน'
                      : '${calAdjust.toStringAsFixed(0)} kcal/วัน',
                  valueColor: calAdjust < 0
                      ? const Color(
                          0xFFEA580C) // orange — deficit (lose weight)
                      : const Color(
                          0xFF2563EB), // blue — surplus (build muscle)
                ),
              ],
              const Divider(height: 20),
              _macroRatioRow(macroP, macroC, macroF, goalColor),
            ],
          ),

          // ── STEP 4: Final Target ──────────────────────────────
          _stepCard(
            step: '4',
            title: 'เป้าหมายของคุณ',
            subtitle: 'ค่าที่แอปใช้แสดงผลทุกวัน',
            color: _green,
            icon: '🎯',
            children: [
              _bigResultRow('🔥 แคลอรี่', '$targetCal kcal/วัน', _green),
              const SizedBox(height: 8),
              Row(children: [
                _macroResultChip(
                    '🥩 โปรตีน', '$targetProtein g', _macroProtein),
                const SizedBox(width: 8),
                _macroResultChip('🍚 คาร์บ', '$targetCarbs g', _macroCarbs),
                const SizedBox(width: 8),
                _macroResultChip('🥑 ไขมัน', '$targetFat g', _macroFat),
              ]),
            ],
          ),

          _stepCard(
            step: 'Σ',
            title: 'สูตรทั้งหมดที่ใช้ในแอพ',
            subtitle: 'อ้างอิงค่าที่ใช้คำนวณใน Calories Guard',
            color: const Color(0xFF4B5563),
            icon: '🧮',
            children: [
              _formulaItem(
                'อายุ',
                'ปีปัจจุบัน − ปีเกิด แล้วลบ 1 ถ้ายังไม่ถึงวันเกิดปีนี้',
              ),
              _formulaItem(
                'BMI',
                'น้ำหนัก(kg) ÷ (ส่วนสูง(m) × ส่วนสูง(m))',
              ),
              _formulaItem(
                'BMR ชาย',
                '[(10×น้ำหนัก) + (6.25×ส่วนสูง) − (5×อายุ) + 5] × 0.94',
              ),
              _formulaItem(
                'BMR หญิง',
                '[(10×น้ำหนัก) + (6.25×ส่วนสูง) − (5×อายุ) − 161] × 0.94',
              ),
              _formulaItem(
                'TDEE',
                'BMR × Activity Factor (1.2, 1.375, 1.55, 1.725, 1.9)',
              ),
              _formulaItem(
                'เป้าหมายแคลอรี่',
                'TDEE + (kg ต่อสัปดาห์ × 1100)',
              ),
              _formulaItem(
                'ขอบล่างความปลอดภัยจากระบบ',
                'ชาย: max(BMR, 1500), หญิง: max(BMR, 1200)',
              ),
              _formulaItem(
                'kg ต่อสัปดาห์',
                '(น้ำหนักเป้าหมาย − น้ำหนักปัจจุบัน) ÷ จำนวนสัปดาห์',
              ),
              _formulaItem(
                'โปรตีนจาก backend',
                'ลดน้ำหนัก: น้ำหนัก×1.8g, คงน้ำหนัก: ×1.6g, เพิ่มกล้าม: ×2.0g',
              ),
              _formulaItem(
                'ไขมันจาก backend',
                'ลดน้ำหนัก: น้ำหนัก×0.8g, คงน้ำหนัก/เพิ่มกล้าม: ×1.0g',
              ),
              _formulaItem(
                'คาร์บจาก backend',
                '(แคลอรี่เป้าหมาย − โปรตีน×4 − ไขมัน×9) ÷ 4',
              ),
              _formulaItem(
                'โปรตีน fallback ในเครื่อง',
                '(แคลอรี่เป้าหมาย × สัดส่วนโปรตีน) ÷ 4',
              ),
              _formulaItem(
                'คาร์บ fallback ในเครื่อง',
                '(แคลอรี่เป้าหมาย × สัดส่วนคาร์บ) ÷ 4',
              ),
              _formulaItem(
                'ไขมัน fallback ในเครื่อง',
                '(แคลอรี่เป้าหมาย × สัดส่วนไขมัน) ÷ 9',
              ),
              _formulaItem(
                'แคลอรี่อาหารในมื้อ',
                'ผลรวมของ (จำนวนที่กิน × kcal ต่อหน่วย) ทุกเมนู',
              ),
              _formulaItem(
                'โปรตีน/คาร์บ/ไขมันในมื้อ',
                'ผลรวมของ (จำนวนที่กิน × macro ต่อหน่วย) ทุกเมนู',
              ),
              _formulaItem(
                'น้ำดื่ม',
                '1 แก้ว = 250 ml, เครื่องดื่มที่ไม่มีแอลกอฮอล์นับรวมตาม ml',
              ),
              const SizedBox(height: 8),
              _infoBanner(
                fromBackend
                    ? 'ค่าบางรายการอาจถูก override จาก backend เพื่อให้ตรงกับข้อมูลล่าสุดในฐานข้อมูล'
                    : 'ถ้ายังไม่มีค่าจาก backend แอพจะใช้สูตรประมาณจากข้อมูลในเครื่อง',
                const Color(0xFFF3F4F6),
                const Color(0xFF4B5563),
              ),
            ],
          ),

          const SizedBox(height: 8),
          _infoBanner(
            '💡 ต้องการปรับเป้าหมาย? ไปที่ แก้ไขโปรไฟล์',
            const Color(0xFFE8EFCF),
            _green,
          ),
        ]),
      ),
    );
  }

  Widget _infoBanner(String text, Color bg, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(text,
          style: TextStyle(
              fontSize: 12, color: textColor, fontWeight: FontWeight.w500)),
    );
  }

  Widget _stepCard({
    required String step,
    required String title,
    required String subtitle,
    required Color color,
    required String icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Center(
                child: Text(step,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(icon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ]),
              Text(subtitle,
                  style: TextStyle(
                      fontSize: 11, color: color.withOpacity(0.7))),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ]),
    );
  }

  Widget _inputRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600))),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87)),
      ]),
    );
  }

  Widget _formulaBox(String formula) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(formula,
          style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: Colors.blueGrey.shade700)),
    );
  }

  Widget _formulaItem(String label, String formula) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151))),
        const SizedBox(height: 4),
        _formulaBox(formula),
      ]),
    );
  }

  Widget _resultRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ),
      ],
    );
  }

  Widget _bigResultRow(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _macroResultChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }

  Widget _macroRatioRow(int p, int c, int f, Color color) {
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('สัดส่วน Macro',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text('P $p% : C $c% : F $f%',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Row(children: [
          _ratioBar(p.toDouble(), _macroProtein),
          _ratioBar(c.toDouble(), _macroCarbs),
          _ratioBar(f.toDouble(), _macroFat),
        ]),
      ),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _ratioLabel('🥩 โปรตีน $p%', _macroProtein),
        _ratioLabel('🍚 คาร์บ $c%', _macroCarbs),
        _ratioLabel('🥑 ไขมัน $f%', _macroFat),
      ]),
    ]);
  }

  Widget _ratioBar(double ratio, Color color) {
    return Expanded(
      flex: ratio.toInt(),
      child: Container(height: 10, color: color),
    );
  }

  Widget _ratioLabel(String text, Color color) {
    return Text(text,
        style:
            TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600));
  }
}
