import 'models.dart';

class IndianFoodPreset {
  final String foodId;
  final String name;
  final String hindiName;
  final String category;
  final String servingUnit; // 'piece' or 'katori'
  final double standardServingGrams; // 35g for roti, 150g for dal/rice, etc.
  final double carbsPer100g;
  final double dietaryFiberPer100g;
  final double netCarbsPer100g;
  final double glycemicIndex;
  final double glycemicLoadPerServing;
  final String emoji;

  const IndianFoodPreset({
    required this.foodId,
    required this.name,
    required this.hindiName,
    required this.category,
    required this.servingUnit,
    required this.standardServingGrams,
    required this.carbsPer100g,
    required this.dietaryFiberPer100g,
    required this.netCarbsPer100g,
    required this.glycemicIndex,
    required this.glycemicLoadPerServing,
    required this.emoji,
  });

  DishItem toDishItem({double quantity = 1.0}) {
    final totalGrams = standardServingGrams * quantity;
    final ratio = totalGrams / 100.0;
    final netCarbs = double.parse((netCarbsPer100g * ratio).toStringAsFixed(1));
    final fiber = double.parse((dietaryFiberPer100g * ratio).toStringAsFixed(1));
    final gl = double.parse(((netCarbs * glycemicIndex) / 100.0).toStringAsFixed(1));

    return DishItem(
      name: name,
      hindiName: hindiName,
      category: category,
      confidence: 1.0,
      bbox: [0.2, 0.2, 0.8, 0.8],
      estimatedGrams: totalGrams,
      carbsPer100g: carbsPer100g,
      netCarbs: netCarbs,
      dietaryFiber: fiber,
      glycemicIndex: glycemicIndex,
      glycemicLoad: gl,
      reviewFlag: false,
    );
  }
}

class IndianFoodDatabase {
  static const List<IndianFoodPreset> allFoods = [
    // Breads & Cereals (Counted by Rotis / Pieces)
    IndianFoodPreset(
      foodId: 'IFCT_001',
      name: 'Roti (Whole Wheat)',
      hindiName: 'Chapati',
      category: 'Breads & Cereals',
      servingUnit: 'piece',
      standardServingGrams: 35.0, // 1 medium roti = ~35g
      carbsPer100g: 46.1,
      dietaryFiberPer100g: 10.2,
      netCarbsPer100g: 35.9,
      glycemicIndex: 62.0,
      glycemicLoadPerServing: 7.8,
      emoji: '🫓',
    ),
    IndianFoodPreset(
      foodId: 'IFCT_002',
      name: 'Plain Paratha',
      hindiName: 'Paratha',
      category: 'Breads & Cereals',
      servingUnit: 'piece',
      standardServingGrams: 50.0, // 1 paratha = ~50g
      carbsPer100g: 42.0,
      dietaryFiberPer100g: 8.5,
      netCarbsPer100g: 33.5,
      glycemicIndex: 65.0,
      glycemicLoadPerServing: 10.9,
      emoji: '🫓',
    ),
    IndianFoodPreset(
      foodId: 'IFCT_003',
      name: 'Steamed Basmati Rice',
      hindiName: 'Chawal',
      category: 'Cereals & Grains',
      servingUnit: 'katori',
      standardServingGrams: 150.0, // 1 katori = ~150g
      carbsPer100g: 28.2,
      dietaryFiberPer100g: 0.6,
      netCarbsPer100g: 27.6,
      glycemicIndex: 73.0,
      glycemicLoadPerServing: 30.2,
      emoji: '🍚',
    ),
    IndianFoodPreset(
      foodId: 'IFCT_012',
      name: 'Vegetable Biryani',
      hindiName: 'Veg Biryani',
      category: 'Cereals & Grains',
      servingUnit: 'katori',
      standardServingGrams: 180.0,
      carbsPer100g: 24.0,
      dietaryFiberPer100g: 2.2,
      netCarbsPer100g: 21.8,
      glycemicIndex: 65.0,
      glycemicLoadPerServing: 25.5,
      emoji: '🍛',
    ),
    // Dals & Lentils (Counted by Katoris)
    IndianFoodPreset(
      foodId: 'IFCT_004',
      name: 'Dal Tadka (Yellow Lentil)',
      hindiName: 'Peeli Dal',
      category: 'Lentils & Pulses',
      servingUnit: 'katori',
      standardServingGrams: 150.0, // 1 standard 9cm katori = 150g
      carbsPer100g: 11.5,
      dietaryFiberPer100g: 4.1,
      netCarbsPer100g: 7.4,
      glycemicIndex: 42.0,
      glycemicLoadPerServing: 4.7,
      emoji: '🍲',
    ),
    IndianFoodPreset(
      foodId: 'IFCT_005',
      name: 'Rajma Masala (Kidney Beans)',
      hindiName: 'Rajma Curry',
      category: 'Lentils & Pulses',
      servingUnit: 'katori',
      standardServingGrams: 150.0,
      carbsPer100g: 15.2,
      dietaryFiberPer100g: 5.8,
      netCarbsPer100g: 9.4,
      glycemicIndex: 45.0,
      glycemicLoadPerServing: 6.3,
      emoji: '🥘',
    ),
    IndianFoodPreset(
      foodId: 'IFCT_006',
      name: 'Chhole (Chickpeas Masala)',
      hindiName: 'Chana Masala',
      category: 'Lentils & Pulses',
      servingUnit: 'katori',
      standardServingGrams: 150.0,
      carbsPer100g: 16.8,
      dietaryFiberPer100g: 5.4,
      netCarbsPer100g: 11.4,
      glycemicIndex: 40.0,
      glycemicLoadPerServing: 6.8,
      emoji: '🥘',
    ),
    // Curries & Vegetables (Counted by Katoris)
    IndianFoodPreset(
      foodId: 'IFCT_007',
      name: 'Paneer Butter Masala',
      hindiName: 'Paneer Makhani',
      category: 'Curries',
      servingUnit: 'katori',
      standardServingGrams: 150.0,
      carbsPer100g: 6.5,
      dietaryFiberPer100g: 1.8,
      netCarbsPer100g: 4.7,
      glycemicIndex: 35.0,
      glycemicLoadPerServing: 2.5,
      emoji: '🧀',
    ),
    IndianFoodPreset(
      foodId: 'IFCT_008',
      name: 'Palak Paneer',
      hindiName: 'Palak Paneer',
      category: 'Curries',
      servingUnit: 'katori',
      standardServingGrams: 150.0,
      carbsPer100g: 4.2,
      dietaryFiberPer100g: 2.5,
      netCarbsPer100g: 1.7,
      glycemicIndex: 30.0,
      glycemicLoadPerServing: 0.8,
      emoji: '🥬',
    ),
    IndianFoodPreset(
      foodId: 'IFCT_016',
      name: 'Mixed Vegetable Sabzi',
      hindiName: 'Mix Veg',
      category: 'Vegetables',
      servingUnit: 'katori',
      standardServingGrams: 120.0,
      carbsPer100g: 8.4,
      dietaryFiberPer100g: 3.2,
      netCarbsPer100g: 5.2,
      glycemicIndex: 40.0,
      glycemicLoadPerServing: 2.5,
      emoji: '🥗',
    ),
    IndianFoodPreset(
      foodId: 'IFCT_017',
      name: 'Cucumber Tomato Salad',
      hindiName: 'Kachumber',
      category: 'Salads',
      servingUnit: 'katori',
      standardServingGrams: 100.0,
      carbsPer100g: 3.6,
      dietaryFiberPer100g: 1.5,
      netCarbsPer100g: 2.1,
      glycemicIndex: 15.0,
      glycemicLoadPerServing: 0.3,
      emoji: '🥗',
    ),
    IndianFoodPreset(
      foodId: 'IFCT_018',
      name: 'Curd / Dahi (Plain)',
      hindiName: 'Dahi',
      category: 'Dairy',
      servingUnit: 'katori',
      standardServingGrams: 120.0,
      carbsPer100g: 4.7,
      dietaryFiberPer100g: 0.0,
      netCarbsPer100g: 4.7,
      glycemicIndex: 36.0,
      glycemicLoadPerServing: 2.0,
      emoji: '🥣',
    ),
    // South Indian (Counted by Pieces / Katoris)
    IndianFoodPreset(
      foodId: 'IFCT_009',
      name: 'Idli (Steamed Rice-Urad)',
      hindiName: 'Idli',
      category: 'South Indian',
      servingUnit: 'piece',
      standardServingGrams: 40.0, // 1 idli = ~40g
      carbsPer100g: 21.5,
      dietaryFiberPer100g: 1.8,
      netCarbsPer100g: 19.7,
      glycemicIndex: 68.0,
      glycemicLoadPerServing: 5.4,
      emoji: '⚪',
    ),
    IndianFoodPreset(
      foodId: 'IFCT_010',
      name: 'Plain Dosa',
      hindiName: 'Sada Dosa',
      category: 'South Indian',
      servingUnit: 'piece',
      standardServingGrams: 80.0,
      carbsPer100g: 26.4,
      dietaryFiberPer100g: 2.1,
      netCarbsPer100g: 24.3,
      glycemicIndex: 77.0,
      glycemicLoadPerServing: 15.0,
      emoji: '🥞',
    ),
    IndianFoodPreset(
      foodId: 'IFCT_011',
      name: 'Masala Dosa',
      hindiName: 'Masala Dosa',
      category: 'South Indian',
      servingUnit: 'piece',
      standardServingGrams: 130.0,
      carbsPer100g: 24.8,
      dietaryFiberPer100g: 2.7,
      netCarbsPer100g: 22.1,
      glycemicIndex: 75.0,
      glycemicLoadPerServing: 21.5,
      emoji: '🥞',
    ),
    // Snacks & Breakfast
    IndianFoodPreset(
      foodId: 'IFCT_013',
      name: 'Poha',
      hindiName: 'Poha',
      category: 'Snacks & Breakfast',
      servingUnit: 'katori',
      standardServingGrams: 120.0,
      carbsPer100g: 23.5,
      dietaryFiberPer100g: 1.9,
      netCarbsPer100g: 21.6,
      glycemicIndex: 64.0,
      glycemicLoadPerServing: 16.6,
      emoji: '🥣',
    ),
    IndianFoodPreset(
      foodId: 'IFCT_014',
      name: 'Upma',
      hindiName: 'Upma',
      category: 'Snacks & Breakfast',
      servingUnit: 'katori',
      standardServingGrams: 120.0,
      carbsPer100g: 20.1,
      dietaryFiberPer100g: 1.5,
      netCarbsPer100g: 18.6,
      glycemicIndex: 65.0,
      glycemicLoadPerServing: 14.5,
      emoji: '🥣',
    ),
    IndianFoodPreset(
      foodId: 'IFCT_015',
      name: 'Samosa',
      hindiName: 'Samosa',
      category: 'Snacks',
      servingUnit: 'piece',
      standardServingGrams: 80.0,
      carbsPer100g: 32.0,
      dietaryFiberPer100g: 2.0,
      netCarbsPer100g: 30.0,
      glycemicIndex: 72.0,
      glycemicLoadPerServing: 17.3,
      emoji: '🥟',
    ),
    IndianFoodPreset(
      foodId: 'IFCT_019',
      name: 'Gulab Jamun',
      hindiName: 'Gulab Jamun',
      category: 'Sweets',
      servingUnit: 'piece',
      standardServingGrams: 45.0,
      carbsPer100g: 52.0,
      dietaryFiberPer100g: 0.5,
      netCarbsPer100g: 51.5,
      glycemicIndex: 78.0,
      glycemicLoadPerServing: 18.1,
      emoji: '🟤',
    ),
    IndianFoodPreset(
      foodId: 'IFCT_020',
      name: 'Besan Ladoo',
      hindiName: 'Laddoo',
      category: 'Sweets',
      servingUnit: 'piece',
      standardServingGrams: 35.0,
      carbsPer100g: 48.5,
      dietaryFiberPer100g: 3.0,
      netCarbsPer100g: 45.5,
      glycemicIndex: 55.0,
      glycemicLoadPerServing: 8.8,
      emoji: '🟡',
    ),
  ];

  /// Finds household unit configuration for any food name (whether from YOLO or preset)
  static (String unitName, double gramsPerUnit, bool isPiece) getHouseholdUnit(String foodName) {
    final lower = foodName.toLowerCase();
    if (lower.contains('roti') || lower.contains('chapati') || lower.contains('phulka')) {
      return ('Roti', 35.0, true);
    }
    if (lower.contains('paratha')) {
      return ('Paratha', 50.0, true);
    }
    if (lower.contains('naan')) {
      return ('Naan', 90.0, true);
    }
    if (lower.contains('idli')) {
      return ('Idli', 40.0, true);
    }
    if (lower.contains('dosa')) {
      return ('Dosa', lower.contains('masala') ? 130.0 : 80.0, true);
    }
    if (lower.contains('samosa')) {
      return ('Samosa', 80.0, true);
    }
    if (lower.contains('jamun') || lower.contains('ladoo') || lower.contains('laddoo')) {
      return ('Piece', 35.0, true);
    }
    if (lower.contains('curd') || lower.contains('dahi') || lower.contains('sabzi') || lower.contains('poha') || lower.contains('upma')) {
      return ('Katori', 120.0, false);
    }
    if (lower.contains('salad') || lower.contains('kachumber')) {
      return ('Katori', 100.0, false);
    }
    // Default for Indian curries, dals, rice dishes
    return ('Katori', 150.0, false);
  }

  static String getDishEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('roti') || lower.contains('chapati') || lower.contains('paratha') || lower.contains('naan')) return '🫓';
    if (lower.contains('rice') || lower.contains('chawal') || lower.contains('biryani')) return '🍚';
    if (lower.contains('dal') || lower.contains('lentil')) return '🍲';
    if (lower.contains('paneer')) return '🧀';
    if (lower.contains('rajma') || lower.contains('chhole') || lower.contains('chana')) return '🥘';
    if (lower.contains('salad') || lower.contains('kachumber')) return '🥗';
    if (lower.contains('dosa')) return '🥞';
    if (lower.contains('idli')) return '⚪';
    if (lower.contains('samosa')) return '🥟';
    if (lower.contains('poha') || lower.contains('upma')) return '🥣';
    if (lower.contains('curd') || lower.contains('dahi')) return '🥣';
    if (lower.contains('jamun')) return '🟤';
    if (lower.contains('ladoo') || lower.contains('laddoo')) return '🟡';
    return '🍛';
  }
}
