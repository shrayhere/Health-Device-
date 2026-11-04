import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthdeviceapp/main.dart';
import 'package:healthdeviceapp/repositories/mock_health_repository.dart';

void main() {
  testWidgets('HealthDevice app smoke test - Desktop responsive view', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = MockHealthRepository();
    await tester.pumpWidget(HealthDeviceApp(repository: repository));
    await tester.pumpAndSettle();

    // Verify key titles on Home screen matching reference Screen B
    expect(find.text('HealthDevice'), findsAtLeast(1));
    expect(find.text('Heart Rate'), findsOneWidget);
    expect(find.text('SpO₂'), findsOneWidget);
    expect(find.text('Posture'), findsOneWidget);
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text("Today's Activity"), findsOneWidget);
  });

  testWidgets('HealthDevice app smoke test - Mobile view', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final repository = MockHealthRepository();
    await tester.pumpWidget(HealthDeviceApp(repository: repository));
    await tester.pumpAndSettle();

    // Verify key titles on Home screen matching reference Screen B
    expect(find.text('HealthDevice'), findsAtLeast(1));
    expect(find.text('Heart Rate'), findsOneWidget);
    expect(find.text('SpO₂'), findsOneWidget);
    expect(find.text('Posture'), findsOneWidget);
    expect(find.text('Steps'), findsOneWidget);
    expect(find.text("Today's Activity"), findsOneWidget);

    // Test Navigation to Heart Rate detail screen (Screen D)
    await tester.tap(find.text('Heart Rate'));
    await tester.pumpAndSettle();
    expect(find.text('Normal range'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Min'), findsOneWidget);
    expect(find.text('Avg'), findsOneWidget);
    expect(find.text('Max'), findsOneWidget);

    // Pop back to Home
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    // Navigate to History (Screen C)
    await tester.tap(find.byIcon(Icons.history_rounded));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsWidgets);
    expect(find.text('Today'), findsOneWidget);

    // Navigate to Device (Screen E)
    await tester.tap(find.text('Device'));
    await tester.pumpAndSettle();
    expect(find.text('Device Name'), findsOneWidget);
    expect(find.text('Alarms'), findsOneWidget);
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('Device Settings'), findsOneWidget);

    // Open Device Settings inside Device screen
    await tester.ensureVisible(find.text('Device Settings'));
    await tester.tap(find.text('Device Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Sound'), findsOneWidget);
    expect(find.text('Display'), findsOneWidget);
    expect(find.text('LED'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Wi-Fi'), findsOneWidget);
    expect(find.text('Button Guide'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);

    // Pop back to Device
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();

    // Navigate to Profile (4th bottom nav tab)
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Health & Goals'), findsOneWidget);
  });
}
