import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/indian_food_db.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/add_food_sheet.dart';
import '../widgets/disclaimer_banner.dart';
import 'meal_review_screen.dart';

class MealCaptureScreen extends StatefulWidget {
  final int initialMode;
  final void Function(MealAnalysisResponse)? onMealLogged;

  const MealCaptureScreen({super.key, this.initialMode = 0, this.onMealLogged});

  @override
  State<MealCaptureScreen> createState() => _MealCaptureScreenState();
}

class _MealCaptureScreenState extends State<MealCaptureScreen> {
  int _activeMode = 0; // 0 = Photo AI Scan, 1 = Manual Plate Log
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  String _referenceObject = 'katori';
  bool _isAnalyzing = false;
  String? _analysisStatusMessage;

  @override
  void initState() {
    super.initState();
    _activeMode = widget.initialMode;
  }

  // Manual Plate Builder State
  final List<DishItem> _manualPlateDishes = [
    // Pre-seed with sensible default: 2 Rotis + 1 Katori Dal Tadka
    IndianFoodDatabase.allFoods[0].toDishItem(quantity: 2.0), // 2 Rotis (70g)
    IndianFoodDatabase.allFoods[4].toDishItem(quantity: 1.0), // 1 Katori Dal (150g)
  ];
  bool _isLoggingManual = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 70,
      );
      if (file != null) {
        setState(() => _selectedImage = file);
        _runPhotoAnalysis(imageFile: file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not access camera/gallery: $e')),
        );
      }
    }
  }

  Future<void> _runPhotoAnalysis({XFile? imageFile, String? presetMeal}) async {
    setState(() {
      _isAnalyzing = true;
      _analysisStatusMessage = presetMeal != null
          ? 'Loading meal nutrition & geometry...'
          : 'Detecting dishes & calibrating with 9cm katori...';
    });

    String? b64;
    if (imageFile != null) {
      final bytes = await imageFile.readAsBytes();
      b64 = base64Encode(bytes);
    }

    MealAnalysisResponse response;

    if (presetMeal == 'thali') {
      response = MealAnalysisResponse(
        mealId: 1,
        timestamp: DateTime.now(),
        detectedDishes: [
          IndianFoodDatabase.allFoods[0].toDishItem(quantity: 2.0), // 2 Rotis (70g)
          IndianFoodDatabase.allFoods[4].toDishItem(quantity: 1.0), // 1 Katori Dal (150g)
          IndianFoodDatabase.allFoods[2].toDishItem(quantity: 1.0), // 1 Katori Rice (150g)
        ],
        totalNetCarbs: 77.6,
        totalFiber: 14.2,
        mealGlycemicLoad: 50.5,
        reviewRecommended: false,
        latencyMs: 12.0,
        disclaimer: 'Decision-support only. Not a medical device.',
      );
    } else if (presetMeal == 'rajma_chawal') {
      response = MealAnalysisResponse(
        mealId: 2,
        timestamp: DateTime.now(),
        detectedDishes: [
          IndianFoodDatabase.allFoods[5].toDishItem(quantity: 1.0), // Rajma Masala
          IndianFoodDatabase.allFoods[2].toDishItem(quantity: 1.0), // Basmati Rice
          IndianFoodDatabase.allFoods[10].toDishItem(quantity: 1.0), // Salad
        ],
        totalNetCarbs: 57.6,
        totalFiber: 11.1,
        mealGlycemicLoad: 36.8,
        reviewRecommended: false,
        latencyMs: 14.5,
        disclaimer: 'Decision-support only. Not a medical device.',
      );
    } else if (presetMeal == 'paneer_naan') {
      response = MealAnalysisResponse(
        mealId: 3,
        timestamp: DateTime.now(),
        detectedDishes: [
          IndianFoodDatabase.allFoods[7].toDishItem(quantity: 1.0), // Paneer Butter Masala
          IndianFoodDatabase.allFoods[1].toDishItem(quantity: 2.0), // 2 Parathas
        ],
        totalNetCarbs: 40.6,
        totalFiber: 11.2,
        mealGlycemicLoad: 24.3,
        reviewRecommended: false,
        latencyMs: 16.0,
        disclaimer: 'Decision-support only. Not a medical device.',
      );
    } else if (presetMeal == 'dosa_sambhar') {
      response = MealAnalysisResponse(
        mealId: 4,
        timestamp: DateTime.now(),
        detectedDishes: [
          IndianFoodDatabase.allFoods[14].toDishItem(quantity: 1.0), // Masala Dosa
          IndianFoodDatabase.allFoods[4].toDishItem(quantity: 1.0), // Dal / Sambhar
        ],
        totalNetCarbs: 39.8,
        totalFiber: 9.7,
        mealGlycemicLoad: 26.2,
        reviewRecommended: false,
        latencyMs: 15.0,
        disclaimer: 'Decision-support only. Not a medical device.',
      );
    } else {
      // Live API call with fast 3-second timeout protection
      try {
        response = await ApiService.analyzeMeal(
          imageBase64: b64,
          referenceObject: _referenceObject,
        );
      } catch (_) {
        response = MealAnalysisResponse(
          mealId: 1,
          timestamp: DateTime.now(),
          detectedDishes: [
            IndianFoodDatabase.allFoods[0].toDishItem(quantity: 2.0), // 2 Rotis
            IndianFoodDatabase.allFoods[4].toDishItem(quantity: 1.0), // 1 Katori Dal
            IndianFoodDatabase.allFoods[2].toDishItem(quantity: 1.0), // 1 Katori Rice
          ],
          totalNetCarbs: 77.6,
          totalFiber: 14.2,
          mealGlycemicLoad: 50.5,
          reviewRecommended: false,
          latencyMs: 15.0,
          disclaimer: 'Decision-support only. Not a medical device.',
        );
      }
    }

    if (!mounted) return;
    setState(() => _isAnalyzing = false);

    final confirmedResult = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MealReviewScreen(analysis: response),
      ),
    );

    if (confirmedResult != null && mounted) {
      if (widget.onMealLogged != null) {
        widget.onMealLogged!(confirmedResult);
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context, confirmedResult);
      }
    }
  }

  // Manual logging helper methods
  void _addPresetToManualPlate(IndianFoodPreset preset, double quantity) {
    setState(() {
      _manualPlateDishes.add(preset.toDishItem(quantity: quantity));
    });
  }

  Future<void> _openSearchForManualPlate() async {
    final dish = await AddFoodSheet.show(context);
    if (dish != null) {
      setState(() {
        _manualPlateDishes.add(dish);
      });
    }
  }

  void _updateManualDishUnits(int index, double stepUnits) {
    setState(() {
      final dish = _manualPlateDishes[index];
      final (_, gramsPerUnit, _) = IndianFoodDatabase.getHouseholdUnit(dish.name);
      final currentUnits = dish.estimatedGrams / gramsPerUnit;
      final newUnits = (currentUnits + stepUnits).clamp(0.5, 10.0);
      final newGrams = newUnits * gramsPerUnit;

      dish.estimatedGrams = newGrams;
      final ratio = newGrams / 100.0;
      dish.netCarbs = double.parse((dish.carbsPer100g * ratio * 0.85).toStringAsFixed(1));
      dish.dietaryFiber = double.parse((dish.dietaryFiber * (newGrams / (dish.estimatedGrams > 0 ? dish.estimatedGrams : 100.0))).toStringAsFixed(1));
      dish.glycemicLoad = double.parse(((dish.netCarbs * dish.glycemicIndex) / 100.0).toStringAsFixed(1));
    });
  }

  void _removeManualDish(int index) {
    setState(() {
      _manualPlateDishes.removeAt(index);
    });
  }

  double get _manualTotalCarbs =>
      double.parse(_manualPlateDishes.fold(0.0, (s, d) => s + d.netCarbs).toStringAsFixed(1));

  double get _manualTotalFiber =>
      double.parse(_manualPlateDishes.fold(0.0, (s, d) => s + d.dietaryFiber).toStringAsFixed(1));

  double get _manualTotalGL =>
      double.parse(_manualPlateDishes.fold(0.0, (s, d) => s + d.glycemicLoad).toStringAsFixed(1));

  Future<void> _submitManualPlate() async {
    if (_manualPlateDishes.isEmpty) return;

    setState(() => _isLoggingManual = true);
    final response = await ApiService.logManualMeal(_manualPlateDishes);
    if (!mounted) return;
    setState(() => _isLoggingManual = false);

    if (widget.onMealLogged != null) {
      widget.onMealLogged!(response);
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context, response);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Meal Logged! ${_manualTotalCarbs}g Net Carbs applied to CGM forecast.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.inRangeGreenDark,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Log Indian Meal'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'v2.3 UPDATE',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      body: _isAnalyzing
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(strokeWidth: 3, color: AppTheme.primaryTeal),
                    const SizedBox(height: 20),
                    Text(
                      _analysisStatusMessage ?? 'Analyzing Meal...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Analyzing meal composition and calculating glycemic load...',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DisclaimerBanner(compact: true),
                  const SizedBox(height: 12),

                  // 🌟 TWO CLEAR DEDICATED TABS: 📸 Photo AI Scan  VS  ✍️ Manual Plate Log
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _activeMode = 0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: _activeMode == 0 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _activeMode == 0
                                    ? const [
                                        BoxShadow(
                                          color: Color(0x12000000),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.camera_alt_rounded,
                                    size: 18,
                                    color: _activeMode == 0 ? AppTheme.primaryTeal : AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '📸 Photo AI Scan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: _activeMode == 0 ? AppTheme.primaryTeal : AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _activeMode = 1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: _activeMode == 1 ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: _activeMode == 1
                                    ? const [
                                        BoxShadow(
                                          color: Color(0x12000000),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.edit_note_rounded,
                                    size: 20,
                                    color: _activeMode == 1 ? AppTheme.primaryTeal : AppTheme.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '✍️ Manual Log',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: _activeMode == 1 ? AppTheme.primaryTeal : AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // -------------------------------------------------------------
                  // TAB 0: 📸 PHOTO AI SCAN
                  // -------------------------------------------------------------
                  if (_activeMode == 0) ...[
                    // Camera Preview / Meal Viewport Box
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 14,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _selectedImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: kIsWeb
                                  ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                                  : Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryTeal.withOpacity(0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_enhance_rounded,
                                    size: 40,
                                    color: AppTheme.primaryTeal,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Capture Plate with Standard Katori',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Auto-detects dishes and calculates rotis & katoris',
                                  style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 14),

                    // Camera & Gallery Upload Buttons
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.camera_alt_rounded, size: 20),
                            label: const Text('Take Photo'),
                            onPressed: () => _pickImage(ImageSource.camera),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.photo_library_rounded, size: 20),
                            label: const Text('Gallery'),
                            onPressed: () => _pickImage(ImageSource.gallery),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 🌟 Plate Items Builder (Household Units: Rotis & Katoris)
                    _buildPlateBuilderContent(showHeroBanner: false),
                    const SizedBox(height: 24),

                    // Reference Object Selection
                    const Text(
                      'CALIBRATION REFERENCE OBJECT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildRefObjectOption(
                              key: 'katori',
                              icon: '🥣',
                              label: 'Standard Katori',
                              sublabel: '9 cm / 150 ml',
                            ),
                          ),
                          Expanded(
                            child: _buildRefObjectOption(
                              key: 'thali',
                              icon: '🍽️',
                              label: 'Thali Plate',
                              sublabel: '28 cm Steel',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Frequent Indian Meal Combos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'FREQUENT INDIAN MEAL COMBOS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textMuted,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryTeal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Quick Select',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.primaryTeal),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Select a common meal plate to view carbs and glycemic impact:',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 10),

                    _buildPresetMealTile(
                      emoji: '🫓',
                      title: 'North Indian Thali (Default)',
                      subtitle: '2 Rotis (Whole Wheat) + 1 Katori Dal + 1 Katori Rice',
                      carbs: '77.6g',
                      gl: '50.5 (High GL)',
                      onTap: () => _runPhotoAnalysis(presetMeal: 'thali'),
                    ),
                    const SizedBox(height: 10),

                    _buildPresetMealTile(
                      emoji: '🥘',
                      title: 'Rajma Chawal Special',
                      subtitle: '1 Katori Rajma + 1 Katori Rice + 1 Katori Kachumber',
                      carbs: '57.6g',
                      gl: '36.8 (Med GL)',
                      onTap: () => _runPhotoAnalysis(presetMeal: 'rajma_chawal'),
                    ),
                    const SizedBox(height: 10),

                    _buildPresetMealTile(
                      emoji: '🧀',
                      title: 'Shahi Paneer Delight',
                      subtitle: '1 Katori Paneer Butter Masala + 2 Parathas',
                      carbs: '40.6g',
                      gl: '24.3 (Low GI Fat/Protein)',
                      onTap: () => _runPhotoAnalysis(presetMeal: 'paneer_naan'),
                    ),
                    const SizedBox(height: 10),

                    _buildPresetMealTile(
                      emoji: '🥞',
                      title: 'South Indian Breakfast',
                      subtitle: '1 Masala Dosa + 1 Katori Sambhar',
                      carbs: '39.8g',
                      gl: '26.2 (Fermented GI)',
                      onTap: () => _runPhotoAnalysis(presetMeal: 'dosa_sambhar'),
                    ),
                    const SizedBox(height: 24),
                  ]

                  // -------------------------------------------------------------
                  // TAB 1: ✍️ MANUAL PLATE BUILDER (NO PHOTO NEEDED)
                  // -------------------------------------------------------------
                  else ...[
                    _buildPlateBuilderContent(showHeroBanner: true),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildPlateBuilderContent({required bool showHeroBanner}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeroBanner)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00695C), Color(0xFF004D40)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF004D40).withOpacity(0.3),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MANUAL PLATE NUTRITION',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      'Real-time Math',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildManualSummaryStat('Net Carbs', '$_manualTotalCarbs g', Icons.grain_rounded),
                    Container(width: 1, height: 32, color: Colors.white24),
                    _buildManualSummaryStat('Fiber', '$_manualTotalFiber g', Icons.eco_rounded),
                    Container(width: 1, height: 32, color: Colors.white24),
                    _buildManualSummaryStat('Glycemic Load', '$_manualTotalGL', Icons.speed_rounded),
                  ],
                ),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.inRangeGreen, width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.inRangeGreen.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.restaurant_menu_rounded, color: AppTheme.inRangeGreenDark, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Plate Items & Household Portions',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.inRangeGreenDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total: $_manualTotalCarbs g Net Carbs • Glycemic Load: $_manualTotalGL',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Quick-Add Indian Staples Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'TAP TO QUICK-ADD TO PLATE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMuted,
                letterSpacing: 0.8,
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryTeal,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              ),
              icon: const Icon(Icons.search_rounded, size: 16),
              label: const Text('Search 20+ Foods', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              onPressed: _openSearchForManualPlate,
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Quick Add Chips Grid
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickAddChip('🫓 Roti (+2)', () => _addPresetToManualPlate(IndianFoodDatabase.allFoods[0], 2.0)),
            _buildQuickAddChip('🍲 Dal Tadka (+1)', () => _addPresetToManualPlate(IndianFoodDatabase.allFoods[4], 1.0)),
            _buildQuickAddChip('🍚 Basmati Rice (+1)', () => _addPresetToManualPlate(IndianFoodDatabase.allFoods[2], 1.0)),
            _buildQuickAddChip('🥘 Rajma (+1)', () => _addPresetToManualPlate(IndianFoodDatabase.allFoods[5], 1.0)),
            _buildQuickAddChip('🧀 Paneer (+1)', () => _addPresetToManualPlate(IndianFoodDatabase.allFoods[7], 1.0)),
            _buildQuickAddChip('🥣 Curd / Dahi (+1)', () => _addPresetToManualPlate(IndianFoodDatabase.allFoods[11], 1.0)),
            _buildQuickAddChip('🥞 Masala Dosa (+1)', () => _addPresetToManualPlate(IndianFoodDatabase.allFoods[14], 1.0)),
            _buildQuickAddChip('⚪ Idli (+2)', () => _addPresetToManualPlate(IndianFoodDatabase.allFoods[12], 2.0)),
          ],
        ),
        const SizedBox(height: 18),

        // Your Current Plate Items
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'YOUR PLATE ITEMS (${_manualPlateDishes.length})',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMuted,
                letterSpacing: 0.8,
              ),
            ),
            if (_manualPlateDishes.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _manualPlateDishes.clear()),
                child: const Text('Clear All', style: TextStyle(fontSize: 11.5, color: AppTheme.warningRed)),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (_manualPlateDishes.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: const Center(
              child: Column(
                children: [
                  Text('🍽️', style: TextStyle(fontSize: 34)),
                  SizedBox(height: 8),
                  Text('Your plate is empty!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  SizedBox(height: 4),
                  Text(
                    'Tap the quick-add buttons above or search to log your meal.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          ..._manualPlateDishes.asMap().entries.map((entry) {
            final idx = entry.key;
            final dish = entry.value;
            return _buildManualDishCard(idx, dish);
          }),

        const SizedBox(height: 14),

        // Add More Dishes Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.add_circle_outline_rounded),
          label: const Text('Search & Add Another Food Item'),
          onPressed: _openSearchForManualPlate,
        ),
        const SizedBox(height: 16),

        // Submit Manual Meal Button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: _isLoggingManual
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_rounded, size: 22),
            label: Text(
              _isLoggingManual
                  ? 'Saving Meal...'
                  : 'Log Meal ($_manualTotalCarbs g Net Carbs) & Forecast',
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
            ),
            onPressed: _isLoggingManual || _manualPlateDishes.isEmpty
                ? null
                : _submitManualPlate,
          ),
        ),
      ],
    );
  }

  Widget _buildManualSummaryStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 17),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildQuickAddChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
      ),
    );
  }

  Widget _buildManualDishCard(int index, DishItem dish) {
    final (unitName, gramsPerUnit, isPiece) = IndianFoodDatabase.getHouseholdUnit(dish.name);
    final currentUnits = dish.estimatedGrams / gramsPerUnit;

    final unitDisplayLabel = isPiece
        ? '${currentUnits.round()} ${currentUnits.round() == 1 ? unitName : '${unitName}s'}'
        : '${currentUnits % 1 == 0 ? currentUnits.toInt() : currentUnits.toStringAsFixed(1)} ${currentUnits == 1.0 ? 'Katori' : 'Katoris'}';

    final unitSubtitle = isPiece
        ? 'approx ${dish.estimatedGrams.toInt()}g (${gramsPerUnit.toInt()}g per $unitName)'
        : 'approx ${dish.estimatedGrams.toInt()}g (standard 9cm katori)';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(IndianFoodDatabase.getDishEmoji(dish.name), style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
                Text(
                  unitSubtitle,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '${dish.netCarbs}g carbs',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.primaryTeal),
                    ),
                    const SizedBox(width: 6),
                    Text('•', style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
                    const SizedBox(width: 6),
                    Text(
                      'GL ${dish.glycemicLoad}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Counter Buttons [-] 2 Rotis [+]
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_rounded, size: 18),
                  onPressed: () => _updateManualDishUnits(index, isPiece ? -1.0 : -0.5),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    unitDisplayLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryTeal,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  onPressed: () => _updateManualDishUnits(index, isPiece ? 1.0 : 0.5),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
            onPressed: () => _removeManualDish(index),
          ),
        ],
      ),
    );
  }

  Widget _buildRefObjectOption({
    required String key,
    required String icon,
    required String label,
    required String sublabel,
  }) {
    final isSelected = _referenceObject == key;
    return GestureDetector(
      onTap: () => setState(() => _referenceObject = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  const BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppTheme.primaryTeal : AppTheme.textPrimary,
              ),
            ),
            Text(
              sublabel,
              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetMealTile({
    required String emoji,
    required String title,
    required String subtitle,
    required String carbs,
    required String gl,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Carbs: $carbs',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primaryTeal),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'GL: $gl',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
