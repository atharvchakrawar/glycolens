import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/disclaimer_banner.dart';

class AlertsScreen extends StatefulWidget {
  final RuleOf15Guidance? guidance;

  const AlertsScreen({super.key, this.guidance});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  int _secondsLeft = 900; // 15 mins (900 seconds)
  bool _isRunning = false;
  Timer? _timer;

  // Interactive Checklist State
  final Map<int, bool> _completedSteps = {
    1: false,
    2: false,
    3: false,
    4: false,
  };

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.guidance?.timerSeconds ?? 900;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() {
        _isRunning = true;
        _completedSteps[1] = true;
        _completedSteps[2] = true;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsLeft > 0) {
          setState(() => _secondsLeft--);
        } else {
          timer.cancel();
          setState(() => _isRunning = false);
          _showTimeUpAlert();
        }
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _secondsLeft = 900;
      _completedSteps[1] = false;
      _completedSteps[2] = false;
      _completedSteps[3] = false;
      _completedSteps[4] = false;
    });
  }

  void _setDemoTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _secondsLeft = seconds;
      _isRunning = true;
      _completedSteps[1] = true;
      _completedSteps[2] = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        timer.cancel();
        setState(() => _isRunning = false);
        _showTimeUpAlert();
      }
    });
  }

  void _showTimeUpAlert() {
    NotificationService.sendAlert(
      title: '⏰ Rule of 15: 15 Minutes Elapsed!',
      body: 'Step 3 Protocol: Please re-check your blood glucose now.',
      tag: 'rule-of-15-timer',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.alarm_on_rounded, color: AppTheme.inRangeGreen, size: 28),
            SizedBox(width: 8),
            Text('15 Minutes Elapsed'),
          ],
        ),
        content: const Text(
          'Step 3 Protocol: Please re-check your blood glucose now.\n\n'
          '• If still under 70 mg/dL: Take another 15g fast-acting carbs and restart timer.\n'
          '• If 70 mg/dL or higher: Have a small snack with complex carbs and protein to sustain levels.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              setState(() => _completedSteps[3] = true);
              Navigator.pop(ctx);
            },
            child: const Text('Confirm Re-check'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSecs) {
    final m = totalSecs ~/ 60;
    final s = totalSecs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = (900 - _secondsLeft) / 900.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rule of 15 Protocol'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const DisclaimerBanner(compact: true),
            const SizedBox(height: 14),

            // Hypo Timer Hero Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.warningRed, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.warningRed.withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emergency_rounded, color: AppTheme.warningRed, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Hypoglycemia Recovery Protocol',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.warningRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Circular Timer Progress Ring
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 170,
                        height: 170,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 10,
                          backgroundColor: Colors.white,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.warningRed),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(_secondsLeft),
                            style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.warningRed,
                              letterSpacing: -1.0,
                            ),
                          ),
                          Text(
                            _isRunning ? 'WAITING TO RE-TEST' : '15-MIN PROTOCOL',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF991B1B),
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Timer Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _isRunning ? AppTheme.watchAmberDark : AppTheme.warningRed,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        icon: Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        label: Text(_isRunning ? 'Pause' : 'Start 15m Timer'),
                        onPressed: _toggleTimer,
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Reset'),
                        onPressed: _resetTimer,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Fast-Acting Carbs Reference Cards (Specific to Indian diet)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'FAST-ACTING CARBS (TAKE 15 GRAMS NOW)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildCarbSourceTile(
                    emoji: '🧃',
                    title: 'Fruit Juice',
                    amount: '1/2 cup (120 ml)',
                    carbs: '~15g Carbs',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCarbSourceTile(
                    emoji: '🍬',
                    title: 'Sugar / Tablets',
                    amount: '3 tsp / 3 tabs',
                    carbs: '~15g Carbs',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _buildCarbSourceTile(
                    emoji: '🍯',
                    title: 'Honey / Jaggery',
                    amount: '1 tablespoon',
                    carbs: '~17g Carbs',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildCarbSourceTile(
                    emoji: '🥤',
                    title: 'Regular Soda',
                    amount: '150 ml (Half can)',
                    carbs: '~15g Carbs',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Clinical Note on Fats
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppTheme.watchAmberDark, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Avoid chocolate, milk, or biscuits during acute hypo: fat delays carbohydrate absorption!',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Interactive 4-Step Protocol Checklist
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'CLINICAL 4-STEP RECOVERY PROTOCOL',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(height: 8),

            _buildChecklistStep(
              stepNumber: 1,
              title: 'Consume 15g Fast-Acting Carbs',
              description: 'Take one of the quick carb sources above immediately. Do not over-treat to avoid rebound hyperglycemia.',
            ),
            _buildChecklistStep(
              stepNumber: 2,
              title: 'Wait 15 Minutes (Timer Running)',
              description: 'Rest quietly while rapid-acting simple sugars enter the bloodstream and elevate glucose.',
            ),
            _buildChecklistStep(
              stepNumber: 3,
              title: 'Re-test Blood Glucose',
              description: 'Verify if sensor or fingerstick glucose has recovered above 70 mg/dL.',
            ),
            _buildChecklistStep(
              stepNumber: 4,
              title: 'Repeat or Stabilize with Snack',
              description: 'If still < 70 mg/dL, take another 15g carbs and reset timer. If recovered, eat a small protein/complex carb snack.',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCarbSourceTile({
    required String emoji,
    required String title,
    required String amount,
    required String carbs,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Text(amount, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.inRangeGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              carbs,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.inRangeGreenDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistStep({
    required int stepNumber,
    required String title,
    required String description,
  }) {
    final isDone = _completedSteps[stepNumber] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFFF0FDF4) : AppTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone ? AppTheme.inRangeGreen : AppTheme.cardBorder,
          width: isDone ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _completedSteps[stepNumber] = !isDone;
              });
            },
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isDone ? AppTheme.inRangeGreen : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDone ? AppTheme.inRangeGreen : const Color(0xFF94A3B8),
                  width: 2,
                ),
              ),
              child: isDone
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : Center(
                      child: Text(
                        '$stepNumber',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: isDone ? AppTheme.inRangeGreenDark : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
