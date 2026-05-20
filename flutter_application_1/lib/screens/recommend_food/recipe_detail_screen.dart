import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/services/api_client.dart';
import '/providers/user_data_provider.dart';
import '/providers/pending_food_provider.dart';
import '/services/error_reporter.dart';
import '../../utils/nutrition_approx.dart';

// ─────────────────────────────────────────────
//  RecipeDetailScreen
//  รับ foodId → fetch GET /recipes/by_food/{foodId}
// ─────────────────────────────────────────────
class RecipeDetailScreen extends ConsumerStatefulWidget {
  final int foodId;
  const RecipeDetailScreen({super.key, required this.foodId});

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  // ── Data ──
  Map<String, dynamic>? _recipe;
  List<dynamic> _ingredients = [];
  List<dynamic> _steps = [];
  List<dynamic> _tools = [];
  List<dynamic> _tips = [];
  List<dynamic> _reviews = [];

  bool _isLoading = true;
  bool _isFav = false;
  bool _favLoading = false;

  // ── Colors ──
  static const _green = Color(0xFF628141);
  static const _greenL = Color(0xFFE8EFCF);
  static const _greenMid = Color(0xFFAFD198);
  static const _orange = Color(0xFFD76A3C);
  static const _orangeL = Color(0xFFFFF3E0);
  static const _gold = Color(0xFFF9A825);
  static const _bg = Color(0xFFF2F7F4);

  @override
  void initState() {
    super.initState();
    _fetchRecipe();
  }

  // ────────────────────────────────────────────
  //  FETCH
  // ────────────────────────────────────────────
  Future<void> _fetchRecipe() async {
    try {
      final userId = ref.read(userDataProvider).userId;
      final res = await ApiClient().get(
        '/recipes/${widget.foodId}',
        queryParams: userId > 0 ? {'user_id': '$userId'} : null,
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _recipe = data;
          _ingredients = data['ingredients'] ?? [];
          _steps = data['steps'] ?? [];
          _tools = data['tools'] ?? [];
          _tips = data['tips'] ?? [];
          _reviews = data['reviews'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final userId = ref.read(userDataProvider).userId;
    if (userId == 0) return;
    setState(() => _favLoading = true);
    try {
      final res = await ApiClient().post(
        '/recipes/${widget.foodId}/favorite/$userId',
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => _isFav = data['is_favorite'] == true);
      }
    } catch (e, st) {
      ErrorReporter.report('recipe_detail.fetch_favorite', e, st);
    }
    setState(() => _favLoading = false);
  }

  // ────────────────────────────────────────────
  //  BUILD
  // ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _green)),
      );
    }

    if (_recipe == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
                onPressed: () => Navigator.pop(context))),
        body: const Center(
            child: Text('ยังไม่มีสูตรอาหารนี้ในระบบ 😅',
                style: TextStyle(fontSize: 16, color: Colors.grey))),
      );
    }

    final r = _recipe!;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Hero Image + App Bar ──
              _buildSliverAppBar(r),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Rating Row ──
                    _buildRatingRow(r),

                    // ── Time Chips ──
                    _buildTimeChips(r),

                    // ── Meta (difficulty, serving, id) ──
                    _buildMetaRow(r),

                    // ── Nutrition Card ──
                    _buildSection(
                        '📊 ข้อมูลโภชนาการ (ต่อจาน)', _buildNutritionCard(r)),

                    // ── Tools ──
                    if (_tools.isNotEmpty)
                      _buildSection('🍳 อุปกรณ์ที่ใช้', _buildToolsRow()),

                    // ── Ingredients ──
                    if (_ingredients.isNotEmpty)
                      _buildSection(
                        '🛒 วัตถุดิบ (${r['serving_people']?.toString() ?? '2'} ที่)',
                        _buildIngredientsList(),
                      ),

                    // ── Steps ──
                    if (_steps.isNotEmpty)
                      _buildSection('👨‍🍳 ขั้นตอนการทำ', _buildStepsList()),

                    // ── Tips ──
                    if (_tips.isNotEmpty)
                      _buildSection('💡 เทคนิคลับ', _buildTipsCard()),

                    // ── Reviews ──
                    _buildSection('💬 รีวิวจากผู้ใช้', _buildReviews()),

                    // padding ด้านล่าง (เผื่อ Add Meal Bar)
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),

          // ── Add to Meal Bar (Fixed Bottom) ──
          _buildAddMealBar(r),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  //  SLIVER APP BAR (Hero Image)
  // ────────────────────────────────────────────
  Widget _buildSliverAppBar(Map<String, dynamic> r) {
    final imageUrl = r['image_url']?.toString();
    final category = r['category']?.toString() ?? 'อาหารไทย';
    final name = r['display_name']?.toString() ??
        r['recipe_name']?.toString() ??
        r['food_name']?.toString() ??
        '';
    final desc = r['description']?.toString() ?? '';

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: _green,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity( 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 18),
        ),
      ),
      actions: [
        // ── Favorite Button ──
        GestureDetector(
          onTap: _favLoading ? null : _toggleFavorite,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isFav
                  ? Colors.red.withOpacity( 0.3)
                  : Colors.white.withOpacity( 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _favLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Icon(_isFav ? Icons.favorite : Icons.favorite_border,
                    color: Colors.white, size: 20),
          ),
        ),
        // ── Share Button ──
        Container(
          margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity( 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              const Icon(Icons.share_outlined, color: Colors.white, size: 20),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Hero image
            imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade400,
                        child: const Icon(Icons.restaurant,
                            size: 80, color: Colors.white)))
                : Container(
                    color: Colors.grey.shade400,
                    child: const Icon(Icons.restaurant,
                        size: 80, color: Colors.white)),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity( 0.35),
                    Colors.transparent,
                    Colors.black.withOpacity( 0.65),
                  ],
                  stops: const [0, 0.4, 1],
                ),
              ),
            ),

            // Bottom content
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('🍳 $category',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 8),
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 8)
                          ])),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withOpacity( 0.85),
                            fontSize: 13)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  RATING ROW
  // ────────────────────────────────────────────
  Widget _buildRatingRow(Map<String, dynamic> r) {
    final rating = double.tryParse(r['avg_rating']?.toString() ?? '0') ?? 0;
    final count = r['review_count'] ?? 0;
    final favCnt = r['favorite_count'] ?? 0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          // Stars
          Row(
              children: List.generate(
                  5,
                  (i) => Icon(
                      i < rating.round() ? Icons.star : Icons.star_border,
                      color: _gold,
                      size: 18))),
          const SizedBox(width: 6),
          Text(rating.toStringAsFixed(1),
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          Text(' ($count รีวิว)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          Container(
              width: 1,
              height: 20,
              color: Colors.grey.shade300,
              margin: const EdgeInsets.symmetric(horizontal: 10)),
          const Text('❤️ ', style: TextStyle(fontSize: 14)),
          Text('$favCnt บันทึก',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const Spacer(),
          // Review button
          GestureDetector(
            onTap: () => _showReviewSheet(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                  color: _greenL, borderRadius: BorderRadius.circular(99)),
              child: const Text('💬 รีวิว',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _green)),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────
  //  TIME CHIPS
  // ────────────────────────────────────────────
  Widget _buildTimeChips(Map<String, dynamic> r) {
    final prep = r['prep_time_minutes'] ?? 0;
    final cook = r['cooking_time_minutes'] ?? 0;
    final total = r['total_time_minutes'] ?? (prep + cook);
    final cuisine = r['cuisine']?.toString() ?? 'ไทย';

    return Container(
      color: _bg,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _timeChip('🔪', '$prep', 'นาที เตรียม', isHighlight: false),
            const SizedBox(width: 8),
            _timeChip('🔥', '$cook', 'นาที ทำ', isHighlight: false),
            const SizedBox(width: 8),
            _timeChip('⏱️', '$total', 'นาที รวม', isHighlight: true),
            const SizedBox(width: 8),
            _timeChip('🌏', cuisine, 'สัญชาติ', isHighlight: false),
          ],
        ),
      ),
    );
  }

  Widget _timeChip(String icon, String val, String label,
      {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlight ? _green : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity( 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 2),
        Text(val,
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isHighlight ? Colors.white : Colors.black87)),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: isHighlight ? Colors.white70 : Colors.grey.shade500)),
      ]),
    );
  }

  // ────────────────────────────────────────────
  //  META ROW (difficulty, serving, id)
  // ────────────────────────────────────────────
  Widget _buildMetaRow(Map<String, dynamic> r) {
    final diff = r['difficulty']?.toString() ?? 'Easy';
    final serving = r['serving_people']?.toString() ?? '2';
    final id = r['recipe_id']?.toString() ?? '-';

    Color diffColor;
    String diffEmoji;
    switch (diff.toLowerCase()) {
      case 'easy':
        diffColor = const Color(0xFF628141);
        diffEmoji = '⚡';
        break;
      case 'medium':
        diffColor = _orange;
        diffEmoji = '🔥';
        break;
      default:
        diffColor = Colors.red;
        diffEmoji = '💪';
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(children: [
        _metaBadge('ระดับความยาก', '$diffEmoji $diff', diffColor),
        const SizedBox(width: 8),
        _metaBadge('จำนวนเสิร์ฟ', '🍽️ $serving ที่', Colors.black87),
        const SizedBox(width: 8),
        _metaBadge('รหัสเมนู', '#$id', Colors.grey.shade600),
      ]),
    );
  }

  Widget _metaBadge(String label, String val, Color valColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity( 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: [
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          const SizedBox(height: 3),
          Text(val,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valColor)),
        ]),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  NUTRITION CARD
  // ────────────────────────────────────────────
  Widget _buildNutritionCard(Map<String, dynamic> r) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF1B5E35), Color(0xFF2E7D52)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF2E7D52).withOpacity( 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(children: [
        Row(children: [
          // แคลหลัก
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity( 0.15),
                  borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text(NutritionApprox.tildeDynamic(r['calories']),
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1)),
                const Text('kcal',
                    style: TextStyle(fontSize: 11, color: Colors.white70)),
                const Text('พลังงาน',
                    style: TextStyle(fontSize: 12, color: Colors.white)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          // macro grid
          Expanded(
            flex: 4,
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 1.8,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _nutItem('โปรตีน', r['protein'], 'g'),
                _nutItem('คาร์บ', r['carbs'], 'g'),
                _nutItem('ไขมัน', r['fat'], 'g'),
                _nutItem('น้ำตาล', r['sugar'], 'g'),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _nutItem2('โซเดียม', r['sodium'], 'mg')),
          const SizedBox(width: 6),
          Expanded(child: _nutItem2('คอเลสเตอรอล', r['cholesterol'], 'mg')),
        ]),
      ]),
    );
  }

  Widget _nutItem(String label, dynamic val, String unit) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white.withOpacity( 0.1),
          borderRadius: BorderRadius.circular(10)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(NutritionApprox.tildeDynamic(val),
            style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1)),
        Text(unit, style: const TextStyle(fontSize: 9, color: Colors.white60)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white)),
      ]),
    );
  }

  Widget _nutItem2(String label, dynamic val, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity( 0.1),
          borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.white70)),
          Text('${NutritionApprox.tildeDynamic(val)} $unit',
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ]),
      ]),
    );
  }

  // ────────────────────────────────────────────
  //  TOOLS ROW
  // ────────────────────────────────────────────
  Widget _buildToolsRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _tools.map((t) {
        final emoji = t['tool_emoji']?.toString() ?? '🔧';
        final name = t['tool_name']?.toString() ?? '';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity( 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(name,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E5040))),
          ]),
        );
      }).toList(),
    );
  }

  // ────────────────────────────────────────────
  //  INGREDIENTS LIST
  // ────────────────────────────────────────────
  Widget _buildIngredientsList() {
    return Column(
      children: _ingredients.asMap().entries.map((entry) {
        final i = entry.value;
        final idx = entry.key + 1;
        final isOpt = i['is_optional'] == true;
        final name = i['ingredient_name']?.toString() ?? '';
        final qty = i['quantity'];
        final unit = i['unit']?.toString() ?? '';
        final note = i['note']?.toString() ?? '';

        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isOpt ? Colors.white.withOpacity( 0.6) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: isOpt
                ? Border.all(color: _greenMid, style: BorderStyle.solid)
                : null,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity( 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(children: [
            // Index badge
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                  color: isOpt ? const Color(0xFFFFF3E0) : _greenL,
                  borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: isOpt
                  ? const Text('✦',
                      style: TextStyle(fontSize: 10, color: _orange))
                  : Text('$idx',
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _green)),
            ),
            const SizedBox(width: 12),
            // Name + note
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D2118))),
                if (note.isNotEmpty)
                  Text(note,
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            )),
            // Quantity
            if (isOpt)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(99)),
                child: const Text('เสริม',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _orange)),
              )
            else
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(qty != null ? NutritionApprox.tildeDynamic(qty) : '-',
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _green)),
                Text(unit,
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ]),
          ]),
        );
      }).toList(),
    );
  }

  // ────────────────────────────────────────────
  //  STEPS LIST
  // ────────────────────────────────────────────
  Widget _buildStepsList() {
    return Column(
      children: _steps.asMap().entries.map((entry) {
        final i = entry.value;
        final isLast = entry.key == _steps.length - 1;
        final num = i['step_number'] ?? (entry.key + 1);
        final title = i['title']?.toString() ?? 'ขั้นตอนที่ $num';
        final inst = i['instruction']?.toString() ?? '';
        final time = i['time_minutes'] ?? 0;
        final tip = i['tips']?.toString() ?? '';
        final img = i['image_url']?.toString() ?? '';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: number + line
            Column(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isLast ? const Color(0xFF4CAF79) : _green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: _green.withOpacity( 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ],
                ),
                alignment: Alignment.center,
                child: Text('$num',
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
              if (!isLast) Container(width: 2, height: 120, color: _greenMid),
            ]),
            const SizedBox(width: 12),
            // Right: content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + time
                    Row(children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D2118))),
                      const Spacer(),
                      if (time > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                              color: _orangeL,
                              borderRadius: BorderRadius.circular(99)),
                          child: Text('⏱ $time นาที',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _orange)),
                        ),
                    ]),
                    const SizedBox(height: 6),
                    // Instruction box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity( 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Text(inst,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF2E5040),
                              height: 1.6)),
                    ),
                    // Step image
                    if (img.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(img,
                            width: double.infinity,
                            height: 130,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox()),
                      ),
                    ],
                    // Tip box
                    if (tip.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFFDE7),
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('💡 ', style: TextStyle(fontSize: 14)),
                            Expanded(
                                child: Text(tip,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF2E5040),
                                        height: 1.4))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ────────────────────────────────────────────
  //  TIPS CARD
  // ────────────────────────────────────────────
  Widget _buildTipsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity( 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: _tips.asMap().entries.map((entry) {
          final idx = entry.key;
          final tip = entry.value;
          final text = tip['tip_text']?.toString() ?? '';
          final isLast = idx == _tips.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                        color: _greenL, borderRadius: BorderRadius.circular(7)),
                    alignment: Alignment.center,
                    child: Text('${idx + 1}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _green)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(text,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF2E5040),
                              height: 1.5))),
                ],
              ),
            ),
            if (!isLast) const Divider(height: 1, color: _greenL),
          ]);
        }).toList(),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  REVIEWS
  // ────────────────────────────────────────────
  Widget _buildReviews() {
    return Column(children: [
      // ── Comment input ──
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity( 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          const Expanded(
              child: Text('เขียนรีวิวของคุณ...',
                  style: TextStyle(fontSize: 13, color: Colors.grey))),
          GestureDetector(
            onTap: () => _showReviewSheet(),
            child: Container(
                width: 36,
                height: 36,
                decoration:
                    const BoxDecoration(color: _green, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 16)),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      // ── Review list ──
      if (_reviews.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text('ยังไม่มีรีวิว เป็นคนแรกที่รีวิวเลย! 🎉',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
        )
      else
        ..._reviews.map((rv) => _buildReviewItem(rv)),
    ]);
  }

  Widget _buildReviewItem(Map<String, dynamic> rv) {
    final rating = rv['rating'] ?? 0;
    final comment = rv['comment']?.toString() ?? '';
    final username = rv['username']?.toString() ?? 'ผู้ใช้';
    final date = rv['created_at']?.toString() ?? '';

    String dateShort = '';
    try {
      final d = DateTime.parse(date);
      final diff = DateTime.now().difference(d).inDays;
      dateShort = diff == 0 ? 'วันนี้' : '$diff วันที่แล้ว';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity( 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: _greenMid,
            child: Text(username.isNotEmpty ? username[0].toUpperCase() : 'U',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Text(username,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(dateShort,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        ]),
        const SizedBox(height: 4),
        Row(
            children: List.generate(
                5,
                (i) => Icon(i < rating ? Icons.star : Icons.star_border,
                    color: _gold, size: 14))),
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(comment,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF2E5040), height: 1.4)),
        ],
      ]),
    );
  }

  // ────────────────────────────────────────────
  //  REVIEW SHEET
  // ────────────────────────────────────────────
  void _showReviewSheet() {
    final userId = ref.read(userDataProvider).userId;
    if (userId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณาเข้าสู่ระบบก่อนรีวิว')));
      return;
    }

    int selectedRating = 5;
    final commentCtrl = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Handle
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(99)))),
              const SizedBox(height: 16),
              const Text('⭐ เขียนรีวิว',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              // Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    5,
                    (i) => GestureDetector(
                          onTap: () => setSheet(() => selectedRating = i + 1),
                          child: Icon(
                              i < selectedRating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: _gold,
                              size: 36),
                        )),
              ),
              const SizedBox(height: 16),
              // Comment
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'บอกเล่าประสบการณ์ของคุณ...',
                  filled: true,
                  fillColor: _greenL,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              // Submit
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setSheet(() => isSaving = true);
                          final nav = Navigator.of(ctx);
                          final messenger = ScaffoldMessenger.of(ctx);
                          try {
                            final res = await ApiClient().post(
                              '/recipes/${widget.foodId}/review',
                              body: {
                                'user_id': userId,
                                'rating': selectedRating,
                                'comment': commentCtrl.text.trim(),
                              },
                            );
                            if (res.statusCode == 200) {
                              _fetchRecipe(); // refresh
                              nav.pop();
                              messenger.showSnackBar(const SnackBar(
                                  content: Text('✅ บันทึกรีวิวแล้ว!')));
                            }
                          } catch (_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'ไม่สามารถบันทึกรีวิวได้ กรุณาลองใหม่'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                          setSheet(() => isSaving = false);
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  child: isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('ส่งรีวิว',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  TIME → MEAL TYPE
  // ────────────────────────────────────────────
  /// Returns meal id based on current hour:
  /// breakfast 06-10, lunch 11-14, dinner 17-20, else '' (user picks)
  String _mealIdFromTime() {
    final h = DateTime.now().hour;
    if (h >= 6 && h <= 10) return 'breakfast';
    if (h >= 11 && h <= 14) return 'lunch';
    if (h >= 17 && h <= 20) return 'dinner';
    return ''; // gap / snack — let user pick
  }

  // ────────────────────────────────────────────
  //  ADD TO MEAL BAR
  // ────────────────────────────────────────────
  Widget _buildAddMealBar(Map<String, dynamic> r) {
    final calLine =
        '${NutritionApprox.kcal((r['calories'] as num?)?.toDouble() ?? 0)} / จาน';
    final name = r['display_name']?.toString() ??
        r['recipe_name']?.toString() ??
        r['food_name']?.toString() ??
        '';

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF1B5E35), Color(0xFF2E7D52)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF2E7D52).withOpacity( 0.4),
                blurRadius: 20,
                offset: const Offset(0, 6))
          ],
        ),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(calLine,
                style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            Text('เพิ่ม "$name" ในบันทึกอาหาร',
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ]),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              final mealId = _mealIdFromTime();
              final mealLabel = {
                'breakfast': 'มื้อเช้า',
                'lunch': 'มื้อกลางวัน',
                'dinner': 'มื้อเย็น',
              }[mealId];
              // Set pending food for FoodLogScreen to pick up
              ref.read(pendingFoodProvider.notifier).state = PendingFoodEntry(
                foodId: widget.foodId,
                foodName: name,
                mealId: mealId,
                calories: (r['calories'] as num?)?.toDouble() ?? 0,
                protein: (r['protein'] as num?)?.toDouble() ?? 0,
                carbs: (r['carbs'] as num?)?.toDouble() ?? 0,
                fat: (r['fat'] as num?)?.toDouble() ?? 0,
              );
              // Switch to record tab
              ref.read(navIndexProvider.notifier).state = 1;
              Navigator.popUntil(context, (route) => route.isFirst);
              if (mealLabel != null) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('เพิ่ม "$name" ไปยัง $mealLabel ✔️'),
                  backgroundColor: const Color(0xFF628141),
                  duration: const Duration(seconds: 2),
                ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('กรุณาเลือกมื้ออาหารที่ต้องการบันทึก'),
                  duration: Duration(seconds: 3),
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1B5E35),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              elevation: 0,
            ),
            child: const Text('+ บันทึก',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  HELPER: Section wrapper
  // ────────────────────────────────────────────
  Widget _buildSection(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Section title with accent line
        Row(children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0D2118))),
          const SizedBox(width: 8),
          Expanded(
              child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_greenMid, Colors.transparent]),
                      borderRadius: BorderRadius.circular(99)))),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}
