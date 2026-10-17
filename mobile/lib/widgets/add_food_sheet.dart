import 'package:flutter/material.dart';
import '../models/indian_food_db.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class AddFoodSheet extends StatefulWidget {
  const AddFoodSheet({super.key});

  static Future<DishItem?> show(BuildContext context) {
    return showModalBottomSheet<DishItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddFoodSheet(),
    );
  }

  @override
  State<AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<AddFoodSheet> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  IndianFoodPreset? _selectedFood;
  double _quantity = 1.0; // In household units (e.g. 1, 2, 3 rotis or 0.5, 1.0, 1.5 katoris)

  final List<String> _categories = [
    'All',
    'Breads & Cereals',
    'Lentils & Pulses',
    'Curries',
    'Cereals & Grains',
    'South Indian',
    'Snacks & Breakfast',
    'Dairy',
  ];

  @override
  void initState() {
    super.initState();
    _selectedFood = IndianFoodDatabase.allFoods.first; // Default to Roti
    _quantity = 2.0; // Default to 2 rotis!
  }

  List<IndianFoodPreset> get _filteredFoods {
    return IndianFoodDatabase.allFoods.where((food) {
      final matchesQuery = _searchQuery.isEmpty ||
          food.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          food.hindiName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory =
          _selectedCategory == 'All' || food.category == _selectedCategory;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  void _onFoodSelected(IndianFoodPreset food) {
    setState(() {
      _selectedFood = food;
      final (unitName, _, isPiece) = IndianFoodDatabase.getHouseholdUnit(food.name);
      if (unitName == 'Roti') {
        _quantity = 2.0; // sensible default 2 rotis
      } else if (isPiece) {
        _quantity = 2.0;
      } else {
        _quantity = 1.0; // 1 katori
      }
    });
  }

  void _incrementQuantity(double step) {
    setState(() {
      _quantity = (_quantity + step).clamp(0.5, 10.0);
    });
  }

  void _decrementQuantity(double step) {
    setState(() {
      _quantity = (_quantity - step).clamp(0.5, 10.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final food = _selectedFood ?? IndianFoodDatabase.allFoods.first;
    final (unitName, gramsPerUnit, isPiece) = IndianFoodDatabase.getHouseholdUnit(food.name);
    final totalGrams = _quantity * gramsPerUnit;
    final ratio = totalGrams / 100.0;
    final netCarbs = double.parse((food.netCarbsPer100g * ratio).toStringAsFixed(1));
    final fiber = double.parse((food.dietaryFiberPer100g * ratio).toStringAsFixed(1));
    final gl = double.parse(((netCarbs * food.glycemicIndex) / 100.0).toStringAsFixed(1));
    final (glColor, glText) = AppTheme.getGlycemicLoadBadge(gl);

    final unitDisplayLabel = isPiece
        ? '${_quantity.round()} ${_quantity.round() == 1 ? unitName : '${unitName}s'}'
        : '${_quantity % 1 == 0 ? _quantity.toInt() : _quantity.toStringAsFixed(1)} ${_quantity == 1.0 ? 'Katori' : 'Katoris'}';

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Food to Plate',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Search ICMR IFCT database with household units',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search "Roti", "Dal", "Paneer", "Rice"...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryTeal),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    selectedColor: AppTheme.primaryTeal.withOpacity(0.15),
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? AppTheme.primaryTeal : AppTheme.textSecondary,
                    ),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryTeal : AppTheme.cardBorder,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // List of Filtered Foods
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filteredFoods.length,
              itemBuilder: (ctx, idx) {
                final item = _filteredFoods[idx];
                final isCurrent = item.foodId == food.foodId;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isCurrent ? AppTheme.primaryTeal.withOpacity(0.08) : AppTheme.surfaceWhite,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isCurrent ? AppTheme.primaryTeal : AppTheme.cardBorder,
                      width: isCurrent ? 1.8 : 1.0,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Text(item.emoji, style: const TextStyle(fontSize: 24)),
                    title: Text(
                      item.name,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w700,
                        color: isCurrent ? AppTheme.primaryTeal : AppTheme.textPrimary,
                        fontSize: 13.5,
                      ),
                    ),
                    subtitle: Text(
                      '${item.hindiName} • Std: ${item.standardServingGrams.toInt()}g (${item.servingUnit == 'piece' ? '1 piece' : '1 katori'})',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${item.netCarbsPer100g}g carbs/100g',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                      ),
                    ),
                    onTap: () => _onFoodSelected(item),
                  ),
                );
              },
            ),
          ),

          // Bottom Configuration Card (Household Units & Add Button)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: AppTheme.cardBorder, width: 1.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selected Item & Household Quantity Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(food.emoji, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  food.name,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            isPiece
                                ? 'approx ${totalGrams.toInt()}g (${gramsPerUnit.toInt()}g each)'
                                : 'approx ${totalGrams.toInt()}g (standard 9cm katori)',
                            style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    // Counter Controls
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_rounded, size: 20),
                            onPressed: () => _decrementQuantity(isPiece ? 1.0 : 0.5),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              unitDisplayLabel,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryTeal,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_rounded, size: 20),
                            onPressed: () => _incrementQuantity(isPiece ? 1.0 : 0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Quick Preset Chips (1, 2, 3, 4 Rotis OR 0.5, 1, 1.5, 2 Katoris)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: isPiece
                        ? [
                            _buildQuickUnitChip('1 $unitName', 1.0),
                            _buildQuickUnitChip('2 ${unitName}s', 2.0),
                            _buildQuickUnitChip('3 ${unitName}s', 3.0),
                            _buildQuickUnitChip('4 ${unitName}s', 4.0),
                          ]
                        : [
                            _buildQuickUnitChip('0.5 Katori', 0.5),
                            _buildQuickUnitChip('1.0 Katori', 1.0),
                            _buildQuickUnitChip('1.5 Katoris', 1.5),
                            _buildQuickUnitChip('2.0 Katoris', 2.0),
                          ],
                  ),
                ),
                const SizedBox(height: 12),

                // Macro Preview Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        'Net Carbs: $netCarbs g',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppTheme.primaryTeal),
                      ),
                      const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                      Text(
                        'Fiber: $fiber g',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: glColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'GL $gl ($glText)',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: glColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Confirm Add Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                    label: Text(
                      'Add $unitDisplayLabel to Plate',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    onPressed: () {
                      final item = food.toDishItem(quantity: _quantity);
                      Navigator.pop(context, item);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickUnitChip(String label, double val) {
    final isSelected = _quantity == val;
    return GestureDetector(
      onTap: () => setState(() => _quantity = val),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryTeal : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryTeal : AppTheme.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
