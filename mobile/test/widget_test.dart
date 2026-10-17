import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glycolens_mobile/main.dart';
import 'package:glycolens_mobile/widgets/glucose_gauge.dart';

void main() {
  testWidgets('GlycoLensApp mounts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const GlycoLensApp());
    expect(find.text('GlycoLens'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('GlucoseGauge renders large text and status', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GlucoseGauge(
            glucose: 65.0,
            trendArrow: 'DOUBLE_DOWN',
            rateOfChange: -2.4,
            alertLevel: 'WARNING',
          ),
        ),
      ),
    );

    expect(find.text('65'), findsOneWidget);
    expect(find.text('mg/dL'), findsOneWidget);
    expect(find.text('↓↓'), findsOneWidget);
    expect(find.text('HYPO WARNING'), findsOneWidget);
    expect(find.text('Dropping 2.4 mg/dL/min'), findsOneWidget);
  });
}
