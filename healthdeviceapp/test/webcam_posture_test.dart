import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthdeviceapp/models/health_metrics.dart';
import 'package:healthdeviceapp/repositories/mock_health_repository.dart';
import 'package:healthdeviceapp/screens/webcam_posture_screen.dart';
import 'package:healthdeviceapp/services/webcam_posture_service.dart';

void main() {
  group('Webcam Posture Tracker Architecture Tests', () {
    test('WebcamPostureData parses JSON and detects good vs slouching posture', () {
      final jsonGood = {
        'running': true,
        'personDetected': true,
        'postureScore': 94,
        'status': 'Good Posture',
        'shoulderTiltDeg': 1.4,
        'headForwardPct': 10.2,
        'slouchSeconds': 0.0,
        'goodPostureSeconds': 120,
        'beepEnabled': true,
        'calibrated': true,
      };

      final dataGood = WebcamPostureData.fromJson(jsonGood);
      expect(dataGood.isConnected, isTrue);
      expect(dataGood.personDetected, isTrue);
      expect(dataGood.postureScore, 94);
      expect(dataGood.isGoodPosture, isTrue);
      expect(dataGood.status, 'Good Posture');
      expect(dataGood.calibrated, isTrue);

      final jsonBad = {
        'running': true,
        'personDetected': true,
        'postureScore': 55,
        'status': 'Slouch Detected!',
        'shoulderTiltDeg': 14.2,
        'headForwardPct': 35.0,
        'slouchSeconds': 5.2,
        'goodPostureSeconds': 30,
        'beepEnabled': true,
        'calibrated': true,
      };

      final dataBad = WebcamPostureData.fromJson(jsonBad);
      expect(dataBad.isGoodPosture, isFalse);
      expect(dataBad.postureScore, 55);
      expect(dataBad.slouchSeconds, 5.2);
    });

    test('Disconnected state defaults cleanly', () {
      final disc = WebcamPostureData.disconnected();
      expect(disc.isConnected, isFalse);
      expect(disc.personDetected, isFalse);
      expect(disc.postureScore, 100);
      expect(disc.status, 'Tracker Offline');
    });

    test('HealthRepository updatePosture changes live repository state', () {
      final repo = MockHealthRepository();
      expect(repo.posture.value.postureScoreToday, 0);

      repo.updatePosture(
        repo.posture.value.copyWith(
          classification: PostureClassification.upright,
          postureScoreToday: 92,
          tiltDegrees: 2.1,
          goodPostureTime: const Duration(minutes: 15),
          timestamp: DateTime.now(),
        ),
      );

      expect(repo.posture.value.postureScoreToday, 92);
      expect(repo.posture.value.classification, PostureClassification.upright);
      expect(repo.posture.value.tiltDegrees, 2.1);
      expect(repo.posture.value.isGood, isTrue);
    });

    testWidgets('WebcamPostureScreen renders cleanly with controls', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() {
        WebcamPostureService.instance.telemetry.value = WebcamPostureData.disconnected();
      });

      final repo = MockHealthRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: WebcamPostureScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Posture Tracker'), findsOneWidget);
      expect(find.text('Live Posture Score'), findsOneWidget);
      expect(find.text('Turn ON'), findsOneWidget);

      // Now simulate active connected state to render advanced controls
      WebcamPostureService.instance.telemetry.value = const WebcamPostureData(
        isConnected: true,
        personDetected: true,
        postureScore: 92,
        status: 'Good Posture',
      );
      await tester.pumpAndSettle();

      expect(find.text('Turn OFF'), findsOneWidget);
      expect(find.text('Gender-Based Voice Alert'), findsOneWidget);
      expect(find.text('Calibrate Upright'), findsOneWidget);
    });
  });
}
