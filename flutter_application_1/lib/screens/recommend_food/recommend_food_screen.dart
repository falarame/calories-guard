import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/services/api_client.dart';
import '/providers/user_data_provider.dart';
import '/services/tamagotchi_action_logger.dart';
import '../macro/macro_detail_screen.dart';

import 'recipe_detail_screen.dart';

String _foodDisplayName(Map<String, dynamic> item) =>
    item['display_name']?.toString().trim().isNotEmpty == true
        ? item['display_name'].toString()
        : item['food_name']?.toString() ?? 'ไม่มีชื่อ';

class RecommendedFoodScreen extends ConsumerStatefulWidget {
  const RecommendedFoodScreen({super.key});

  @override
  ConsumerState<RecommendedFoodScreen> createState() =>
      _RecommendedFoodScreenState();
}

class _RecommendedFoodScreenState extends ConsumerState<RecommendedFoodScreen> {
  String? _foodCategoryFilter; // null = ทั้งหมด
  int _drinkFilterIndex = 0;
  String? _dessertCategoryFilter; // null = ทั้งหมด

  List<Map<String, dynamic>> _allFood = [];
  List<Map<String, dynamic>> _allDrinks = [];
  List<Map<String, dynamic>> _allDesserts = [];

  Map<int, int> _foodFrequency = {}; // food_id → จำนวนครั้งที่เคยกิน

  String _searchQuery = '';
  String? _selectedMacroFilter; // 'protein' | 'carbs' | 'fat'
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _errorMsg;
  bool _hideAllergic = true; // กรองเมนูที่แพ้ออกโดยค่าเริ่มต้น

  @override
  void initState() {
    super.initState();
    _fetchAllFood();
  }

  // ────────────────────────────────────────────
  //  FETCH FREQUENCY
  // ────────────────────────────────────────────
  Future<void> _fetchFoodFrequency() async {
    final userId = ref.read(userDataProvider).userId;
    if (userId <= 0) return;
    try {
      final res = await ApiClient().get('/users/$userId/food-frequency');
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        setState(() {
          _foodFrequency = {
            for (final d in data) (d['food_id'] as int): (d['count'] as int)
          };
        });
        _applyFrequencySort();
      }
    } catch (_) {}
  }

  void _applyFrequencySort() {
    setState(() {
      _allFood.sort((a, b) {
        final fa = _foodFrequency[a['food_id'] as int? ?? 0] ?? 0;
        final fb = _foodFrequency[b['food_id'] as int? ?? 0] ?? 0;
        if (fb != fa) return fb.compareTo(fa); // กินบ่อยขึ้นก่อน
        return 0; // เท่ากันคงไว้ลำดับ shuffle เดิม
      });
    });
  }

  // ────────────────────────────────────────────
  //  FETCH — ดึงอาหารทั้งหมดแล้วแยก category
  // ────────────────────────────────────────────
  Future<void> _fetchAllFood() async {
    try {
      final userId = ref.read(userDataProvider).userId;
      final res = await ApiClient().get(
        '/foods',
        queryParams: userId > 0 ? {'user_id': '$userId'} : null,
      );
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        final all = data.cast<Map<String, dynamic>>();

        setState(() {
          // ✅ แยกตาม food_type จริงจาก DB
          _allFood = all
              .where((f) =>
                  f['food_type'] == 'dish' || f['food_type'] == 'recipe_dish')
              .toList()
            ..shuffle();
          _allDrinks = all.where((f) => f['food_type'] == 'beverage').toList()
            ..shuffle();
          _allDesserts = all.where((f) => f['food_type'] == 'snack').toList()
            ..shuffle();
          _isLoading = false;
        });
        // ดึง frequency แล้ว sort ทับ (non-blocking)
        _fetchFoodFrequency();
      } else {
        setState(() {
          _isLoading = false;
          _errorMsg = 'โหลดข้อมูลไม่สำเร็จ (${res.statusCode})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้';
        });
      }
    }
  }

  // ────────────────────────────────────────────
  //  FILTER LOGIC
  // ────────────────────────────────────────────

  /// คืน true ถ้าควรซ่อนอาหารนี้เพราะผู้ใช้แพ้
  bool _isAllergicFood(Map<String, dynamic> food) {
    if (!_hideAllergic) return false;
    final userAllergies = ref.read(userDataProvider).allergyFlagIds;
    if (userAllergies.isEmpty) return false;
    final flags = (food['allergy_flag_ids'] as List?)?.cast<int>() ?? [];
    return flags.any((id) => userAllergies.contains(id));
  }

  // ✅ filter อาหาร ตาม category_name + กรองแพ้อาหาร
  List<Map<String, dynamic>> get _filteredFood {
    List<Map<String, dynamic>> base =
        _allFood.where((f) => !_isAllergicFood(f)).toList();
    if (_foodCategoryFilter != null) {
      base = base
          .where((f) => f['category_name']?.toString() == _foodCategoryFilter)
          .toList();
    }
    return base;
  }

  // ✅ filter เครื่องดื่ม
  List<Map<String, dynamic>> get _filteredDrinks {
    switch (_drinkFilterIndex) {
      case 1:
        return _allDrinks
            .where((f) => (f['sugar'] as num? ?? 0) == 0)
            .toList(); // ไม่มีน้ำตาล
      case 2:
        return _allDrinks
            .where((f) => (f['caffeine_mg'] as num? ?? 0) > 0)
            .toList(); // มีคาเฟอีน
      case 3:
        return _allDrinks
            .where((f) => (f['is_alcoholic'] as bool? ?? false))
            .toList(); // มีแอลกอฮอล์
      default:
        return _allDrinks;
    }
  }

  // ✅ filter ของหวาน/ขนม ตาม category_name
  List<Map<String, dynamic>> get _filteredDesserts {
    if (_dessertCategoryFilter != null) {
      return _allDesserts
          .where(
              (f) => f['category_name']?.toString() == _dessertCategoryFilter)
          .toList();
    }
    return _allDesserts;
  }

  // ────────────────────────────────────────────
  //  MACRO FILTER — เมนูที่ macro ≤ remaining
  // ────────────────────────────────────────────
  List<Map<String, dynamic>> _macroFilteredFood(String macro) {
    final userData = ref.read(userDataProvider);
    int consumed, target;
    String field;
    switch (macro) {
      case 'protein':
        consumed = userData.consumedProtein;
        target = userData.targetProtein;
        field = 'protein';
        break;
      case 'carbs':
        consumed = userData.consumedCarbs;
        target = userData.targetCarbs;
        field = 'carbs';
        break;
      case 'fat':
        consumed = userData.consumedFat;
        target = userData.targetFat;
        field = 'fat';
        break;
      default:
        return [];
    }
    final remaining = (target - consumed).clamp(0, target);
    if (remaining <= 0) return [];
    final result = _allFood
        .where((f) => !_isAllergicFood(f))
        .where((f) =>
            (f[field] as num? ?? 0) > 0 && (f[field] as num? ?? 0) <= remaining)
        .toList();
    result.sort(
        (a, b) => (b[field] as num? ?? 0).compareTo(a[field] as num? ?? 0));
    return result;
  }

  // ✅ ผลการค้นหา — ค้นจากทุกหมวด
  List<Map<String, dynamic>> get _searchResults {
    if (_searchQuery.isEmpty) return [];
    final all = [..._allFood, ..._allDrinks, ..._allDesserts];
    return all.where((item) {
      final q = _searchQuery.toLowerCase();
      final name = item['food_name']?.toString().toLowerCase() ?? '';
      final displayName = item['display_name']?.toString().toLowerCase() ?? '';
      final regionalName =
          item['regional_name']?.toString().toLowerCase() ?? '';
      return name.contains(q) ||
          displayName.contains(q) ||
          regionalName.contains(q);
    }).toList();
  }

  // ────────────────────────────────────────────
  //  SUGGEST NEW FOOD — opens a bottom sheet that POSTs to /foods/auto-add
  //  Admin reviews the submission before it becomes a real food entry.
  // ────────────────────────────────────────────
  void _openSuggestFoodSheet(String prefillName) {
    final userId = ref.read(userDataProvider).userId;
    if (userId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนเพิ่มเมนู')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SuggestFoodSheet(
        initialName: prefillName,
        userId: userId,
        onSubmitted: () {
          // Refresh to let newly-approved items appear. Won't show pending ones
          // (that's by design — temp_food is admin-gated).
          _fetchAllFood();
          TamagotchiActionLogger.logFoodSuggestion(userId);
        },
      ),
    );
  }

  // ────────────────────────────────────────────
  //  BUILD
  // ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // When the home-screen macro card is tapped, macroFilterProvider is set.
    // Listen here so we pick it up the moment this tab becomes visible, then
    // clear the provider so it doesn't re-trigger on future rebuilds.
    ref.listen<String?>(macroFilterProvider, (_, incoming) {
      if (incoming != null) {
        setState(() => _selectedMacroFilter = incoming);
        ref.read(macroFilterProvider.notifier).state = null;
      }
    });

    final isSearching = _searchQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // ── Search Bar ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Container(
                  height: 43,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) =>
                              setState(() => _searchQuery = val.trim()),
                          decoration: const InputDecoration(
                            hintText: 'ค้นหาอาหาร',
                            hintStyle: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w100,
                              color: Colors.black54,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      // ✅ ปุ่ม clear search
                      if (_searchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: const Icon(Icons.close,
                              size: 20, color: Colors.grey),
                        )
                      else
                        Icon(Icons.search, size: 24, color: Colors.grey[600]),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Allergy Filter Toggle ──
              Builder(builder: (_) {
                final userAllergies =
                    ref.watch(userDataProvider).allergyFlagIds;
                if (userAllergies.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: GestureDetector(
                    onTap: () => setState(() => _hideAllergic = !_hideAllergic),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _hideAllergic
                            ? const Color(0xFF628141).withOpacity(0.1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _hideAllergic
                              ? const Color(0xFF628141)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.no_meals,
                            size: 16,
                            color: _hideAllergic
                                ? const Color(0xFF628141)
                                : Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _hideAllergic
                                ? 'ซ่อนเมนูที่แพ้อยู่'
                                : 'แสดงเมนูที่แพ้ทั้งหมด',
                            style: TextStyle(
                              fontSize: 13,
                              color: _hideAllergic
                                  ? const Color(0xFF628141)
                                  : Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 12),

              if (_isLoading)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(
                            color: Color(0xFF628141))))
              else if (_errorMsg != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.wifi_off_rounded,
                          size: 56, color: Color(0xFFBDBDBD)),
                      const SizedBox(height: 12),
                      Text(_errorMsg!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMsg = null;
                          });
                          _fetchAllFood();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('ลองใหม่'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF628141),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ]),
                  ),
                )

              // ── ผลการค้นหา ──
              else if (isSearching) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                      'ผลการค้นหา: "$_searchQuery" (${_searchResults.length} รายการ)',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                _searchResults.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded,
                                  size: 52, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text(
                                'ไม่พบ "$_searchQuery" ในฐานข้อมูล',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _openSuggestFoodSheet(_searchQuery),
                                icon: const Icon(Icons.add_circle_outline,
                                    size: 18),
                                label: const Text('ขอเพิ่มเมนูนี้',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF628141),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'เมนูที่เพิ่มจะรอแอดมินตรวจสอบก่อนเผยแพร่',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildGrid(_searchResults),
              ]

              // ── หน้าหลัก ──
              else ...[
                // ── โภชนาการวันนี้ ──
                _buildMacroNutritionPanel(),
                const SizedBox(height: 8),

                // ── ผลการกรองตาม macro ──
                if (_selectedMacroFilter != null) ...[
                  _buildMacroFilterSection(),
                  const SizedBox(height: 24),
                ],

                // ── Macro Block ──
                if (_allFood.isNotEmpty)
                  _buildMacroBlockNew(context, 'อาหารแนะนำ (ทั้งหมด)',
                      'protein', _allFood.take(2).toList()),

                const SizedBox(height: 32),

                // ── แถบแนะนำสำหรับคุณ ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: const Color(0xFFEA580C),
                  alignment: Alignment.center,
                  child: const Text('แนะนำสำหรับคุณ',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          color: Colors.white)),
                ),
                const SizedBox(height: 24),

                // ── อาหาร ──
                _buildSectionHeader('สูตรอาหารแนะนำสำหรับคุณ'),
                _buildCategoryChips(
                  items: _allFood,
                  selected: _foodCategoryFilter,
                  onTap: (c) => setState(() => _foodCategoryFilter = c),
                ),
                // ✅ ใช้ _filteredFood แทน _allFood
                _allFood.isEmpty
                    ? _buildEmptyState('ยังไม่มีเมนูอาหาร')
                    : _buildGrid(_filteredFood),
                _buildSeeMoreButton(
                  categoryTitle: 'สูตรอาหารทั้งหมด',
                  items: _filteredFood,
                ),

                // ── เครื่องดื่ม ──
                _buildSectionHeader('สูตรเครื่องดื่มแนะนำสำหรับคุณ'),
                _buildFilterChips(
                  labels: const [
                    'ทั้งหมด',
                    'ไม่มีน้ำตาล',
                    'ชา/กาแฟ',
                    'มีแอลกอฮอล์'
                  ],
                  selectedIndex: _drinkFilterIndex,
                  onTap: (i) => setState(() => _drinkFilterIndex = i),
                ),
                // ✅ ดึงจาก DB จริง ไม่ใช่ Mock
                _allDrinks.isEmpty
                    ? _buildEmptyState('ยังไม่มีข้อมูลเครื่องดื่ม')
                    : _buildGrid(_filteredDrinks),
                _buildSeeMoreButton(
                  categoryTitle: 'สูตรเครื่องดื่มทั้งหมด',
                  items: _filteredDrinks,
                ),

                // ── ของหวาน ──
                _buildSectionHeader('สูตรของหวานแนะนำสำหรับคุณ'),
                _buildCategoryChips(
                  items: _allDesserts,
                  selected: _dessertCategoryFilter,
                  onTap: (c) => setState(() => _dessertCategoryFilter = c),
                ),
                // ✅ ดึงจาก DB จริง
                _allDesserts.isEmpty
                    ? _buildEmptyState('ยังไม่มีข้อมูลของหวาน')
                    : _buildGrid(_filteredDesserts),
                _buildSeeMoreButton(
                  categoryTitle: 'สูตรของหวานทั้งหมด',
                  items: _filteredDesserts,
                ),

                const SizedBox(height: 100),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  MACRO NUTRITION PANEL
  // ────────────────────────────────────────────

  Widget _buildMacroNutritionPanel() {
    final userData = ref.watch(userDataProvider);
    // Semantic macro colors — consistent with TDEE formula screen
    const proteinColor = Color(0xFF2563EB); // blue — muscle/protein
    const carbsColor = Color(0xFFD97706); // amber — energy/carbs
    const fatColor = Color(0xFFEA580C); // orange — fat/warmth
    final macros = [
      {
        'key': 'protein',
        'label': 'โปรตีน',
        'icon': Icons.egg_outlined,
        'consumed': userData.consumedProtein,
        'target': userData.targetProtein,
        'color': proteinColor,
      },
      {
        'key': 'carbs',
        'label': 'คาร์บ',
        'icon': Icons.grain_rounded,
        'consumed': userData.consumedCarbs,
        'target': userData.targetCarbs,
        'color': carbsColor,
      },
      {
        'key': 'fat',
        'label': 'ไขมัน',
        'icon': Icons.water_drop_outlined,
        'consumed': userData.consumedFat,
        'target': userData.targetFat,
        'color': fatColor,
      },
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.bar_chart_rounded,
                size: 16, color: Color(0xFF628141)),
            const SizedBox(width: 6),
            const Text('โภชนาการวันนี้',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Text('กดเลือกเพื่อดูเมนูที่เหมาะ',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ]),
          const SizedBox(height: 10),
          Row(
              children: macros.map((m) {
            final key = m['key'] as String;
            final isSelected = _selectedMacroFilter == key;
            final consumed = m['consumed'] as int;
            final target = m['target'] as int;
            final remaining = (target - consumed).clamp(0, target);
            final progress =
                target > 0 ? (consumed / target).clamp(0.0, 1.0) : 0.0;
            final color = m['color'] as Color;
            final isOver = consumed > target;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedMacroFilter = isSelected ? null : key;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.12)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isSelected ? color : Colors.grey.shade200,
                        width: isSelected ? 1.5 : 1),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(m['icon'] as IconData,
                            size: 13,
                            color: isSelected ? color : Colors.grey.shade500),
                        const SizedBox(height: 4),
                        Text(m['label'] as String,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? color : Colors.black87)),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey.shade200,
                            color: isOver ? Colors.red.shade400 : color,
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('$consumed/$target g',
                            style: TextStyle(
                                fontSize: 9, color: Colors.grey.shade500)),
                        const SizedBox(height: 2),
                        Text(
                          isOver ? 'เกินเป้าหมาย' : 'ขาด ${remaining}g',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isOver ? Colors.red.shade400 : color),
                        ),
                      ]),
                ),
              ),
            );
          }).toList()),
        ]),
      ),
    );
  }

  Widget _buildMacroFilterSection() {
    final userData = ref.watch(userDataProvider);
    final macro = _selectedMacroFilter!;
    final labelMap = {'protein': 'โปรตีน', 'carbs': 'คาร์บ', 'fat': 'ไขมัน'};
    final colorMap = {
      'protein': const Color(0xFF2563EB), // blue — muscle/protein
      'carbs': const Color(0xFFD97706), // amber — energy/carbs
      'fat': const Color(0xFFEA580C), // orange — fat/warmth
    };
    final label = labelMap[macro]!;
    final color = colorMap[macro]!;
    final consumed = macro == 'protein'
        ? userData.consumedProtein
        : macro == 'carbs'
            ? userData.consumedCarbs
            : userData.consumedFat;
    final target = macro == 'protein'
        ? userData.targetProtein
        : macro == 'carbs'
            ? userData.targetCarbs
            : userData.targetFat;
    final remaining = (target - consumed).clamp(0, target);
    final filtered = _macroFilteredFood(macro);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── header banner ──
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(children: [
          Icon(Icons.restaurant_rounded, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                children: [
                  const TextSpan(
                    text: 'เมนูที่มี',
                  ),
                  TextSpan(
                      text: label,
                      style:
                          TextStyle(fontWeight: FontWeight.bold, color: color)),
                  const TextSpan(text: ' ≤ '),
                  TextSpan(
                      text: '${remaining}g',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, color: color)),
                  const TextSpan(text: '  •  เหมาะสำหรับมื้อถัดไป'),
                ],
              ),
            ),
          ),
          Text('$consumed/$target g',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ]),
      ),
      const SizedBox(height: 10),
      // ── food list ──
      if (remaining <= 0)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          child: Center(
            child: consumed > target
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 44, color: Colors.red.shade400),
                    const SizedBox(height: 8),
                    Text('เกิน$labelเป้าหมายแล้ว! ⚠️',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.red.shade400,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('$consumed/$target g',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(navIndexProvider.notifier).state = 1;
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      },
                      icon: const Icon(Icons.edit_note_rounded, size: 16),
                      label: const Text('ไปหน้าบันทึก'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade400,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                    ),
                  ])
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 44, color: color),
                    const SizedBox(height: 8),
                    Text('ตามเป้าหมาย$labelแล้ววันนี้ 🎉',
                        style: TextStyle(
                            fontSize: 14,
                            color: color,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('$consumed/$target g',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ]),
          ),
        )
      else if (filtered.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Text(
            'ไม่พบเมนูที่มี$label ≤ ${remaining}g ในฐานข้อมูล',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        )
      else
        _buildGrid(filtered.take(6).toList()),
    ]);
  }

  // ────────────────────────────────────────────
  //  WIDGETS
  // ────────────────────────────────────────────

  Widget _buildMacroBlockNew(BuildContext context, String title,
      String macroType, List<Map<String, dynamic>> items) {
    const lightGreen = Color(0xFFE8EFCF);
    const darkGreen = Color(0xFF628141);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
          color: lightGreen, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MacroDetailScreen(macroType: macroType))),
          child: IntrinsicWidth(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(30)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 8),
                Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                        color: darkGreen, shape: BoxShape.circle),
                    child: const Icon(Icons.chevron_right,
                        color: Colors.white, size: 18)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 20),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: _buildMacroCard(items[i])),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _buildMacroCard(Map<String, dynamic> item) {
    final foodName = _foodDisplayName(item);
    final calories = item['calories']?.toString() ?? '0';
    final imageUrl = item['image_url']?.toString();
    // ✅ แปลง foodId เป็น int ให้ถูกต้อง
    final foodId = item['food_id'] != null
        ? int.tryParse(item['food_id'].toString())
        : null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AspectRatio(
        aspectRatio: 1.0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: (imageUrl != null && imageUrl.isNotEmpty)
              ? _networkImage(imageUrl)
              : _imagePlaceholder(),
        ),
      ),
      const SizedBox(height: 12),
      Text(foodName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis),
      Text('$calories kcal',
          style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      const Spacer(),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () {
          if (foodId != null) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(foodId: foodId)));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFAFD198),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 3))
            ],
          ),
          child: const Text('วิธีการทำ',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
        ),
      ),
    ]);
  }

  // ✅ Grid หลัก — รองรับทั้ง dish/beverage/snack
  Widget _buildGrid(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return _buildEmptyState('ไม่มีรายการในหมวดนี้');

    return Container(
      width: double.infinity,
      color: const Color(0xFFE8EFCF),
      padding: const EdgeInsets.fromLTRB(25, 14, 25, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 23,
          mainAxisSpacing: 21,
          childAspectRatio: 0.62,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildFoodCard(items[index]),
      ),
    );
  }

  Widget _buildFoodCard(Map<String, dynamic> item) {
    final foodName = _foodDisplayName(item);
    final calories = item['calories']?.toString() ?? '0';
    final imageUrl = item['image_url']?.toString();
    // ✅ cast int ให้ถูกต้องทุกที่
    final foodId = item['food_id'] != null
        ? int.tryParse(item['food_id'].toString())
        : null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 160,
          height: 160,
          child: (imageUrl != null && imageUrl.isNotEmpty)
              ? _networkImage(imageUrl)
              : _imagePlaceholder(),
        ),
      ),
      const SizedBox(height: 10),
      Text(foodName,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, height: 1.2),
          maxLines: 2,
          overflow: TextOverflow.ellipsis),
      const SizedBox(height: 4),
      Text('$calories kcal',
          style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      const Spacer(),
      GestureDetector(
        onTap: () {
          if (foodId != null) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => RecipeDetailScreen(foodId: foodId)));
          } else {
            // ✅ แสดงแจ้งเตือนถ้ายังไม่มีสูตร
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('ยังไม่มีสูตรอาหารสำหรับเมนูนี้'),
                duration: Duration(seconds: 2)));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFAFD198),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 4))
            ],
          ),
          child: const Text('วิธีการทำ',
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        ),
      ),
    ]);
  }

  // ✅ Empty state widget
  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFE8EFCF),
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(children: [
        Icon(Icons.restaurant_menu, size: 40, color: Colors.grey.shade400),
        const SizedBox(height: 8),
        Text(message,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
      ]),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: const Color(0xFF628141),
      alignment: Alignment.center,
      child: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w500, fontSize: 20, color: Colors.white)),
    );
  }

  Widget _buildFilterChips({
    required List<String> labels,
    required int selectedIndex,
    required ValueChanged<int> onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(labels.length, (i) {
            final isSelected = i == selectedIndex;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFAFD198) : Colors.white,
                    borderRadius: BorderRadius.circular(100),
                    border: isSelected
                        ? null
                        : Border.all(color: const Color(0xFF4C6414)),
                  ),
                  child: Text(labels[i],
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 16)),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCategoryChips({
    required List<Map<String, dynamic>> items,
    required String? selected,
    required ValueChanged<String?> onTap,
  }) {
    final cats = items
        .map((f) => f['category_name']?.toString())
        .where((c) => c != null && c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _chip('ทั้งหมด', selected == null, () => onTap(null)),
            ...cats.map((c) => _chip(c!, selected == c, () => onTap(c))),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFAFD198) : Colors.white,
            borderRadius: BorderRadius.circular(100),
            border:
                isSelected ? null : Border.all(color: const Color(0xFF4C6414)),
          ),
          child: Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildSeeMoreButton({
    required String categoryTitle,
    required List<Map<String, dynamic>> items,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FoodCategoryScreen(
            title: categoryTitle,
            items: items,
          ),
        ),
      ),
      child: Container(
        width: double.infinity,
        color: const Color(0xFFE8EFCF),
        padding: const EdgeInsets.only(right: 25, top: 12, bottom: 20),
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF628141),
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 4))
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ดูเพิ่มเติม',
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: Colors.white)),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
//  Shared image helpers (used by multiple screens in this file)
// ────────────────────────────────────────────────────────────────────────────

Widget _imagePlaceholder() {
  return Container(
    color: const Color(0xFFE8EFCF),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.restaurant_menu_rounded,
          color: const Color(0xFF628141).withOpacity(0.55), size: 44),
      const SizedBox(height: 6),
      Text('ไม่มีรูปภาพ',
          style: TextStyle(
              fontSize: 11,
              color: const Color(0xFF628141).withOpacity(0.6),
              fontWeight: FontWeight.w500)),
    ]),
  );
}

Widget _imageLoading() {
  return Container(
    color: const Color(0xFFEFF4E8),
    child: Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF628141).withOpacity(0.6))),
      ),
    ),
  );
}

Widget _networkImage(String url, {BoxFit fit = BoxFit.cover}) {
  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (_, child, progress) =>
        progress == null ? child : _imageLoading(),
    errorBuilder: (_, __, ___) => _imagePlaceholder(),
  );
}

// ────────────────────────────────────────────────────────────────────────────
//  FoodCategoryScreen — แสดงรายการอาหารทั้งหมดในหมวดหมู่นั้นๆ
// ────────────────────────────────────────────────────────────────────────────
class FoodCategoryScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;

  const FoodCategoryScreen({
    super.key,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EFCF),
      body: Column(children: [
        // Header
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3D5A27), Color(0xFF628141)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${items.length} รายการ',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ]),
        ),

        // Grid
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restaurant_menu_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text('ยังไม่มีรายการในหมวดนี้',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 16)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.68,
                  ),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) =>
                      _buildCategoryFoodCard(ctx, items[i]),
                ),
        ),
      ]),
    );
  }

  Widget _buildCategoryFoodCard(
      BuildContext context, Map<String, dynamic> item) {
    final foodName = _foodDisplayName(item);
    final calories = item['calories']?.toString() ?? '0';
    final imageUrl = item['image_url']?.toString();
    final foodId = item['food_id'] != null
        ? int.tryParse(item['food_id'].toString())
        : null;

    return GestureDetector(
      onTap: () {
        if (foodId != null) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => RecipeDetailScreen(foodId: foodId)));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                width: double.infinity,
                height: 140,
                child: (imageUrl != null && imageUrl.isNotEmpty)
                    ? _networkImage(imageUrl)
                    : _imagePlaceholder(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(foodName,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(children: [
                      const Icon(Icons.local_fire_department_rounded,
                          size: 13, color: Color(0xFFE74C3C)),
                      const SizedBox(width: 3),
                      Text('$calories kcal',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFFE74C3C),
                              fontWeight: FontWeight.w500)),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  _SuggestFoodSheet
//  Bottom sheet to submit a new food suggestion → /foods/auto-add (temp_food).
//  Admin reviews and approves before it shows up in the catalog.
// ─────────────────────────────────────────────
class _SuggestFoodSheet extends StatefulWidget {
  final String initialName;
  final int userId;
  final VoidCallback onSubmitted;
  const _SuggestFoodSheet({
    required this.initialName,
    required this.userId,
    required this.onSubmitted,
  });

  @override
  State<_SuggestFoodSheet> createState() => _SuggestFoodSheetState();
}

class _SuggestFoodSheetState extends State<_SuggestFoodSheet> {
  static const _green = Color(0xFF628141);
  late final TextEditingController _nameCtrl;
  final TextEditingController _calCtrl = TextEditingController();
  final TextEditingController _proteinCtrl = TextEditingController();
  final TextEditingController _carbsCtrl = TextEditingController();
  final TextEditingController _fatCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อเมนู')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final res = await ApiClient().post(
        '/foods/auto-add',
        body: {
          'food_name': name,
          'calories': double.tryParse(_calCtrl.text.trim()) ?? 0,
          'protein': double.tryParse(_proteinCtrl.text.trim()) ?? 0,
          'carbs': double.tryParse(_carbsCtrl.text.trim()) ?? 0,
          'fat': double.tryParse(_fatCtrl.text.trim()) ?? 0,
          'user_id': widget.userId,
        },
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        Navigator.pop(context);
        widget.onSubmitted();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('ส่งคำขอเพิ่มเมนูแล้ว รอแอดมินตรวจสอบ'),
              backgroundColor: _green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ส่งคำขอไม่สำเร็จ (${res.statusCode})')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _numberField(String label, TextEditingController c, String suffix) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 12),
            const Text('ขอเพิ่มเมนูใหม่',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('แอดมินจะตรวจสอบก่อนเพิ่มเข้าฐานข้อมูล',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: 'ชื่อเมนู *',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            _numberField('แคลอรี่', _calCtrl, 'kcal'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _numberField('โปรตีน', _proteinCtrl, 'g')),
              const SizedBox(width: 10),
              Expanded(child: _numberField('คาร์บ', _carbsCtrl, 'g')),
              const SizedBox(width: 10),
              Expanded(child: _numberField('ไขมัน', _fatCtrl, 'g')),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('ส่งคำขอ',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
