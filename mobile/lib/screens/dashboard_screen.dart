import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glucose_gauge.dart';
import '../widgets/cgm_chart.dart';
import '../widgets/disclaimer_banner.dart';
import 'alerts_screen.dart';
import 'meal_capture_screen.dart';
import '../services/notification_service.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  String _selectedScenario = 'post_meal_low';
  bool _isLoading = true;
  List<CGMReading> _cgmReadings = [];
  GlucoseForecastResponse? _forecast;
  double _lastLatencyMs = 18.0;

  @override
  void initState() {
    super.initState();
    _loadScenarioData(_selectedScenario);
    NotificationService.requestPermission();
  }

  void _triggerHypoNotification(GlucoseForecastResponse forecast) {
    if (forecast.alert == null || forecast.alert!.level == 'NONE') return;

    final int minutes = forecast.alert!.timeToLowMin ?? (forecast.forecast30m < 70 ? 30 : 60);
    final int predictedGlucose = (forecast.forecast30m < 70 ? forecast.forecast30m : forecast.forecast60m).toInt();

    String title;
    String body;

    if (forecast.alert!.level == 'CRITICAL') {
      title = '🚨 CRITICAL HYPO ALERT (<54 mg/dL)';
      body = 'Blood glucose is critically low! Consume 15g fast carbs (juice / 3 tsp sugar) immediately!';
    } else {
      title = '⚠️ Hypo Warning: Predicted in ~$minutes mins';
      body = 'Glucose dropping to $predictedGlucose mg/dL in ~$minutes min! Eat a fruit (banana/apple) or 15g carbs now to control and prevent a crash!';
    }

    NotificationService.sendAlert(
      title: title,
      body: body,
      tag: 'glycolens-hypo-alert',
    );
  }

  Future<void> updateMealCarbs(double confirmedCarbs) async {
    final updatedForecast = await ApiService.forecastGlucose(
      recentReadings: _cgmReadings,
      confirmedCarbs: confirmedCarbs,
    );
    if (mounted) {
      setState(() => _forecast = updatedForecast);
      _triggerHypoNotification(updatedForecast);
    }
  }

  Future<void> _loadScenarioData(String scenario) async {
    setState(() => _isLoading = true);
    final stopwatch = Stopwatch()..start();
    final readings = await ApiService.fetchDemoCGM(scenario: scenario);
    final forecast = await ApiService.forecastGlucose(
      recentReadings: readings,
      activeInsulin: scenario == 'post_meal_low' ? 1.5 : 0.0,
      confirmedCarbs: scenario == 'post_meal_low' ? 0.0 : 45.0,
    );
    stopwatch.stop();

    if (mounted) {
      setState(() {
        _selectedScenario = scenario;
        _cgmReadings = readings;
        _forecast = forecast;
        _lastLatencyMs = forecast.latencyMs > 0 ? forecast.latencyMs : stopwatch.elapsedMilliseconds.toDouble();
        _isLoading = false;
      });

      _triggerHypoNotification(forecast);
    }
  }

  void _showSettingsDialog() {
    final controller = TextEditingController(text: ApiService.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backend API Server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Base URL:\n'
              '• Web / PWA: Automatically connects to host origin.\n'
              '• Manual Override below if using custom tunnel.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Server Base URL',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ApiService.setBaseUrl(controller.text.trim());
              Navigator.pop(ctx);
              _loadScenarioData(_selectedScenario);
            },
            child: const Text('Save & Reload'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final latestReading = _cgmReadings.isNotEmpty ? _cgmReadings.last : null;
    final currentGlucose = latestReading?.glucoseMgDl ?? 110.0;
    final trendArrow = latestReading?.trendArrow ?? 'FLAT';
    final velocity = latestReading?.rateOfChange ?? 0.0;
    final alert = _forecast?.alert;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.monitor_heart_rounded, color: AppTheme.primaryTeal, size: 24),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'GlycoLens',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                    ),
                    const SizedBox(width: 6),
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
                const Text(
                  'T1D AI Decision-Support • Rotis & Katoris',
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Live Backend Latency Chip
          GestureDetector(
            onTap: _showSettingsDialog,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.inRangeGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.inRangeGreen.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.inRangeGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_lastLatencyMs.toStringAsFixed(0)}ms',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.inRangeGreenDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined, color: AppTheme.primaryTeal),
            tooltip: 'Phone Alerts',
            onPressed: () {
              NotificationService.requestPermission();
              NotificationService.sendAlert(
                title: '⚠️ Hypo Warning: Predicted in ~30 mins',
                body: 'Glucose dropping to 58 mg/dL in 30 min. Eat a fruit (banana/apple) or 15g fast carbs now to control and prevent a crash!',
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🔔 Notification sent! Check your phone notification bar.'),
                  backgroundColor: AppTheme.primaryTeal,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppTheme.textSecondary),
            tooltip: 'Server Settings',
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 3, color: AppTheme.primaryTeal),
                  SizedBox(height: 16),
                  Text('Forecasting glucose trajectory...', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => _loadScenarioData(_selectedScenario),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Regulatory Disclaimer
                    const DisclaimerBanner(compact: true),
                    const SizedBox(height: 14),

                    // Hypoglycemia Early-Warning Alert Card (If Active)
                    if (alert != null && alert.level != 'NONE') ...[
                      _buildAlertBanner(alert),
                      const SizedBox(height: 14),
                    ],

                    // Elevated Glucose Gauge
                    GlucoseGauge(
                      glucose: currentGlucose,
                      trendArrow: trendArrow,
                      rateOfChange: velocity,
                      alertLevel: alert?.level,
                    ),
                    const SizedBox(height: 14),

                    // Forecast Summary Cards (+30m & +60m)
                    if (_forecast != null)
                      Row(
                        children: [
                          Expanded(
                            child: _buildForecastMetricCard(
                              title: 'Projected +30m',
                              value: '${_forecast!.forecast30m.toInt()} mg/dL',
                              band: '${_forecast!.confidenceBandLow30m.toInt()}–${_forecast!.confidenceBandHigh30m.toInt()}',
                              isLow: _forecast!.forecast30m < 70,
                              drop: _forecast!.forecast30m - currentGlucose,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildForecastMetricCard(
                              title: 'Projected +60m',
                              value: '${_forecast!.forecast60m.toInt()} mg/dL',
                              band: '${_forecast!.confidenceBandLow60m.toInt()}–${_forecast!.confidenceBandHigh60m.toInt()}',
                              isLow: _forecast!.forecast60m < 70,
                              drop: _forecast!.forecast60m - currentGlucose,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),

                    // CGM Curve & Forecast Chart
                    CGMChart(
                      readings: _cgmReadings,
                      forecast: _forecast,
                    ),
                    const SizedBox(height: 16),

                    // Action Card 1: Analyze Indian Meal
                    Container(
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
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MealCaptureScreen(),
                              ),
                            );
                            if (result != null && result is MealAnalysisResponse) {
                              final updatedForecast = await ApiService.forecastGlucose(
                                recentReadings: _cgmReadings,
                                confirmedCarbs: result.totalNetCarbs,
                              );
                              setState(() => _forecast = updatedForecast);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Center(
                                    child: Text('🍲', style: TextStyle(fontSize: 26)),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Capture & Estimate Indian Meal',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        'AI Sizing + 9cm Katori Calibration → Net Carbs',
                                        style: TextStyle(fontSize: 11.5, color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Action Card 2: Manual Food Log (Rotis & Katoris - No Photo)
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primaryTeal.withOpacity(0.4), width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MealCaptureScreen(initialMode: 1),
                              ),
                            );
                            if (result != null && result is MealAnalysisResponse) {
                              final updatedForecast = await ApiService.forecastGlucose(
                                recentReadings: _cgmReadings,
                                confirmedCarbs: result.totalNetCarbs,
                              );
                              setState(() => _forecast = updatedForecast);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryTeal.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryTeal, size: 28),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Log Meal Manually (No Photo)',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Count Rotis, Katoris of Dal, Rice, etc.',
                                        style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.primaryTeal),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Test Simulation Scenarios (Clean & Collapsible at bottom)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.tune_rounded, size: 15, color: AppTheme.textSecondary),
                                  SizedBox(width: 6),
                                  Text(
                                    'CGM STREAM SIMULATOR',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textMuted,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Testing Controls',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildScenarioChip(
                                  label: 'Post-Meal Low',
                                  scenarioKey: 'post_meal_low',
                                  icon: '🔴',
                                  subtitle: 'Dropping',
                                ),
                                const SizedBox(width: 8),
                                _buildScenarioChip(
                                  label: 'Post-Meal Stable',
                                  scenarioKey: 'post_meal_stable',
                                  icon: '🟢',
                                  subtitle: 'In-Range',
                                ),
                                const SizedBox(width: 8),
                                _buildScenarioChip(
                                  label: 'Overnight Low',
                                  scenarioKey: 'overnight_low',
                                  icon: '🌙',
                                  subtitle: 'Nocturnal',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildScenarioChip({
    required String label,
    required String scenarioKey,
    required String icon,
    required String subtitle,
  }) {
    final isSelected = _selectedScenario == scenarioKey;
    return InkWell(
      onTap: () => _loadScenarioData(scenarioKey),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryTeal.withOpacity(0.12) : AppTheme.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primaryTeal : AppTheme.cardBorder,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryTeal.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AppTheme.primaryTeal : AppTheme.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? AppTheme.primaryTeal.withOpacity(0.8) : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertBanner(AlertInfo alert) {
    final isCritical = alert.level == 'CRITICAL';
    final alertColor = isCritical ? AppTheme.criticalCrimson : AppTheme.warningRed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: alertColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: alertColor.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: alertColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: alertColor,
                      ),
                    ),
                    Text(
                      'AI Predicted Hypo in ~${alert.timeToLowMin ?? 35} minutes',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: alertColor.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            alert.message,
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary, height: 1.35),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: alertColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.timer_outlined, size: 18),
              label: const Text('Launch Rule of 15 Recovery Timer'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AlertsScreen(guidance: alert.ruleOf15Guidance),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastMetricCard({
    required String title,
    required String value,
    required String band,
    required bool isLow,
    required double drop,
  }) {
    final statusColor = isLow ? AppTheme.warningRed : AppTheme.inRangeGreenDark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLow ? AppTheme.warningRed.withOpacity(0.5) : AppTheme.cardBorder,
          width: isLow ? 1.5 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
              Icon(
                drop < 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                size: 16,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: statusColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '90% CI: $band',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
