import 'dart:convert';

class CGMReading {
  final DateTime timestamp;
  final double glucoseMgDl;
  final String trendArrow;
  final double rateOfChange;

  CGMReading({
    required this.timestamp,
    required this.glucoseMgDl,
    this.trendArrow = 'FLAT',
    this.rateOfChange = 0.0,
  });

  factory CGMReading.fromJson(Map<String, dynamic> json) {
    return CGMReading(
      timestamp: DateTime.parse(json['timestamp']),
      glucoseMgDl: (json['glucose_mg_dl'] as num).toDouble(),
      trendArrow: json['trend_arrow'] ?? 'FLAT',
      rateOfChange: (json['rate_of_change'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'glucose_mg_dl': glucoseMgDl,
      'trend_arrow': trendArrow,
      'rate_of_change': rateOfChange,
    };
  }
}

class DishItem {
  final String name;
  final String? hindiName;
  final String? category;
  final double confidence;
  final List<double> bbox;
  double estimatedGrams;
  final double carbsPer100g;
  double netCarbs;
  double dietaryFiber;
  final double glycemicIndex;
  double glycemicLoad;
  bool reviewFlag;

  DishItem({
    required this.name,
    this.hindiName,
    this.category,
    required this.confidence,
    required this.bbox,
    required this.estimatedGrams,
    required this.carbsPer100g,
    required this.netCarbs,
    required this.dietaryFiber,
    required this.glycemicIndex,
    required this.glycemicLoad,
    required this.reviewFlag,
  });

  factory DishItem.fromJson(Map<String, dynamic> json) {
    return DishItem(
      name: json['name'],
      hindiName: json['hindi_name'],
      category: json['category'],
      confidence: (json['confidence'] as num).toDouble(),
      bbox: (json['bbox'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      estimatedGrams: (json['estimated_grams'] as num).toDouble(),
      carbsPer100g: (json['carbs_per_100g'] as num).toDouble(),
      netCarbs: (json['net_carbs'] as num).toDouble(),
      dietaryFiber: (json['dietary_fiber'] as num).toDouble(),
      glycemicIndex: (json['glycemic_index'] as num).toDouble(),
      glycemicLoad: (json['glycemic_load'] as num).toDouble(),
      reviewFlag: json['review_flag'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'hindi_name': hindiName,
      'category': category,
      'confidence': confidence,
      'bbox': bbox,
      'estimated_grams': estimatedGrams,
      'carbs_per_100g': carbsPer100g,
      'net_carbs': netCarbs,
      'dietary_fiber': dietaryFiber,
      'glycemic_index': glycemicIndex,
      'glycemic_load': glycemicLoad,
      'review_flag': reviewFlag,
    };
  }
}

class MealAnalysisResponse {
  final int? mealId;
  final DateTime timestamp;
  final List<DishItem> detectedDishes;
  final double totalNetCarbs;
  final double totalFiber;
  final double mealGlycemicLoad;
  final bool reviewRecommended;
  final double latencyMs;
  final String disclaimer;

  MealAnalysisResponse({
    this.mealId,
    required this.timestamp,
    required this.detectedDishes,
    required this.totalNetCarbs,
    required this.totalFiber,
    required this.mealGlycemicLoad,
    required this.reviewRecommended,
    required this.latencyMs,
    required this.disclaimer,
  });

  factory MealAnalysisResponse.fromJson(Map<String, dynamic> json) {
    return MealAnalysisResponse(
      mealId: json['meal_id'],
      timestamp: DateTime.parse(json['timestamp']),
      detectedDishes: (json['detected_dishes'] as List<dynamic>)
          .map((e) => DishItem.fromJson(e))
          .toList(),
      totalNetCarbs: (json['total_net_carbs'] as num).toDouble(),
      totalFiber: (json['total_fiber'] as num).toDouble(),
      mealGlycemicLoad: (json['meal_glycemic_load'] as num).toDouble(),
      reviewRecommended: json['review_recommended'] ?? false,
      latencyMs: (json['latency_ms'] as num).toDouble(),
      disclaimer: json['disclaimer'] ?? '',
    );
  }
}

class RuleOf15Guidance {
  final String title;
  final String step1;
  final String step2;
  final String step3;
  final String step4;
  final int timerSeconds;

  RuleOf15Guidance({
    required this.title,
    required this.step1,
    required this.step2,
    required this.step3,
    required this.step4,
    this.timerSeconds = 900,
  });

  factory RuleOf15Guidance.fromJson(Map<String, dynamic> json) {
    return RuleOf15Guidance(
      title: json['title'] ?? 'Rule of 15 Protocol',
      step1: json['step_1'] ?? '',
      step2: json['step_2'] ?? '',
      step3: json['step_3'] ?? '',
      step4: json['step_4'] ?? '',
      timerSeconds: json['timer_seconds'] ?? 900,
    );
  }
}

class AlertInfo {
  final String level; // NONE, WATCH, WARNING, CRITICAL
  final String title;
  final String message;
  final double glucoseReading;
  final int? timeToLowMin;
  final RuleOf15Guidance? ruleOf15Guidance;
  final DateTime timestamp;
  final String disclaimer;

  AlertInfo({
    required this.level,
    required this.title,
    required this.message,
    required this.glucoseReading,
    this.timeToLowMin,
    this.ruleOf15Guidance,
    required this.timestamp,
    required this.disclaimer,
  });

  factory AlertInfo.fromJson(Map<String, dynamic> json) {
    return AlertInfo(
      level: json['level'] ?? 'NONE',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      glucoseReading: (json['glucose_reading'] as num).toDouble(),
      timeToLowMin: json['time_to_low_min'],
      ruleOf15Guidance: json['rule_of_15_guidance'] != null
          ? RuleOf15Guidance.fromJson(json['rule_of_15_guidance'])
          : null,
      timestamp: DateTime.parse(json['timestamp']),
      disclaimer: json['disclaimer'] ?? '',
    );
  }
}

class GlucoseForecastResponse {
  final double currentGlucose;
  final double forecast30m;
  final double forecast60m;
  final double confidenceBandLow30m;
  final double confidenceBandHigh30m;
  final double confidenceBandLow60m;
  final double confidenceBandHigh60m;
  final bool hypoRisk;
  final int? timeToLowMin;
  final AlertInfo? alert;
  final double latencyMs;
  final String disclaimer;

  GlucoseForecastResponse({
    required this.currentGlucose,
    required this.forecast30m,
    required this.forecast60m,
    required this.confidenceBandLow30m,
    required this.confidenceBandHigh30m,
    required this.confidenceBandLow60m,
    required this.confidenceBandHigh60m,
    required this.hypoRisk,
    this.timeToLowMin,
    this.alert,
    required this.latencyMs,
    required this.disclaimer,
  });

  factory GlucoseForecastResponse.fromJson(Map<String, dynamic> json) {
    return GlucoseForecastResponse(
      currentGlucose: (json['current_glucose'] as num).toDouble(),
      forecast30m: (json['forecast_30m'] as num).toDouble(),
      forecast60m: (json['forecast_60m'] as num).toDouble(),
      confidenceBandLow30m: (json['confidence_band_low_30m'] as num).toDouble(),
      confidenceBandHigh30m: (json['confidence_band_high_30m'] as num).toDouble(),
      confidenceBandLow60m: (json['confidence_band_low_60m'] as num).toDouble(),
      confidenceBandHigh60m: (json['confidence_band_high_60m'] as num).toDouble(),
      hypoRisk: json['hypo_risk'] ?? false,
      timeToLowMin: json['time_to_low_min'],
      alert: json['alert'] != null ? AlertInfo.fromJson(json['alert']) : null,
      latencyMs: (json['latency_ms'] as num?)?.toDouble() ?? 0.0,
      disclaimer: json['disclaimer'] ?? '',
    );
  }
}
