import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthdeviceapp/models/health_metrics.dart';
import 'package:healthdeviceapp/repositories/mock_health_repository.dart';
import 'package:healthdeviceapp/repositories/auth_repository.dart';
import 'package:healthdeviceapp/services/ai_service.dart';
import 'package:healthdeviceapp/screens/alarms_screen.dart';
import 'package:healthdeviceapp/screens/device_screen.dart';
import 'package:healthdeviceapp/screens/history_screen.dart';
import 'package:healthdeviceapp/screens/led_settings_screen.dart';
import 'package:healthdeviceapp/screens/notifications_screen.dart';
import 'package:healthdeviceapp/screens/reminders_screen.dart';
import 'package:healthdeviceapp/screens/device_settings_screen.dart';
import 'package:healthdeviceapp/screens/settings_screen.dart';
import 'package:healthdeviceapp/screens/wifi_settings_screen.dart';
import 'package:healthdeviceapp/services/settings_storage_service.dart';
import 'package:healthdeviceapp/widgets/rgb_color_picker.dart';

void main() {
  group('1. RGB Color Model & Picker Unit Tests', () {
    test('RgbColor creation, hex formatting, PWM conversion', () {
      const color = RgbColor(red: 255, green: 80, blue: 20);
      expect(color.red, 255);
      expect(color.green, 80);
      expect(color.blue, 20);
      expect(color.toHexString(), '#FF5014');

      final flutterColor = color.toColor();
      final fromColor = RgbColor.fromColor(flutterColor);
      expect(fromColor.red, 255);
      expect(fromColor.green, 80);
      expect(fromColor.blue, 20);

      final json = color.toJson();
      final fromJson = RgbColor.fromJson(json);
      expect(fromJson, equals(color));
    });

    testWidgets(
      'RgbColorPicker renders wheel, preview, RGB sliders and updates',
      (tester) async {
        RgbColor? resultColor;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RgbColorPicker(
                initialColor: const RgbColor(red: 100, green: 150, blue: 200),
                title: 'Test Color Picker',
                onColorChanged: (c) => resultColor = c,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Test Color Picker'), findsOneWidget);
        expect(find.text('Brightness'), findsOneWidget);
        expect(find.text('PWM'), findsOneWidget);
        expect(find.text('R'), findsOneWidget);
        expect(find.text('G'), findsOneWidget);
        expect(find.text('B'), findsOneWidget);

        // Verify Apply Color button triggers callback
        await tester.tap(find.text('Apply Color'));
        await tester.pumpAndSettle();

        expect(resultColor, isNotNull);
        expect(resultColor!.red, 100);
        expect(resultColor!.green, 150);
        expect(resultColor!.blue, 200);
      },
    );
  });

  group('2. LED Settings Cleanup Tests', () {
    testWidgets(
      'LED Settings provides clean On/Off toggle',
      (tester) async {
        final repository = MockHealthRepository();
        await tester.pumpWidget(
          MaterialApp(home: LedSettingsScreen(repository: repository)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Enable LED'), findsOneWidget);
        expect(find.text('Status: ON (Active)'), findsOneWidget);

        // Confirm sensor event color pickers have been removed
        expect(find.text('Heart Rate'), findsNothing);
        expect(find.text('SpO₂'), findsNothing);
        expect(find.text('Good Posture'), findsNothing);
        expect(find.text('Bad Posture'), findsNothing);
        expect(find.text('Alarm'), findsNothing);
        expect(find.text('Reminder'), findsNothing);

        // Toggle LED Off
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(repository.ledSettings.value.isEnabled, isFalse);
        expect(find.text('Status: OFF (Disabled)'), findsOneWidget);

        // Toggle LED On
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
        expect(repository.ledSettings.value.isEnabled, isTrue);
        expect(find.text('Status: ON (Active)'), findsOneWidget);
      },
    );
  });

  group('3. Alarm System Tests', () {
    testWidgets('Create, toggle, and delete alarm with custom RGB color', (
      tester,
    ) async {
      final repository = MockHealthRepository();
      await tester.pumpWidget(
        MaterialApp(home: AlarmsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alarms'), findsOneWidget);
      expect(find.text('Wake Up'), findsOneWidget);
      expect(find.text('07:30 AM'), findsOneWidget);

      // Open Add Alarm Dialog
      await tester.tap(find.byTooltip('Add Alarm'));
      await tester.pumpAndSettle();

      expect(find.text('New Alarm'), findsOneWidget);
      expect(find.text('Alarm Name / Label'), findsOneWidget);
      expect(find.text('Sound / Beep'), findsOneWidget);
      expect(find.text('LED Diode Color'), findsOneWidget);

      // Save new alarm
      await tester.tap(find.text('Save Alarm'));
      await tester.pumpAndSettle();

      expect(repository.alarms.value.length, 3);

      // Toggle first alarm
      final initialEnabled = repository.alarms.value.first.enabled;
      await repository.toggleAlarm(
        repository.alarms.value.first.id,
        !initialEnabled,
      );
      expect(repository.alarms.value.first.enabled, !initialEnabled);

      // Delete an alarm
      final idToDelete = repository.alarms.value.first.id;
      await repository.deleteAlarm(idToDelete);
      expect(repository.alarms.value.any((a) => a.id == idToDelete), isFalse);
    });
  });

  group('4. Reminder System Tests', () {
    testWidgets(
      'Create, edit, toggle and delete reminder with custom RGB color',
      (tester) async {
        final repository = MockHealthRepository();
        await tester.pumpWidget(
          MaterialApp(home: RemindersScreen(repository: repository)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Reminders'), findsOneWidget);
        expect(find.text('Drink Water'), findsOneWidget);

        // Open Add Reminder
        await tester.tap(find.byTooltip('Add Reminder'));
        await tester.pumpAndSettle();

        expect(find.text('New Reminder'), findsOneWidget);
        expect(find.widgetWithText(ChoiceChip, 'Daily'), findsOneWidget);

        await tester.tap(find.text('Save Reminder'));
        await tester.pumpAndSettle();

        expect(repository.reminders.value.length, 3);

        // Delete a reminder
        final idToDelete = repository.reminders.value.first.id;
        await repository.deleteReminder(idToDelete);
        expect(
          repository.reminders.value.any((r) => r.id == idToDelete),
          isFalse,
        );
      },
    );
  });

  group('5. Device Name Tests', () {
    testWidgets(
      'Update device name reflects across repository and UI immediately',
      (tester) async {
        final repository = MockHealthRepository();
        expect(repository.deviceInfo.value.name, 'HealthDevice');
        expect(repository.connectionStatus.value.deviceName, 'HealthDevice');

        await repository.updateDeviceName('My Health Wristband');
        expect(repository.deviceInfo.value.name, 'My Health Wristband');
        expect(
          repository.connectionStatus.value.deviceName,
          'My Health Wristband',
        );
      },
    );
  });

  group('6. Notification Settings Tests', () {
    testWidgets('Individual toggles persist and change config correctly', (
      tester,
    ) async {
      final repository = MockHealthRepository();
      await tester.pumpWidget(
        MaterialApp(home: NotificationsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alarm'), findsOneWidget);
      expect(find.text('Reminder'), findsOneWidget);
      expect(find.text('Heart Rate Alert'), findsOneWidget);
      expect(find.text('SpO₂ Alert'), findsOneWidget);
      expect(find.text('Bad Posture'), findsOneWidget);
      expect(find.text('Fall Detection'), findsOneWidget);
      expect(find.text('Low Battery'), findsOneWidget);
      expect(find.text('Timer'), findsOneWidget);
      expect(find.text('Device / Connection'), findsOneWidget);

      // Toggle one setting
      final initialAlarm = repository.notificationConfig.value.alarm;
      await repository.updateNotificationConfig(
        repository.notificationConfig.value.copyWith(alarm: !initialAlarm),
      );
      expect(repository.notificationConfig.value.alarm, !initialAlarm);
    });
  });

  group('7. History Day / Week / Month Tests', () {
    test(
      'Verify History datasets genuinely change across Day, Week, and Month',
      () async {
        final repository = MockHealthRepository();

        final dayEntries = await repository.getHistoryEntries(
          timeframe: MetricTimeframe.day,
        );
        final weekEntries = await repository.getHistoryEntries(
          timeframe: MetricTimeframe.week,
        );
        final monthEntries = await repository.getHistoryEntries(
          timeframe: MetricTimeframe.month,
        );

        // Verify sizes and unique data points differ
        expect(dayEntries.isNotEmpty, isTrue);
        expect(weekEntries.isNotEmpty, isTrue);
        expect(monthEntries.isNotEmpty, isTrue);

        expect(dayEntries.first.section, 'Today');
        expect(weekEntries.first.section, 'This Week');
        expect(monthEntries.first.section, 'September 2026');

        expect(dayEntries.first.title, 'Heart Rate');
        expect(weekEntries.first.title, 'Heart Rate Daily Avg');
        expect(monthEntries.first.title, 'Week 4 Aggregate Activity');
      },
    );

    testWidgets(
      'HistoryScreen changes chart bars and feed when switching tabs',
      (tester) async {
        final repository = MockHealthRepository();
        await tester.pumpWidget(
          MaterialApp(home: HistoryScreen(repository: repository)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Today'), findsOneWidget);

        // Tap Week
        await tester.tap(find.text('Week'));
        await tester.pumpAndSettle();
        expect(find.text('This Week'), findsOneWidget);

        // Tap Month
        await tester.tap(find.text('Month'));
        await tester.pumpAndSettle();
        expect(find.text('September 2026'), findsOneWidget);

        // Switch to Chart View
        await tester.tap(find.byTooltip('Show Charts'));
        await tester.pumpAndSettle();
        expect(
          find.text('Monthly Aggregation by Week (W1 – W4)'),
          findsOneWidget,
        );

        // Switch back to Day on Charts
        await tester.tap(find.text('Day'));
        await tester.pumpAndSettle();
        expect(
          find.text("Today's Hourly Readings (8 AM – 8 PM)"),
          findsOneWidget,
        );
      },
    );
  });

  group('8. Wi-Fi Multi-Network & Priority Tests', () {
    testWidgets(
      'Saved Wi-Fi list, priorities, edit, move, scan, and add from scan',
      (tester) async {
        final repository = MockHealthRepository();
        await tester.pumpWidget(
          MaterialApp(home: WiFiSettingsScreen(repository: repository)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Wi-Fi'), findsOneWidget);
        expect(find.text('Connected'), findsWidgets);
        expect(find.text('Home_WiFi'), findsWidgets);
        expect(find.text('192.168.1.24'), findsOneWidget);

        // Check saved networks and priorities
        expect(find.text('Priority 1'), findsOneWidget);
        expect(find.text('College WiFi'), findsWidgets);
        expect(find.text('Priority 2'), findsOneWidget);
        expect(find.text('Phone Hotspot'), findsWidgets);
        expect(find.text('Priority 3'), findsOneWidget);

        // Verify Nearby Networks section and scan button
        expect(find.text('Nearby Networks'), findsOneWidget);
        expect(find.text('(2.4 GHz • WPA2 only)'), findsOneWidget);
        expect(find.text('Scan'), findsOneWidget);

        // Verify Scanned nearby networks render 2.4 GHz and WPA2-Personal
        expect(find.text('Airtel_2.4G'), findsOneWidget);
        expect(find.text('TP-Link_2.4G'), findsOneWidget);
        expect(find.text('JioFiber'), findsOneWidget);
        expect(find.text('Add'), findsWidgets);

        // Move priority down
        await repository.moveWiFiPriorityDown('wifi_1');
        expect(
          repository.wifiState.value.savedNetworks.first.ssid,
          'College WiFi',
        );

        // Move priority up
        await repository.moveWiFiPriorityUp('wifi_1');
        expect(
          repository.wifiState.value.savedNetworks.first.ssid,
          'Home_WiFi',
        );

        // Edit existing network: update password, verify same ID preserved
        final originalId = repository.wifiState.value.savedNetworks.first.id;
        await repository.updateWiFiNetwork(
          repository.wifiState.value.savedNetworks.first.copyWith(
            password: 'new_super_secure_pass',
          ),
        );
        expect(repository.wifiState.value.savedNetworks.first.id, originalId);
        expect(
          repository.wifiState.value.savedNetworks.first.password,
          'new_super_secure_pass',
        );

        // Add network with duplicate SSID: should update existing without duplicating
        final countBefore = repository.wifiState.value.savedNetworks.length;
        await repository.addWiFiNetwork(
          const WiFiNetworkItem(
            id: 'new_random_id',
            ssid: 'Home_WiFi',
            password: 'updated_password',
            priority: 1,
          ),
        );
        expect(repository.wifiState.value.savedNetworks.length, countBefore);
        expect(repository.wifiState.value.savedNetworks.first.id, originalId);
        expect(
          repository.wifiState.value.savedNetworks.first.password,
          'updated_password',
        );

        // Add a distinct network
        const newNet = WiFiNetworkItem(
          id: 'wifi_office',
          ssid: 'Office 2.4G',
          password: 'office_secret',
          priority: 4,
        );
        await repository.addWiFiNetwork(newNet);
        expect(
          repository.wifiState.value.savedNetworks.any(
            (n) => n.ssid == 'Office 2.4G',
          ),
          isTrue,
        );

        // Delete network
        await repository.deleteWiFiNetwork('wifi_office');
        expect(
          repository.wifiState.value.savedNetworks.any(
            (n) => n.ssid == 'Office 2.4G',
          ),
          isFalse,
        );
      },
    );
  });

  group('9. Device & Settings Navigation Integration Tests', () {
    testWidgets(
      'DeviceSettingsScreen contains Device, Sound, Display, LED, Notifications, Wi-Fi, Button Guide, About',
      (tester) async {
        final repository = MockHealthRepository();
        await tester.pumpWidget(
          MaterialApp(home: DeviceSettingsScreen(repository: repository)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Device'), findsOneWidget);
        expect(find.text('Sound'), findsOneWidget);
        expect(find.text('Display'), findsOneWidget);
        expect(find.text('LED'), findsOneWidget);
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Wi-Fi'), findsOneWidget);
        expect(find.text('Button Guide'), findsOneWidget);
        expect(find.text('About'), findsOneWidget);

        // Alarms and Reminders MUST NOT be directly under general Settings
        expect(find.text('Alarms'), findsNothing);
        expect(find.text('Reminders'), findsNothing);

        // Tap LED -> Opens LedSettingsScreen
        await tester.ensureVisible(find.text('LED'));
        await tester.tap(find.text('LED'));
        await tester.pumpAndSettle();
        expect(find.text('Enable LED'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
        await tester.pumpAndSettle();

        // Tap Notifications -> Opens NotificationsScreen
        await tester.ensureVisible(find.text('Notifications'));
        await tester.tap(find.text('Notifications'));
        await tester.pumpAndSettle();
        expect(find.text('Notification Settings'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
        await tester.pumpAndSettle();

        // Tap Wi-Fi -> Opens WiFiSettingsScreen
        await tester.ensureVisible(find.text('Wi-Fi'));
        await tester.tap(find.text('Wi-Fi'));
        await tester.pumpAndSettle();
        expect(find.text('Saved Networks'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
        await tester.pumpAndSettle();

        // Tap Sound -> Opens SoundSettingsScreen
        await tester.ensureVisible(find.text('Sound'));
        await tester.tap(find.text('Sound'));
        await tester.pumpAndSettle();
        expect(find.text('Sound & Haptics'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
        await tester.pumpAndSettle();

        // Tap Display -> Opens DisplaySettingsScreen
        await tester.ensureVisible(find.text('Display'));
        await tester.tap(find.text('Display'));
        await tester.pumpAndSettle();
        expect(find.text('Display Settings'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
        await tester.pumpAndSettle();

        // Tap Button Guide -> Opens ButtonGuideScreen
        await tester.ensureVisible(find.text('Button Guide'));
        await tester.tap(find.text('Button Guide'));
        await tester.pumpAndSettle();
        expect(find.text('Button Guide'), findsOneWidget);
        expect(find.text('Physical Button Controls'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
        await tester.pumpAndSettle();

        // Tap About -> Opens AboutScreen
        await tester.ensureVisible(find.text('About'));
        await tester.tap(find.text('About'));
        await tester.pumpAndSettle();
        expect(find.text('HealthDevice Companion'), findsOneWidget);
      },
    );

    testWidgets(
      'Device screen contains Device Name, Alarms, Reminders, and Device Settings',
      (tester) async {
        final repository = MockHealthRepository();
        await tester.pumpWidget(
          MaterialApp(home: DeviceScreen(repository: repository)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Device Name'), findsOneWidget);
        expect(find.text('Alarms'), findsOneWidget);
        expect(find.text('Reminders'), findsOneWidget);
        expect(find.text('Device Settings'), findsOneWidget);

        // Tap Alarms -> Opens AlarmsScreen
        await tester.tap(find.text('Alarms'));
        await tester.pumpAndSettle();
        expect(find.text('Configured Alarms'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
        await tester.pumpAndSettle();

        // Tap Reminders -> Opens RemindersScreen
        await tester.tap(find.text('Reminders'));
        await tester.pumpAndSettle();
        expect(find.text('Active Reminders'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
        await tester.pumpAndSettle();

        // Tap Device Settings -> Opens DeviceSettingsScreen
        await tester.ensureVisible(find.text('Device Settings'));
        await tester.tap(find.text('Device Settings'));
        await tester.pumpAndSettle();
        expect(find.text('Sound'), findsOneWidget);
      },
    );

    testWidgets(
      'Account SettingsScreen contains Account, Privacy, App Preferences, Delete Account',
      (tester) async {
        final repository = MockHealthRepository();
        final authRepository = LocalAuthRepository(autoSignInDefault: true);
        await tester.pumpWidget(
          MaterialApp(
            home: SettingsScreen(
              repository: repository,
              authRepository: authRepository,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('ACCOUNT & SESSION'), findsOneWidget);
        expect(find.text('PRIVACY & CLOUD DATA'), findsOneWidget);
        expect(find.text('APPLICATION PREFERENCES'), findsOneWidget);
        expect(find.text('Delete Account'), findsOneWidget);
        expect(find.text('Log Out'), findsOneWidget);
      },
    );
  });

  group('10. Authentication & Health Profile Unit Tests', () {
    test(
      'LocalAuthRepository sign up, login, session persistence, logout',
      () async {
        final authRepo = LocalAuthRepository(autoSignInDefault: false);
        expect(authRepo.currentUser.value, isNull);

        // Sign up
        final signUpResult = await authRepo.signUp(
          email: 'test@example.com',
          password: 'Password123',
          name: 'Test User',
        );
        expect(signUpResult.success, isTrue);
        expect(signUpResult.user?.email, 'test@example.com');
        expect(signUpResult.user?.name, 'Test User');

        // Save health profile
        final profile = UserHealthProfile(
          name: 'Test User',
          dateOfBirth: DateTime(1995, 5, 20),
          heightCm: 175,
          weightKg: 70,
          biologicalSex: 'Male',
          units: 'Metric (cm, kg)',
          primaryGoal: 'General wellness',
        );
        await authRepo.updateHealthProfile(profile);
        expect(authRepo.currentProfile.value?.heightCm, 175);
        expect(authRepo.currentProfile.value?.isCompleted, isTrue);

        // Logout
        await authRepo.logOut();
        expect(authRepo.currentUser.value, isNull);

        // Log in with wrong password fails
        final failedLogin = await authRepo.logIn(
          email: 'test@example.com',
          password: 'wrongpassword',
        );
        expect(failedLogin.success, isFalse);

        // Log in with correct password
        final successfulLogin = await authRepo.logIn(
          email: 'test@example.com',
          password: 'Password123',
        );
        expect(successfulLogin.success, isTrue);
        expect(successfulLogin.user?.email, 'test@example.com');
        expect(authRepo.currentProfile.value?.weightKg, 70);
      },
    );
  });

  group('11. AI Assistant Engine & Disclaimers Tests', () {
    test(
      'HealthDeviceAiService context building and rule-based queries',
      () async {
        final repository = MockHealthRepository();
        final aiService = HealthDeviceAiService();

        final profile = UserHealthProfile(
          name: 'Alex',
          dateOfBirth: DateTime(1996, 1, 1),
          heightCm: 178,
          weightKg: 72,
          biologicalSex: 'Male',
          units: 'Metric (cm, kg)',
          primaryGoal: 'Fitness',
        );

        final context = aiService.buildContext(
          repository: repository,
          profile: profile,
        );

        expect(context.userName, 'Alex');
        expect(context.userAge, isNotNull);
        expect(context.currentBpm, greaterThan(0));

        // Daily summary query
        final summary = await aiService.queryAssistant(
          userPrompt: 'Daily health summary',
          context: context,
        );

        expect(summary, contains('Daily Health Summary'));
        expect(summary, contains('Heart Rate'));
        expect(summary, contains('SpO₂'));
        // Must include medical disclaimer
        expect(summary, contains('informational'));
        expect(summary, contains('not intended as medical diagnosis'));

        // Device assistance query
        final buttonQuery = await aiService.queryAssistant(
          userPrompt: 'How does the button work?',
          context: context,
        );
        expect(buttonQuery, contains('Button Guide'));
      },
    );

    test(
      'AI Chat and question history persistence across app reloads',
      () async {
        final storage = SettingsStorageService();
        await storage.init();

        final now = DateTime.now();
        final testMessages = [
          AiChatMessage(
            id: 'usr_test_1',
            isUser: true,
            text: 'How is my posture today?',
            timestamp: now,
          ),
          AiChatMessage(
            id: 'ai_test_1',
            isUser: false,
            text: 'Your posture score is 85% today with good alignment.',
            timestamp: now.add(const Duration(seconds: 1)),
          ),
        ];

        final testHistory = [
          AiChatQuestionHistoryItem(
            questionId: 'usr_test_1',
            answerId: 'ai_test_1',
            question: 'How is my posture today?',
            answer: 'Your posture score is 85% today with good alignment.',
            timestamp: now,
          ),
        ];

        // Save
        await storage.saveAiChatHistory(
          testMessages.map((m) => m.toJson()).toList(),
        );
        await storage.saveAiQuestionHistory(
          testHistory.map((m) => m.toJson()).toList(),
        );

        // Retrieve and verify
        final retrievedMessages = storage.getAiChatHistory();
        expect(retrievedMessages.length, 2);
        final firstMsg = AiChatMessage.fromJson(retrievedMessages[0]);
        expect(firstMsg.id, 'usr_test_1');
        expect(firstMsg.isUser, isTrue);
        expect(firstMsg.text, 'How is my posture today?');

        final retrievedHistory = storage.getAiQuestionHistory();
        expect(retrievedHistory.length, 1);
        final firstHistory =
            AiChatQuestionHistoryItem.fromJson(retrievedHistory[0]);
        expect(firstHistory.questionId, 'usr_test_1');
        expect(firstHistory.question, 'How is my posture today?');
        expect(firstHistory.answer, contains('85%'));

        // Clear
        await storage.clearAiChatHistory();
        expect(storage.getAiChatHistory(), isEmpty);
        expect(storage.getAiQuestionHistory(), isEmpty);
      },
    );
  });

  group('12. Sound & Display Settings Repository Tests', () {
    test('Sound and Display settings persist and broadcast updates', () async {
      final repository = MockHealthRepository();

      expect(repository.soundSettings.value.soundEnabled, isTrue);
      expect(repository.soundSettings.value.volumePct, 80);

      await repository.updateSoundSettings(
        const SoundSettings(
          soundEnabled: false,
          volumePct: 50,
          dndEnabled: true,
          clickSoundEnabled: false,
          measurementSoundEnabled: true,
        ),
      );
      expect(repository.soundSettings.value.soundEnabled, isFalse);
      expect(repository.soundSettings.value.volumePct, 50);
      expect(repository.soundSettings.value.dndEnabled, isTrue);

      expect(repository.displaySettings.value.brightnessPct, 85);
      await repository.updateDisplaySettings(
        const DisplaySettings(
          brightnessPct: 60,
          screenTimeoutSec: 30,
          orientationFlipped: true,
          use24HourTime: false,
        ),
      );
      expect(repository.displaySettings.value.brightnessPct, 60);
      expect(repository.displaySettings.value.orientationFlipped, isTrue);
      expect(repository.displaySettings.value.use24HourTime, isFalse);
    });
  });
}
