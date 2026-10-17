import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlucoseGauge extends StatelessWidget {
  final double glucose;
  final String trendArrow;
  final double rateOfChange;
  final String? alertLevel;

  const GlucoseGauge({
    super.key,
    required this.glucose,
    this.trendArrow = 'FLAT',
    this.rateOfChange = 0.0,
    this.alertLevel,
  });

  String _getArrowSymbol() {
    switch (trendArrow) {
      case 'DOUBLE_DOWN':
        return '↓↓';
      case 'SINGLE_DOWN':
        return '↓';
      case 'SINGLE_UP':
        return '↑';
      case 'DOUBLE_UP':
        return '↑↑';
      default:
        return '→';
    }
  }

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusIcon, statusLabel, statusDesc) =
        AppTheme.getGlucoseStatus(glucose, alertLevel: alertLevel);

    final isSevere = alertLevel == 'CRITICAL' || glucose < 54.0;
    final isWarning = alertLevel == 'WARNING' || glucose < 70.0;

    // Normalizing glucose to [0.0, 1.0] for the target range gauge bar (40 to 240 mg/dL)
    final clampedGlucose = glucose.clamp(40.0, 240.0);
    final gaugePercent = (clampedGlucose - 40.0) / (240.0 - 40.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: (isSevere || isWarning) ? statusColor : AppTheme.cardBorder,
          width: (isSevere || isWarning) ? 2.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(isSevere ? 0.22 : 0.10),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Status Pill Badge (Color + Icon + Label)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: statusColor.withOpacity(0.5), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Large Glucose Readout & Trend Arrow
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                glucose.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 76,
                  fontWeight: FontWeight.w900,
                  color: statusColor,
                  height: 1.0,
                  letterSpacing: -3,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getArrowSymbol(),
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                      height: 1.0,
                    ),
                  ),
                  const Text(
                    'mg/dL',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 3. Status Description Subtitle
          Text(
            statusDesc,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // 4. Target Range Indicator Bar (40 to 240 mg/dL with 70-180 Target Zone)
          Column(
            children: [
              // Pinpoint Marker Position
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final barWidth = constraints.maxWidth;
                  final markerLeft = (barWidth * gaugePercent - 8).clamp(0.0, barWidth - 16.0);
                  return SizedBox(
                    width: barWidth,
                    height: 12,
                    child: Stack(
                      children: [
                        Positioned(
                          left: markerLeft,
                          child: Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 20,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Gradient Colored Track
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    stops: [0.0, 0.15, 0.15, 0.70, 0.70, 1.0],
                    colors: [
                      AppTheme.warningRed,
                      AppTheme.warningRed,
                      AppTheme.inRangeGreen,
                      AppTheme.inRangeGreen,
                      AppTheme.highPurple,
                      AppTheme.highPurple,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('40 (Low)', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                  Text('Target: 70–180 mg/dL', style: TextStyle(fontSize: 11, color: AppTheme.inRangeGreenDark, fontWeight: FontWeight.w700)),
                  Text('240 (High)', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 5. Velocity Badge & Trend Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  rateOfChange < 0
                      ? Icons.trending_down_rounded
                      : rateOfChange > 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_flat_rounded,
                  size: 18,
                  color: rateOfChange < -1.5 ? AppTheme.warningRed : AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  rateOfChange != 0.0
                      ? '${rateOfChange < 0 ? "Dropping" : "Rising"} ${rateOfChange.abs().toStringAsFixed(1)} mg/dL/min'
                      : 'Stable trajectory (±0.0 mg/dL/min)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: rateOfChange < -1.5 ? AppTheme.warningRed : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('•', style: TextStyle(color: Color(0xFFCBD5E1))),
                const SizedBox(width: 8),
                const Text(
                  'TIR: 88%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.inRangeGreenDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
