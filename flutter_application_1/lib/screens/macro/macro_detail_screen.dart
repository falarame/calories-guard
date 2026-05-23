import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:flutter_application_1/services/api_client.dart';
import '../../models/models.dart';
import '../../providers/user_data_provider.dart';

class MacroDetailScreen extends ConsumerStatefulWidget {
  final String macroType; // 'protein', 'carbs', or 'fat'

  const MacroDetailScreen({
    super.key,
    required this.macroType,
  });

  @override
  ConsumerState<MacroDetailScreen> createState() => _MacroDetailScreenState();
}

class _MacroDetailScreenState extends ConsumerState<MacroDetailScreen> {
  bool _isLoading = true;
  List<Food> _allFoods = [];
  List<Food> _filteredFoods = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAndFilterFoods();
  }

  Future<void> _fetchAndFilterFoods() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiClient().get('/foods');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        _allFoods = data.map((item) => Food.fromJson(item)).toList();

        _filterAndSortFoods();

        if (mounted) setState(() => _isLoading = false);
      } else {
        throw Exception('Failed to load foods');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'เกิดข้อผิดพลาดในการโหลดข้อมูล: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _filterAndSortFoods() {
    final userData = ref.read(userDataProvider);

    int targetMacro = 0;
    int consumedMacro = 0;

    switch (widget.macroType) {
      case 'protein':
        targetMacro = userData.targetProtein;
        consumedMacro = userData.consumedProtein;
        _allFoods.sort((a, b) => b.protein.compareTo(a.protein));
        break;
      case 'carbs':
        targetMacro = userData.targetCarbs;
        consumedMacro = userData.consumedCarbs;
        _allFoods.sort((a, b) => b.carbs.compareTo(a.carbs));
        break;
      case 'fat':
        targetMacro = userData.targetFat;
        consumedMacro = userData.consumedFat;
        _allFoods.sort((a, b) => b.fat.compareTo(a.fat));
        break;
    }

    int remaining = targetMacro - consumedMacro;

    // ถ้ากินเกินแล้ว (remaining <= 0) ไม่แสดงรายการอาหารที่แนะนำ
    if (remaining <= 0) {
      _filteredFoods = [];
      return;
    }

    _filteredFoods = _allFoods.where((food) {
      switch (widget.macroType) {
        case 'protein':
          return food.protein <= remaining;
        case 'carbs':
          return food.carbs <= remaining;
        case 'fat':
          return food.fat <= remaining;
        default:
          return true;
      }
    }).toList();
  }

  String _getMacroLabel() {
    switch (widget.macroType) {
      case 'protein':
        return 'โปรตีน';
      case 'carbs':
        return 'คาร์บ';
      case 'fat':
        return 'ไขมัน';
      default:
        return 'สารอาหาร';
    }
  }

  String _getMacroUnit() {
    return 'g';
  }

  double _getConsumedMacro() {
    final userData = ref.watch(userDataProvider);
    switch (widget.macroType) {
      case 'protein':
        return userData.consumedProtein.toDouble();
      case 'carbs':
        return userData.consumedCarbs.toDouble();
      case 'fat':
        return userData.consumedFat.toDouble();
      default:
        return 0.0;
    }
  }

  double _getMacroValue(Food food) {
    switch (widget.macroType) {
      case 'protein':
        return food.protein;
      case 'carbs':
        return food.carbs;
      case 'fat':
        return food.fat;
      default:
        return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userData = ref.watch(userDataProvider);

    int targetMacro = 0;
    switch (widget.macroType) {
      case 'protein':
        targetMacro = userData.targetProtein;
        break;
      case 'carbs':
        targetMacro = userData.targetCarbs;
        break;
      case 'fat':
        targetMacro = userData.targetFat;
        break;
    }

    double consumedMacro = _getConsumedMacro();
    int remaining = (targetMacro - consumedMacro.toInt()).clamp(0, 1 << 30);
    bool isOver = consumedMacro >= targetMacro;

    String statusMessage;
    if (isOver) {
      statusMessage =
          '${_getMacroLabel()}วันนี้กินเกินแล้ว ไม่ควรกินอาหารที่มี${_getMacroLabel()}แล้ว';
    } else {
      statusMessage = 'ขาด${_getMacroLabel()}อีก $remaining g ควรทานอะไร';
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF628141),
        title: Text(
          'รายละเอียด${_getMacroLabel()}',
          style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- สถานะโภชนาการ: ควรทานอะไร / กินเกินแล้ว ---
                      Container(
                        width: double.infinity,
                        color: isOver
                            ? const Color(0xFFD76A3C).withValues(alpha: 0.2)
                            : const Color(0xFFE8EFCF),
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 20),
                        child: Text(
                          statusMessage,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isOver
                                ? const Color(0xFFB74D4D)
                                : const Color(0xFF4C6414),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // --- Remaining Macro Display (เมื่อยังไม่เกิน) ---
                      if (!isOver)
                        Container(
                          width: double.infinity,
                          color: const Color(0xFFE8EFCF),
                          padding: const EdgeInsets.symmetric(
                              vertical: 24, horizontal: 20),
                          child: Column(
                            children: [
                              Text(
                                _getMacroLabel(),
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF628141),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Consumed vs Target
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Column(
                                    children: [
                                      const Text(
                                        'ทานแล้ว',
                                        style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black54),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${consumedMacro.toInt()} ${_getMacroUnit()}',
                                        style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 2,
                                    height: 60,
                                    color: Colors.black12,
                                  ),
                                  Column(
                                    children: [
                                      const Text(
                                        'เป้าหมาย',
                                        style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black54),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '$targetMacro ${_getMacroUnit()}',
                                        style: const TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF628141)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 24),

                              // Remaining Info
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFF4C6414), width: 2),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 20),
                                child: Column(
                                  children: [
                                    const Text(
                                      'สามารถทานได้อีก',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '$remaining ${_getMacroUnit()}',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF628141),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (!isOver) ...[
                        const SizedBox(height: 20),

                        // --- Section Header ---
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          color: const Color(0xFF628141),
                          alignment: Alignment.center,
                          child: Text(
                            'แนะนำอาหาร${_getMacroLabel()}สูง',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        const SizedBox(height: 15),

                        // --- Food Grid ---
                        if (_filteredFoods.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 40, horizontal: 20),
                            child: Column(
                              children: [
                                Icon(Icons.info_outline,
                                    size: 48,
                                    color: Colors.grey.withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                const Text(
                                  'ไม่พบอาหารที่เหมาะสม',
                                  style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 16,
                                      color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'ลองกินอาหารอื่นก่อน หรือ ลดปริมาณ',
                                  style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      color:
                                          Colors.grey.withValues(alpha: 0.7)),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            color: const Color(0xFFE8EFCF),
                            padding: const EdgeInsets.symmetric(
                                vertical: 20, horizontal: 25),
                            child: GridView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 23,
                                mainAxisSpacing: 21,
                                childAspectRatio: 0.60,
                              ),
                              itemCount: _filteredFoods.length,
                              itemBuilder: (context, index) {
                                return _buildFoodCard(_filteredFoods[index]);
                              },
                            ),
                          ),
                        const SizedBox(height: 30),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildFoodCard(Food food) {
    final macroValue = _getMacroValue(food);
    final macroLabel = _getMacroLabel();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Food Image
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
                color: Colors.grey[200],
                image: food.imageUrl != null && food.imageUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(food.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: food.imageUrl == null || food.imageUrl!.isEmpty
                  ? Center(
                      child: Icon(Icons.image_not_supported,
                          color: Colors.grey[400], size: 40),
                    )
                  : null,
            ),
          ),

          // Food Info
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${food.calories.toInt()} kcal',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 6),
                // Macro-specific badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFAFD198),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$macroLabel ${macroValue.toInt()}g',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
