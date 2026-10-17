import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  static String? _customBaseUrl;

  static String get baseUrl {
    if (_customBaseUrl != null) return _customBaseUrl!;
    // In Flutter Web, use the exact origin the app was loaded from (handles Cloudflare tunnel, LAN IP, and localhost automatically)
    try {
      if (Uri.base.host.isNotEmpty) {
        return Uri.base.origin;
      }
    } catch (_) {}
    return 'http://127.0.0.1:8000';
  }

  static void setBaseUrl(String url) {
    _customBaseUrl = url.replaceAll(RegExp(r'/+$'), '');
  }


  // 1. Fetch Scripted Demo CGM Readings
  static Future<List<CGMReading>> fetchDemoCGM({String scenario = 'post_meal_low'}) async {
    try {
      final uri = Uri.parse('$baseUrl/demo/cgm?scenario=$scenario');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((e) => CGMReading.fromJson(e)).toList();
      }
    } catch (_) {
      // Fallback local mock if offline
    }
    return _generateFallbackCGM(scenario);
  }

  // 2. Predict Glucose at +30m and +60m
  static Future<GlucoseForecastResponse> forecastGlucose({
    required List<CGMReading> recentReadings,
    double activeInsulin = 0.0,
    double confirmedCarbs = 0.0,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/glucose/forecast');
      final payload = jsonEncode({
        'recent_readings': recentReadings.map((e) => e.toJson()).toList(),
        'active_insulin_units': activeInsulin,
        'confirmed_carbs_grams': confirmedCarbs,
      });

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        return GlucoseForecastResponse.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}

    // Offline fallback estimation
    final current = recentReadings.isNotEmpty ? recentReadings.last.glucoseMgDl : 110.0;
    return GlucoseForecastResponse(
      currentGlucose: current,
      forecast30m: (current - 22.0).clamp(40.0, 400.0),
      forecast60m: (current - 40.0).clamp(40.0, 400.0),
      confidenceBandLow30m: (current - 35.0).clamp(35.0, 400.0),
      confidenceBandHigh30m: current - 10.0,
      confidenceBandLow60m: (current - 55.0).clamp(35.0, 400.0),
      confidenceBandHigh60m: current - 25.0,
      hypoRisk: current < 95.0,
      timeToLowMin: 35,
      alert: current < 95.0
          ? AlertInfo(
              level: 'WARNING',
              title: 'Early Hypoglycemia Warning',
              message: 'Glucose anticipated to reach < 70 mg/dL in ~35 minutes. Consider 15g fast-acting carbs.',
              glucoseReading: current,
              timeToLowMin: 35,
              ruleOf15Guidance: RuleOf15Guidance(
                title: 'Rule of 15 Protocol',
                step1: 'Consume 15g fast-acting carbohydrate (e.g. 1/2 cup juice or 3 glucose tablets).',
                step2: 'Wait 15 minutes.',
                step3: 'Retest blood glucose.',
                step4: 'If still < 70 mg/dL, repeat with 15g carbs.',
              ),
              timestamp: DateTime.now(),
              disclaimer: 'Decision-support only. Not a medical device.',
            )
          : null,
      latencyMs: 15.0,
      disclaimer: 'Decision-support only. Not a medical device.',
    );
  }

  // 3. Analyze Indian Meal Image
  static Future<MealAnalysisResponse> analyzeMeal({
    String? imageBase64,
    String referenceObject = 'katori',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/meal/analyze');
      final payload = jsonEncode({
        'image_base64': imageBase64,
        'reference_object': referenceObject,
        'meal_type': 'lunch',
      });

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        return MealAnalysisResponse.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}

    // Offline fallback meal response
    return MealAnalysisResponse(
      mealId: 1,
      timestamp: DateTime.now(),
      detectedDishes: [
        DishItem(
          name: 'Roti (Whole Wheat)',
          hindiName: 'Chapati',
          category: 'Breads & Cereals',
          confidence: 0.94,
          bbox: [0.10, 0.15, 0.45, 0.50],
          estimatedGrams: 70.0,
          carbsPer100g: 46.1,
          netCarbs: 25.1,
          dietaryFiber: 7.1,
          glycemicIndex: 62.0,
          glycemicLoad: 15.6,
          reviewFlag: false,
        ),
        DishItem(
          name: 'Dal Tadka (Yellow Lentil)',
          hindiName: 'Peeli Dal',
          category: 'Lentils & Pulses',
          confidence: 0.89,
          bbox: [0.50, 0.15, 0.88, 0.52],
          estimatedGrams: 150.0,
          carbsPer100g: 11.5,
          netCarbs: 11.1,
          dietaryFiber: 6.2,
          glycemicIndex: 42.0,
          glycemicLoad: 4.7,
          reviewFlag: false,
        ),
        DishItem(
          name: 'Steamed Basmati Rice',
          hindiName: 'Chawal',
          category: 'Cereals & Grains',
          confidence: 0.85,
          bbox: [0.25, 0.55, 0.75, 0.90],
          estimatedGrams: 150.0,
          carbsPer100g: 28.2,
          netCarbs: 41.4,
          dietaryFiber: 0.9,
          glycemicIndex: 73.0,
          glycemicLoad: 30.2,
          reviewFlag: false,
        ),
      ],
      totalNetCarbs: 77.6,
      totalFiber: 14.2,
      mealGlycemicLoad: 50.5,
      reviewRecommended: false,
      latencyMs: 18.0,
      disclaimer: 'Decision-support only. Not a medical device.',
    );
  }

  // 3b. Log Manual Indian Meal (No Photo)
  static Future<MealAnalysisResponse> logManualMeal(List<DishItem> dishes) async {
    try {
      final uri = Uri.parse('$baseUrl/meal/log');
      final payload = jsonEncode({
        'dishes': dishes.map((d) => d.toJson()).toList(),
        'meal_type': 'lunch',
      });

      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        return MealAnalysisResponse.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}

    final totalCarbs = double.parse(dishes.fold(0.0, (s, d) => s + d.netCarbs).toStringAsFixed(1));
    final totalFiber = double.parse(dishes.fold(0.0, (s, d) => s + d.dietaryFiber).toStringAsFixed(1));
    final totalGL = double.parse(dishes.fold(0.0, (s, d) => s + d.glycemicLoad).toStringAsFixed(1));

    return MealAnalysisResponse(
      mealId: DateTime.now().millisecondsSinceEpoch % 10000,
      timestamp: DateTime.now(),
      detectedDishes: dishes,
      totalNetCarbs: totalCarbs,
      totalFiber: totalFiber,
      mealGlycemicLoad: totalGL,
      reviewRecommended: false,
      latencyMs: 1.0,
      disclaimer: 'Decision-support only. Not a medical device.',
    );
  }

  // 4. Update Portion with 1 Tap
  static Future<MealAnalysisResponse?> updateMealPortions({
    required int mealId,
    required List<Map<String, dynamic>> dishUpdates,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/meal/$mealId/portions');
      final res = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'dish_updates': dishUpdates}),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        return MealAnalysisResponse.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  // 5. Fetch History
  static Future<List<MealAnalysisResponse>> fetchHistory() async {
    try {
      final uri = Uri.parse('$baseUrl/history');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((e) => MealAnalysisResponse.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  static List<CGMReading> _generateFallbackCGM(String scenario) {
    final now = DateTime.now();
    final values = [142, 138, 130, 118, 108, 98, 90, 84, 78, 72, 67, 63];
    return List.generate(values.length, (i) {
      return CGMReading(
        timestamp: now.subtract(Duration(minutes: (values.length - 1 - i) * 5)),
        glucoseMgDl: values[i].toDouble(),
        trendArrow: 'SINGLE_DOWN',
        rateOfChange: -1.6,
      );
    });
  }
}
