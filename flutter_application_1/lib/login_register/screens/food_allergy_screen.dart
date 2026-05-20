import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/services/api_client.dart';
import '/providers/user_data_provider.dart';
import 'activity_level_screen.dart';

class FoodAllergyScreen extends ConsumerStatefulWidget {
  /// isEditing = true เมื่อเปิดจากโปรไฟล์ (ไม่ใช่ register flow)
  final bool isEditing;
  const FoodAllergyScreen({super.key, this.isEditing = false});

  @override
  ConsumerState<FoodAllergyScreen> createState() => _FoodAllergyScreenState();
}

class _FoodAllergyScreenState extends ConsumerState<FoodAllergyScreen> {
  static const _green = Color(0xFF628141);
  static const _greenL = Color(0xFFE8EFCF);
  static const _selected = Color(0xFFE67E22); // สีส้มตอนเลือก

  List<Map<String, dynamic>> _flags = [];
  Set<int> _selectedIds = {};
  bool _noAllergies = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMsg;

  // icon + color mapping ตามชื่อ allergy flag
  final List<_AllergyMeta> _metaList = const [
    _AllergyMeta('ถั่วลิสง', Icons.scatter_plot, Color(0xFFD97706)),
    _AllergyMeta('อาหารทะเล', Icons.dinner_dining, Color(0xFF0369A1)),
    _AllergyMeta('ปลา', Icons.set_meal, Color(0xFF0284C7)),
    _AllergyMeta('นม', Icons.local_drink, Color(0xFF7C3AED)),
    _AllergyMeta('ไข่', Icons.egg_alt, Color(0xFFD97706)),
    _AllergyMeta('กลูเตน', Icons.bakery_dining, Color(0xFF92400E)),
    _AllergyMeta('ถั่วเหลือง', Icons.eco, Color(0xFF15803D)),
    _AllergyMeta('ถั่วต้นไม้', Icons.forest, Color(0xFF166534)),
    _AllergyMeta('งา', Icons.grain, Color(0xFFB45309)),
    _AllergyMeta('แล็กโทส', Icons.no_food, Color(0xFF6D28D9)),
  ];

  _AllergyMeta _metaFor(String name) {
    for (final m in _metaList) {
      if (name.contains(m.keyword)) return m;
    }
    return const _AllergyMeta('', Icons.restaurant, Color(0xFF628141));
  }

  @override
  void initState() {
    super.initState();
    _loadFlags();
  }

  Future<void> _loadFlags() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      final res = await ApiClient().get('/allergy_flags');

      if (res.statusCode == 200) {
        final data =
            (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
        setState(() => _flags = data);

        final userId = ref.read(userDataProvider).userId;
        if (widget.isEditing && userId != 0) {
          // โหลด allergy ปัจจุบันของ user
          final r2 = await ApiClient().get('/users/$userId/allergies');
          if (r2.statusCode == 200) {
            final d2 = jsonDecode(r2.body);
            final ids = (d2['flag_ids'] as List).cast<int>();
            setState(() {
              _selectedIds = ids.toSet();
              _noAllergies = ids.isEmpty;
            });
          }
        } else {
          final existing = ref.read(userDataProvider).allergyFlagIds;
          if (existing.isNotEmpty) {
            setState(() => _selectedIds = existing.toSet());
          }
        }
      } else {
        setState(() => _errorMsg = 'โหลดข้อมูลไม่สำเร็จ (${res.statusCode})');
      }
    } catch (e) {
      setState(() => _errorMsg = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    final userId = ref.read(userDataProvider).userId;

    // ยัง register ไม่เสร็จ → เก็บไว้ใน Provider ก่อน
    if (userId == 0) {
      ref.read(userDataProvider.notifier).setAllergies(_selectedIds.toList());
      _proceed();
      return;
    }

    setState(() => _isSaving = true);
    try {
      final res = await ApiClient().post(
        '/users/$userId/allergies',
        body: {'flag_ids': _selectedIds.toList()},
      );
      if (res.statusCode == 200) {
        ref.read(userDataProvider.notifier).setAllergies(_selectedIds.toList());
        if (widget.isEditing && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('บันทึกข้อมูลการแพ้อาหารแล้ว'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          _proceed();
        }
      } else {
        throw Exception('Save failed: ${res.statusCode}');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => _isSaving = false);
  }

  void _proceed() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ActivityLevelScreen()),
    );
  }

  void _toggleFlag(int flagId) {
    setState(() {
      _noAllergies = false;
      if (_selectedIds.contains(flagId)) {
        _selectedIds.remove(flagId);
      } else {
        _selectedIds.add(flagId);
      }
    });
  }

  void _toggleNoAllergies() {
    setState(() {
      _noAllergies = !_noAllergies;
      if (_noAllergies) _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canProceed = _selectedIds.isNotEmpty || _noAllergies;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: widget.isEditing
            ? const Text('แก้ไขการแพ้อาหาร',
                style: TextStyle(fontFamily: 'Inter', color: Colors.black))
            : ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: 200,
                  height: 8,
                  child: LinearProgressIndicator(
                    value: 0.5,
                    backgroundColor: Colors.grey.shade200,
                    color: _green,
                  ),
                ),
              ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : _errorMsg != null
              ? _buildError()
              : _buildContent(canProceed),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text(_errorMsg!,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _loadFlags,
          icon: const Icon(Icons.refresh),
          label: const Text('ลองใหม่'),
          style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
        ),
      ]),
    );
  }

  Widget _buildContent(bool canProceed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            'คุณแพ้อาหารประเภทไหน?',
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          const SizedBox(height: 8),
          Text(
            'เลือกอาหารที่คุณแพ้เพื่อให้เราแนะนำเมนูที่ปลอดภัยสำหรับคุณ',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          ),
          // แสดงจำนวนที่เลือก
          if (_selectedIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: _greenL, borderRadius: BorderRadius.circular(99)),
              child: Text(
                'เลือกแล้ว ${_selectedIds.length} รายการ',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _green),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: _flags.isEmpty
                ? Center(
                    child: Text('ไม่พบข้อมูล',
                        style: TextStyle(color: Colors.grey.shade400)))
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _flags.length,
                    itemBuilder: (_, i) {
                      final flag = _flags[i];
                      final id = flag['flag_id'] as int;
                      final selected = _selectedIds.contains(id);
                      return _buildCard(flag, selected);
                    },
                  ),
          ),
          const SizedBox(height: 12),
          _buildNoAllergyOption(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: canProceed && !_isSaving ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      widget.isEditing ? 'บันทึก' : 'ถัดไป',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> flag, bool selected) {
    final name = flag['name'] as String? ?? '';
    final desc = flag['description'] as String? ?? '';
    final meta = _metaFor(name);

    return InkWell(
      onTap: () => _toggleFlag(flag['flag_id'] as int),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? _selected.withOpacity( 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? _selected : Colors.grey.shade200, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity( 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Stack(children: [
          // checkmark มุมขวาบน
          if (selected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                    color: _selected, shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
            ),
          // content กลางการ์ด
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected
                          ? _selected.withOpacity( 0.15)
                          : Colors.grey.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(meta.icon,
                        size: 28,
                        color: selected ? _selected : Colors.grey.shade400),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                      color: selected ? _selected : Colors.black87,
                    ),
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      desc,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildNoAllergyOption() {
    return InkWell(
      onTap: _toggleNoAllergies,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: _noAllergies ? _greenL : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: _noAllergies ? _green : Colors.grey.shade200, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'ไม่มีอาหารที่ฉันแพ้',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        _noAllergies ? FontWeight.bold : FontWeight.normal),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: _noAllergies ? _green : Colors.grey.shade300,
                    width: 2),
                color: _noAllergies ? _green : Colors.transparent,
              ),
              child: _noAllergies
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AllergyMeta {
  final String keyword;
  final IconData icon;
  final Color color;
  const _AllergyMeta(this.keyword, this.icon, this.color);
}
