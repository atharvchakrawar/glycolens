import 'package:flutter/material.dart';
import 'models/models.dart';
import 'screens/dashboard_screen.dart';
import 'screens/meal_capture_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/history_screen.dart';
import 'theme/app_theme.dart';

import 'dart:math' as math;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GlycoLensApp());
}

class GlycoLensApp extends StatefulWidget {
  const GlycoLensApp({super.key});

  @override
  State<GlycoLensApp> createState() => _GlycoLensAppState();
}

class _GlycoLensAppState extends State<GlycoLensApp> {
  bool _forceFullScreen = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GlycoLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final isDesktop = mediaQuery.size.width > 540;

        // Native full-screen on mobile phones or small screens
        if (!isDesktop || _forceFullScreen) {
          return Stack(
            children: [
              child ?? const SizedBox.shrink(),
              if (_forceFullScreen && isDesktop)
                Positioned(
                  top: 14,
                  right: 14,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _forceFullScreen = false),
                    icon: const Icon(Icons.phone_android_rounded, size: 16),
                    label: const Text('📱 Switch to Phone View'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14B8A6),
                      foregroundColor: const Color(0xFF0A192F),
                      elevation: 8,
                    ),
                  ),
                ),
            ],
          );
        }

        // On laptop / desktop: render centered inside an authentic phone mockup
        final frameWidth = math.min(414.0, mediaQuery.size.width - 40);
        final frameHeight = math.min(860.0, mediaQuery.size.height - 65);

        return Scaffold(
          backgroundColor: const Color(0xFF070F1E),
          body: Stack(
            children: [
              // Subtle background ambient glows
              Positioned(
                top: -120,
                left: -120,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF14B8A6).withOpacity(0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: -120,
                right: -120,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00695C).withOpacity(0.12),
                  ),
                ),
              ),

              // Centered Phone Frame
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Desktop indicator toolbar
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF162642),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF1E3A5F)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.smartphone_rounded, size: 15, color: Color(0xFF14B8A6)),
                          const SizedBox(width: 8),
                          const Text(
                            'Mobile Phone View (Pixel / iPhone)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          InkWell(
                            onTap: () => setState(() => _forceFullScreen = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fullscreen_rounded, size: 14, color: Colors.white70),
                                  SizedBox(width: 4),
                                  Text(
                                    'Expand Fullscreen',
                                    style: TextStyle(fontSize: 11, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Phone Bezel Frame
                    Container(
                      width: frameWidth,
                      height: frameHeight,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(44),
                        border: Border.all(
                          color: const Color(0xFF334155),
                          width: 8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.65),
                            blurRadius: 40,
                            spreadRadius: 8,
                            offset: const Offset(0, 18),
                          ),
                          BoxShadow(
                            color: const Color(0xFF14B8A6).withOpacity(0.18),
                            blurRadius: 25,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(36),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: child ?? const SizedBox.shrink(),
                            ),
                            // Camera notch / Dynamic Island
                            Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                margin: const EdgeInsets.only(top: 8),
                                width: 95,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey<DashboardScreenState>();

  void _handleMealLogged(MealAnalysisResponse response) {
    setState(() => _currentIndex = 0);
    _dashboardKey.currentState?.updateMealCarbs(response.totalNetCarbs);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Meal Logged! +${response.totalNetCarbs}g Net Carbs applied to Glucose Forecast.',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.inRangeGreenDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  late final List<Widget> _screens = [
    DashboardScreen(
      key: _dashboardKey,
      onNavigateTab: (idx) => setState(() => _currentIndex = idx),
    ),
    MealCaptureScreen(
      onMealLogged: _handleMealLogged,
    ),
    const AlertsScreen(),
    const HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        indicatorColor: AppTheme.primaryTeal.withOpacity(0.18),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AppTheme.primaryTeal),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant_rounded, color: AppTheme.primaryTeal),
            label: 'Log Meal',
          ),
          NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm_on_rounded, color: AppTheme.warningRed),
            label: 'Rule of 15',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded, color: AppTheme.primaryTeal),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
