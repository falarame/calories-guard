import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_client.dart';

/// Bottom sheet: user พิมพ์ข้อความอิสระเช่น
///   "มื้อเช้ากินข้าวผัดกะเพรา 1 จาน ต้มยำกุ้ง ครึ่งถ้วย"
///
/// AI (backend /api/meals/estimate → pythainlp + DB-backed dictionary +
/// optional LLM estimate สำหรับเมนูที่ไม่มีในฐานข้อมูล) จะ
/// คืนรายการอาหาร + โภชนาการ. ถ้าเมนูไหนยังไม่มีในฐานข้อมูล backend จะ
/// auto-add ไปยัง temp_food ให้ admin ตรวจสอบแยกต่างหาก
///
/// เมื่อ user กด "บันทึกมื้อนี้" เราจะ POST /meals/{user_id} พร้อม
/// รายการที่ confirm แล้ว
class AiMealEstimateSheet extends StatefulWidget {
  final int userId;
  final String mealType; // breakfast|lunch|dinner|snack
  final DateTime date;
  final VoidCallback? onSaved;

  const AiMealEstimateSheet({
    super.key,
    required this.userId,
    required this.mealType,
    required this.date,
    this.onSaved,
  });

  @override
  State<AiMealEstimateSheet> createState() => _AiMealEstimateSheetState();
}

class _AiMealEstimateSheetState extends State<AiMealEstimateSheet> {
  final _controller = TextEditingController();
  final _api = ApiClient();

  bool _loading = false;
  bool _saving = false;
  String? _error;
  List<_EstimatedItem> _items = [];
  double _totalCalories = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _estimate() async {
    final msg = _controller.text.trim();
    if (msg.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.post('/api/meals/estimate', body: {
        'user_id': widget.userId,
        'message': msg,
        'meal_type': widget.mealType,
      });
      if (res.statusCode != 200) {
        setState(() => _error = 'AI ประมวลผลไม่สำเร็จ (${res.statusCode})');
        return;
      }
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final rawItems = (data['items'] as List?) ?? [];
      final total = (data['total'] as Map?) ?? {};
      setState(() {
        _items = rawItems
            .map((e) => _EstimatedItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _totalCalories = (total['calories'] as num?)?.toDouble() ?? 0;
        if (_items.isEmpty) {
          _error = 'ไม่พบเมนูอาหารในข้อความ ลองระบุชื่อเมนูให้ชัดขึ้น';
        }
      });
    } catch (e) {
      setState(() => _error = 'เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_items.isEmpty) return;
    setState(() => _saving = true);
    try {
      final dateStr =
          '${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}';
      final itemsPayload = _items
          .map((i) => {
                'food_id': null,
                'food_name': i.name,
                'amount': i.quantity ?? 1.0,
                'unit_id': null,
                'cal_per_unit': i.calories,
                'protein_per_unit': i.protein,
                'carbs_per_unit': i.carbs,
                'fat_per_unit': i.fat,
              })
          .toList();
      final res = await _api.post('/meals/${widget.userId}', body: {
        'date': dateStr,
        'meal_type': widget.mealType,
        'items': itemsPayload,
      });
      if (res.statusCode != 200 && res.statusCode != 201) {
        setState(() => _error = 'บันทึกไม่สำเร็จ (${res.statusCode})');
        return;
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกมื้ออาหารสำเร็จ')),
        );
      }
    } catch (e) {
      setState(() => _error = 'เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF628141)),
                const SizedBox(width: 8),
                const Text('บันทึกมื้ออาหารด้วย AI',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'พิมพ์อาหารที่ทาน เช่น "ข้าวผัดกะเพรา 1 จาน ต้มยำกุ้ง ครึ่งถ้วย"',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'อธิบายมื้อนี้...',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _estimate,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.calculate),
                label: Text(_loading ? 'กำลังวิเคราะห์...' : 'ประมาณแคลอรี่'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF628141),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            if (_items.isNotEmpty) ...[
              const Divider(height: 24),
              Text('รายการที่พบ (${_items.length} เมนู)',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ..._items.map(_buildItemTile),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFAFD198).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department,
                        color: Color(0xFF2D4A1C)),
                    const SizedBox(width: 8),
                    Text('รวม ${_totalCalories.toStringAsFixed(0)} kcal',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึกมื้อนี้'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D4A1C),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildItemTile(_EstimatedItem item) {
    final qty = item.quantity ?? 1.0;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        dense: true,
        title: Text(item.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'x${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 1)}'
          ' · P ${item.protein.toStringAsFixed(0)}g'
          ' · C ${item.carbs.toStringAsFixed(0)}g'
          ' · F ${item.fat.toStringAsFixed(0)}g',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text('${item.calories.toStringAsFixed(0)} kcal',
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Color(0xFF2D4A1C))),
      ),
    );
  }
}

class _EstimatedItem {
  final String name;
  final double? quantity;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? source;

  _EstimatedItem({
    required this.name,
    this.quantity,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.source,
  });

  factory _EstimatedItem.fromJson(Map<String, dynamic> j) => _EstimatedItem(
        name: (j['name'] ?? '').toString(),
        quantity: (j['quantity'] as num?)?.toDouble(),
        calories: (j['calories'] as num?)?.toDouble() ?? 0,
        protein: (j['protein'] as num?)?.toDouble() ?? 0,
        carbs: (j['carbs'] as num?)?.toDouble() ?? 0,
        fat: (j['fat'] as num?)?.toDouble() ?? 0,
        source: j['source'] as String?,
      );
}

/// Helper: show the sheet from anywhere in the app.
Future<void> showAiMealEstimateSheet({
  required BuildContext context,
  required int userId,
  required String mealType,
  required DateTime date,
  VoidCallback? onSaved,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => AiMealEstimateSheet(
      userId: userId,
      mealType: mealType,
      date: date,
      onSaved: onSaved,
    ),
  );
}
