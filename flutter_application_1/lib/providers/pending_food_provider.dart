import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Data class ที่ส่งจาก RecipeDetailScreen → FoodLogScreen
/// เพื่อให้ FoodLogScreen auto-add อาหารไปยังมื้อที่ถูกต้อง
class PendingFoodEntry {
  final int foodId;
  final String foodName;
  final String mealId; // 'breakfast' | 'lunch' | 'dinner' | '' = ให้ user เลือก
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const PendingFoodEntry({
    required this.foodId,
    required this.foodName,
    required this.mealId,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
}

final pendingFoodProvider = StateProvider<PendingFoodEntry?>((ref) => null);
