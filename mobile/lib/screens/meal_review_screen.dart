import 'package:flutter/material.dart';
import '../models/indian_food_db.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_food_sheet.dart';
import '../widgets/disclaimer_banner.dart';

class MealReviewScreen extends StatefulWidget {
  final MealAnalysisResponse analysis;

  const MealReviewScreen({super.key, required this.analysis});

  @override
  State<MealReviewScreen> createState() => _MealReviewScreenState();
}

class _MealReviewScreenState extends State<MealReviewScreen> {
  late List<DishItem> _dishes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dishes = List.from(widget.analysis.detectedDishes);
  }

  void _updateDishGrams(int index, double newGrams) {
    setState(() {
      final dish = _dishes[index];
      final originalGrams = dish.estimatedGrams > 0 ? dish.estimatedGrams : 100.0;
      dish.estimatedGrams = newGrams.clamp(10.0, 800.0);
      final ratio = dish.estimatedGrams / 100.0;
      dish.netCarbs = double.parse((dish.carbsPer100g * ratio * 0.85).toStringAsFixed(1));
      dish.dietaryFiber = double.parse((dish.dietaryFiber * (dish.estimatedGrams / originalGrams)).toStringAsFixed(1));
      dish.glycemicLoad = double.parse(((dish.netCarbs * dish.glycemicIndex) / 100.0).toStringAsFixed(1));
      dish.reviewFlag = false;
    });
  }

  void _updateByUnitStep(int index, double stepUnits) {
    final dish = _dishes[index];
    final (_, gramsPerUnit, _) = IndianFoodDatabase.getHouseholdUnit(dish.name);
    final currentUnits = dish.estimatedGrams / gramsPerUnit;
    final newUnits = (currentUnits + stepUnits).clamp(0.5, 10.0);
    _updateDishGrams(index, newUnits * gramsPerUnit);
  }

  void _setUnits(int index, double targetUnits) {
    final dish = _dishes[index];
    final (_, gramsPerUnit, _) = IndianFoodDatabase.getHouseholdUnit(dish.name);
    _updateDishGrams(index, targetUnits * gramsPerUnit);
  }

  void _removeDish(int index) {
    setState(() {
      _dishes.removeAt(index);
    });
  }

  Future<void> _openAddFoodSheet() async {
    final newDish = await AddFoodSheet.show(context);
    if (newDish != null) {
      setState(() {
        _dishes.add(newDish);
      });
    }
  }

  double get _totalCarbs =>
      double.parse(_dishes.fold(0.0, (sum, d) => sum + d.netCarbs).toStringAsFixed(1));

  double get _totalFiber =>
      double.parse(_dishes.fold(0.0, (sum, d) => sum + d.dietaryFiber).toStringAsFixed(1));

  double get _totalGL =>
      double.parse(_dishes.fold(0.0, (sum, d) => sum + d.glycemicLoad).toStringAsFixed(1));

  Future<void> _confirmMeal() async {
    setState(() => _isSaving = true);

    if (widget.analysis.mealId != null) {
      final updates = _dishes
          .map((d) => {'name': d.name, 'updated_grams': d.estimatedGrams})
          .toList();
      await ApiService.updateMealPortions(
        mealId: widget.analysis.mealId!,
        dishUpdates: updates,
      );
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    final finalResult = MealAnalysisResponse(
      mealId: widget.analysis.mealId,
      timestamp: widget.analysis.timestamp,
      detectedDishes: _dishes,
      totalNetCarbs: _totalCarbs,
      totalFiber: _totalFiber,
      mealGlycemicLoad: _totalGL,
      reviewRecommended: false,
      latencyMs: widget.analysis.latencyMs,
      disclaimer: widget.analysis.disclaimer,
    );

    Navigator.pop(context, finalResult);
  }

  @override
  Widget build(BuildContext context) {
    final (glBadgeColor, glBadgeText) = AppTheme.getGlycemicLoadBadge(_totalGL);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Portions & Carbs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryTeal),
            tooltip: 'Add Food Item',
            onPressed: _openAddFoodSheet,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DisclaimerBanner(compact: true),
            const SizedBox(height: 14),

            // Elevated Nutrition Summary Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00695C), Color(0xFF004D40)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF004D40).withOpacity(0.32),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TOTAL MEAL NUTRITION',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: glBadgeColor.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white38),
                        ),
                        child: Text(
                          glBadgeText,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryStat('Net Carbs', '$_totalCarbs g', Icons.grain_rounded),
                      _buildDivider(),
                      _buildSummaryStat('Fiber', '$_totalFiber g', Icons.eco_rounded),
                      _buildDivider(),
                      _buildSummaryStat('Glycemic Load', '$_totalGL', Icons.speed_rounded),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section Header & Add Food Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DISHES ON YOUR PLATE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      '${_dishes.length} items • Adjust by number of rotis or katoris',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryTeal,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Dish', style: TextStyle(fontWeight: FontWeight.w800)),
                  onPressed: _openAddFoodSheet,
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_dishes.isEmpty)
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.restaurant_outlined, size: 36, color: AppTheme.textMuted),
                      const SizedBox(height: 10),
                      const Text(
                        'Your plate is empty!',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap "Add Dish" to select Rotis, Rice, Dal or Curries.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Food from Database'),
                        onPressed: _openAddFoodSheet,
                      ),
                    ],
                  ),
                ),
              )
            else
              // Dish Cards with Indian Household Units
              ..._dishes.asMap().entries.map((entry) {
                final idx = entry.key;
                final dish = entry.value;
                return _buildDishEditorCard(idx, dish);
              }),

            const SizedBox(height: 14),

            // Additional "Add Another Item" dashed button
            InkWell(
              onTap: _openAddFoodSheet,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryTeal.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryTeal, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Add Another Dish (Roti, Dal, Rice, Dahi...)',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryTeal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 22),
                label: Text(
                  _isSaving ? 'Syncing...' : 'Confirm Meal ($_totalCarbs g Net Carbs)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                onPressed: _isSaving || _dishes.isEmpty ? null : _confirmMeal,
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 38,
      color: Colors.white24,
    );
  }

  Widget _buildDishEditorCard(int index, DishItem dish) {
    final (unitName, gramsPerUnit, isPiece) = IndianFoodDatabase.getHouseholdUnit(dish.name);
    final currentUnits = dish.estimatedGrams / gramsPerUnit;

    final unitDisplayLabel = isPiece
        ? '${currentUnits.round()} ${currentUnits.round() == 1 ? unitName : '${unitName}s'}'
        : '${currentUnits % 1 == 0 ? currentUnits.toInt() : currentUnits.toStringAsFixed(1)} ${currentUnits == 1.0 ? 'Katori' : 'Katoris'}';

    final unitSubtitle = isPiece
        ? 'approx ${dish.estimatedGrams.toInt()}g (${gramsPerUnit.toInt()}g per $unitName)'
        : 'approx ${dish.estimatedGrams.toInt()}g (standard 9cm katori)';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dish.reviewFlag ? AppTheme.watchAmber : AppTheme.cardBorder,
          width: dish.reviewFlag ? 2.0 : 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Emoji, Name, Confidence, and Delete Button
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(IndianFoodDatabase.getDishEmoji(dish.name), style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dish.name,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      if (dish.hindiName != null)
                        Text(
                          dish.hindiName!,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                    ],
                  ),
                ),
                // Bounding Box / Detection Source Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryTeal.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    dish.confidence >= 0.99 ? 'Manual' : 'AI Detected',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.primaryTeal),
                  ),
                ),
                const SizedBox(width: 4),
                // Remove Dish Icon
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFF94A3B8)),
                  tooltip: 'Remove Dish',
                  onPressed: () => _removeDish(index),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Household Unit Counter Row: [-] 2 Rotis [+]
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        unitDisplayLabel,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primaryTeal,
                        ),
                      ),
                      Text(
                        unitSubtitle,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.remove_rounded, size: 18),
                        onPressed: () => _updateByUnitStep(index, isPiece ? -1.0 : -0.5),
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
                        icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                        onPressed: () => _updateByUnitStep(index, isPiece ? 1.0 : 0.5),
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Quick Unit Selection Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: isPiece
                    ? [
                        _buildQuickUnitChip('1 $unitName', () => _setUnits(index, 1.0), currentUnits.round() == 1),
                        const SizedBox(width: 6),
                        _buildQuickUnitChip('2 ${unitName}s', () => _setUnits(index, 2.0), currentUnits.round() == 2),
                        const SizedBox(width: 6),
                        _buildQuickUnitChip('3 ${unitName}s', () => _setUnits(index, 3.0), currentUnits.round() == 3),
                        const SizedBox(width: 6),
                        _buildQuickUnitChip('4 ${unitName}s', () => _setUnits(index, 4.0), currentUnits.round() == 4),
                      ]
                    : [
                        _buildQuickUnitChip('0.5 Katori', () => _setUnits(index, 0.5), currentUnits == 0.5),
                        const SizedBox(width: 6),
                        _buildQuickUnitChip('1.0 Katori', () => _setUnits(index, 1.0), currentUnits == 1.0),
                        const SizedBox(width: 6),
                        _buildQuickUnitChip('1.5 Katoris', () => _setUnits(index, 1.5), currentUnits == 1.5),
                        const SizedBox(width: 6),
                        _buildQuickUnitChip('2.0 Katoris', () => _setUnits(index, 2.0), currentUnits == 2.0),
                      ],
              ),
            ),
            const SizedBox(height: 10),

            // Nutrition Calculated for Current Portion
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Net Carbs: ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    Text(
                      '${dish.netCarbs} g',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primaryTeal),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Fiber: ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    Text(
                      '${dish.dietaryFiber} g',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.inRangeGreenDark),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'GL: ${dish.glycemicLoad}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickUnitChip(String label, VoidCallback onTap, bool isSelected) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryTeal : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryTeal : AppTheme.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
