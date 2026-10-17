import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class CGMChart extends StatelessWidget {
  final List<CGMReading> readings;
  final GlucoseForecastResponse? forecast;

  const CGMChart({
    super.key,
    required this.readings,
    this.forecast,
  });

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(strokeWidth: 2.5),
              SizedBox(height: 12),
              Text(
                'Connecting to CGM stream...',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // Historical Points: X is minutes from start (0 to ~115)
    final historySpots = <FlSpot>[];
    for (int i = 0; i < readings.length; i++) {
      historySpots.add(FlSpot(i * 5.0, readings[i].glucoseMgDl));
    }

    // Forecast Spots (+30m and +60m)
    final forecastSpots = <FlSpot>[];
    final upperBandSpots = <FlSpot>[];
    final lowerBandSpots = <FlSpot>[];

    final lastX = (readings.length - 1) * 5.0;
    final lastY = readings.last.glucoseMgDl;

    if (forecast != null) {
      // Connect history to forecast
      forecastSpots.add(FlSpot(lastX, lastY));
      forecastSpots.add(FlSpot(lastX + 30.0, forecast!.forecast30m));
      forecastSpots.add(FlSpot(lastX + 60.0, forecast!.forecast60m));

      upperBandSpots.add(FlSpot(lastX, lastY));
      upperBandSpots.add(FlSpot(lastX + 30.0, forecast!.confidenceBandHigh30m));
      upperBandSpots.add(FlSpot(lastX + 60.0, forecast!.confidenceBandHigh60m));

      lowerBandSpots.add(FlSpot(lastX, lastY));
      lowerBandSpots.add(FlSpot(lastX + 30.0, forecast!.confidenceBandLow30m));
      lowerBandSpots.add(FlSpot(lastX + 60.0, forecast!.confidenceBandLow60m));
    }

    final maxX = lastX + (forecast != null ? 65.0 : 5.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 20, 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.cardBorder, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Continuous Glucose Trajectory',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Historical sensor curve + PyTorch forecast',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildLegendIndicator('Sensor', AppTheme.primaryTeal, false),
                  const SizedBox(width: 10),
                  _buildLegendIndicator('AI Model', AppTheme.watchAmber, true),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Chart
          SizedBox(
            height: 210,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: maxX,
                minY: 40,
                maxY: 240,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 40,
                  getDrawingHorizontalLine: (val) {
                    if (val == 70.0) {
                      // Clinical Hypoglycemia Threshold Line (Dashed Red)
                      return const FlLine(
                        color: AppTheme.warningRed,
                        strokeWidth: 2,
                        dashArray: [6, 4],
                      );
                    }
                    return FlLine(
                      color: const Color(0xFFE2E8F0),
                      strokeWidth: 0.8,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 50,
                      getTitlesWidget: (val, _) => Text(
                        val.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 30,
                      getTitlesWidget: (val, _) {
                        if (val == lastX) {
                          return const Text(
                            'Now',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: AppTheme.primaryTeal,
                            ),
                          );
                        }
                        if (val == lastX + 30) {
                          return const Text(
                            '+30m',
                            style: TextStyle(
                              color: AppTheme.watchAmberDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          );
                        }
                        if (val == lastX + 60) {
                          return const Text(
                            '+60m',
                            style: TextStyle(
                              color: AppTheme.watchAmberDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          );
                        }
                        final minsAgo = (lastX - val).toInt();
                        if (minsAgo > 0) {
                          return Text(
                            '-${minsAgo}m',
                            style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // 1. History Line with Gradient Area Fill
                  LineChartBarData(
                    spots: historySpots,
                    isCurved: true,
                    curveSmoothness: 0.30,
                    color: AppTheme.primaryTeal,
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryTeal.withOpacity(0.20),
                          AppTheme.primaryTeal.withOpacity(0.01),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, barData) => spot == historySpots.last,
                    ),
                  ),
                  // 2. Forecast Line (Dashed Orange)
                  if (forecast != null)
                    LineChartBarData(
                      spots: forecastSpots,
                      isCurved: true,
                      color: AppTheme.watchAmber,
                      barWidth: 3.0,
                      dashArray: [6, 4],
                      dotData: const FlDotData(show: true),
                    ),
                  // 3. Upper Confidence Band
                  if (forecast != null)
                    LineChartBarData(
                      spots: upperBandSpots,
                      isCurved: true,
                      color: AppTheme.watchAmber.withOpacity(0.4),
                      barWidth: 1.5,
                      dashArray: [3, 3],
                      dotData: const FlDotData(show: false),
                    ),
                  // 4. Lower Confidence Band
                  if (forecast != null)
                    LineChartBarData(
                      spots: lowerBandSpots,
                      isCurved: true,
                      color: AppTheme.watchAmber.withOpacity(0.4),
                      barWidth: 1.5,
                      dashArray: [3, 3],
                      dotData: const FlDotData(show: false),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Hypo Threshold Legend Label
          Row(
            children: [
              Container(width: 14, height: 2.5, color: AppTheme.warningRed),
              const SizedBox(width: 6),
              const Text(
                'Hypoglycemia Alert Boundary (70 mg/dL)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.warningRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendIndicator(String label, Color color, bool dashed) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
