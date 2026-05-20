import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/user_data_provider.dart';

class UnitSettingsScreen extends ConsumerStatefulWidget {
  const UnitSettingsScreen({super.key});

  @override
  ConsumerState<UnitSettingsScreen> createState() => _UnitSettingsScreenState();
}

class _UnitSettingsScreenState extends ConsumerState<UnitSettingsScreen> {
  static const _green = Color(0xFF628141);

  void _updateUnit(String key, String value) {
    if (key == 'unit_weight') {
      ref.read(userDataProvider.notifier).updateUnit(weight: value);
    }
    if (key == 'unit_height') {
      ref.read(userDataProvider.notifier).updateUnit(height: value);
    }
    if (key == 'unit_energy') {
      ref.read(userDataProvider.notifier).updateUnit(energy: value);
    }
    if (key == 'unit_water') {
      ref.read(userDataProvider.notifier).updateUnit(water: value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F0),
      body: Column(children: [
        // ─── Header ────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3D5A27), Color(0xFF628141)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity( 0.15),
                    shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            const Expanded(
              child: Text('ยูนิต',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
            const SizedBox(width: 40),
          ]),
        ),

        // ─── Body ──────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(children: [
              _buildUnitSection(
                icon: Icons.monitor_weight_outlined,
                label: 'น้ำหนัก',
                options: [
                  const _UnitOption('กิโลกรัม (kg)', 'kg'),
                  const _UnitOption('ปอนด์ (lbs)', 'lbs'),
                  const _UnitOption('สโตน (st)', 'st'),
                ],
                currentValue: userData.unitWeight,
                dbKey: 'unit_weight',
              ),
              const SizedBox(height: 16),
              _buildUnitSection(
                icon: Icons.height_rounded,
                label: 'ส่วนสูง',
                options: [
                  const _UnitOption('เซนติเมตร (cm)', 'cm'),
                  const _UnitOption('ฟุต (ft)', 'ft'),
                  const _UnitOption('นิ้ว (in)', 'in'),
                ],
                currentValue: userData.unitHeight,
                dbKey: 'unit_height',
              ),
              const SizedBox(height: 16),
              _buildUnitSection(
                icon: Icons.local_fire_department_outlined,
                label: 'พลังงาน',
                options: [
                  const _UnitOption('กิโลแคลอรี่ (kcal)', 'kcal'),
                  const _UnitOption('แคลอรี่ (cal)', 'cal'),
                  const _UnitOption('กิโลจูล (kJ)', 'kj'),
                ],
                currentValue: userData.unitEnergy,
                dbKey: 'unit_energy',
              ),
              const SizedBox(height: 16),
              _buildUnitSection(
                icon: Icons.water_drop_outlined,
                label: 'น้ำ',
                options: [
                  const _UnitOption('มิลลิลิตร (ml)', 'ml'),
                  const _UnitOption('ลิตร (L)', 'L'),
                  const _UnitOption('ออนซ์ (fl oz)', 'floz'),
                  const _UnitOption('ขวด (bottle)', 'bottle'),
                ],
                currentValue: userData.unitWater,
                dbKey: 'unit_water',
              ),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildUnitSection({
    required IconData icon,
    required String label,
    required List<_UnitOption> options,
    required String currentValue,
    required String dbKey,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Section label
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Row(children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                  letterSpacing: 0.4)),
        ]),
      ),
      // Options card
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity( 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          children: List.generate(options.length, (i) {
            final opt = options[i];
            final isSelected = opt.value == currentValue;
            final isLast = i == options.length - 1;
            return _buildOptionTile(opt, isSelected, isLast, dbKey);
          }),
        ),
      ),
    ]);
  }

  Widget _buildOptionTile(
      _UnitOption opt, bool isSelected, bool isLast, String dbKey) {
    return Column(children: [
      InkWell(
        onTap: () => _updateUnit(dbKey, opt.value),
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(16),
          bottom: isLast ? const Radius.circular(16) : Radius.zero,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? _green.withOpacity( 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(16),
              bottom: isLast ? const Radius.circular(16) : Radius.zero,
            ),
          ),
          child: Row(children: [
            // Radio dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: isSelected ? _green : Colors.grey.shade300,
                    width: 2),
                color: isSelected ? _green : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(opt.label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? _green : Colors.black87)),
            ),
            if (isSelected)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                    color: _green.withOpacity( 0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('ใช้งานอยู่',
                    style: TextStyle(
                        fontSize: 11,
                        color: _green,
                        fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
      ),
      if (!isLast)
        Divider(
            height: 1, indent: 50, endIndent: 16, color: Colors.grey.shade100),
    ]);
  }
}

class _UnitOption {
  final String label;
  final String value;
  const _UnitOption(this.label, this.value);
}
