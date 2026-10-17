import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/disclaimer_banner.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  List<MealAnalysisResponse> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await ApiService.fetchHistory();
    if (mounted) {
      setState(() {
        _history = history;
        _isLoading = false;
      });
    }
  }

  String _getDishEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('roti') || lower.contains('chapati') || lower.contains('paratha')) return '🫓';
    if (lower.contains('rice') || lower.contains('chawal') || lower.contains('biryani')) return '🍚';
    if (lower.contains('dal') || lower.contains('lentil')) return '🍲';
    if (lower.contains('paneer')) return '🧀';
    if (lower.contains('rajma') || lower.contains('chhole') || lower.contains('chana')) return '🥘';
    if (lower.contains('salad') || lower.contains('kachumber')) return '🥗';
    if (lower.contains('dosa') || lower.contains('idli')) return '🥞';
    if (lower.contains('samosa') || lower.contains('poha') || lower.contains('upma')) return '🥟';
    return '🍛';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal & Glycemic History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.primaryTeal))
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  const DisclaimerBanner(compact: true),
                  const SizedBox(height: 14),

                  if (_history.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceWhite,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryTeal.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.receipt_long_rounded, size: 40, color: AppTheme.primaryTeal),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No Logged Meals Yet',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Log an Indian meal via camera or manual builder to track your glycemic load history!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._history.map((meal) => _buildMealHistoryCard(meal)),
                ],
              ),
            ),
    );
  }

  Widget _buildMealHistoryCard(MealAnalysisResponse meal) {
    final dateFormat = DateFormat('EEE, MMM d • h:mm a');
    final (glBadgeColor, glBadgeText) = AppTheme.getGlycemicLoadBadge(meal.mealGlycemicLoad);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      dateFormat.format(meal.timestamp.toLocal()),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: glBadgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: glBadgeColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    'GL ${meal.mealGlycemicLoad} ($glBadgeText)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: glBadgeColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Dishes Chips with Emojis
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: meal.detectedDishes.map((d) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_getDishEmoji(d.name), style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Text(
                        '${d.name} (${d.estimatedGrams.toInt()}g)',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const Divider(height: 20, color: Color(0xFFF1F5F9)),

            // Carbs & Fiber Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Net Carbs: ', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    Text(
                      '${meal.totalNetCarbs} g',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppTheme.primaryTeal),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('Fiber: ', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    Text(
                      '${meal.totalFiber} g',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.inRangeGreenDark),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
