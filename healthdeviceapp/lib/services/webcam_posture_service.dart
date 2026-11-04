import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/health_metrics.dart';
import '../repositories/auth_repository.dart';
import '../repositories/health_repository.dart';

/// Data class holding live telemetry from the AI Webcam Posture Tracker.
class WebcamPostureData {
  final bool isConnected;
  final bool windowVisible;
  final bool personDetected;
  final int postureScore;
  final String status;
  final double shoulderTiltDeg;
  final double headForwardPct;
  final double slouchSeconds;
  final int goodPostureSeconds;
  final bool beepEnabled;
  final String voiceMode;
  final bool showPopup;
  final bool calibrated;
  final String calibrationFeedback;

  const WebcamPostureData({
    this.isConnected = false,
    this.windowVisible = false,
    this.personDetected = false,
    this.postureScore = 100,
    this.status = 'Tracker Offline',
    this.shoulderTiltDeg = 0.0,
    this.headForwardPct = 0.0,
    this.slouchSeconds = 0.0,
    this.goodPostureSeconds = 0,
    this.beepEnabled = true,
    this.voiceMode = 'sir',
    this.showPopup = false,
    this.calibrated = false,
    this.calibrationFeedback = '',
  });

  factory WebcamPostureData.fromJson(Map<String, dynamic> json) {
    return WebcamPostureData(
      isConnected: json['running'] == true,
      windowVisible: json['windowVisible'] == true,
      personDetected: json['personDetected'] == true,
      postureScore: (json['postureScore'] as num?)?.toInt() ?? 100,
      status: json['status']?.toString() ?? 'Active',
      shoulderTiltDeg: (json['shoulderTiltDeg'] as num?)?.toDouble() ?? 0.0,
      headForwardPct: (json['headForwardPct'] as num?)?.toDouble() ?? 0.0,
      slouchSeconds: (json['slouchSeconds'] as num?)?.toDouble() ?? 0.0,
      goodPostureSeconds: (json['goodPostureSeconds'] as num?)?.toInt() ?? 0,
      beepEnabled: json['beepEnabled'] == true,
      voiceMode: json['voiceMode']?.toString() ?? 'sir',
      showPopup: json['showPopup'] == true,
      calibrated: json['calibrated'] == true,
      calibrationFeedback: json['calibrationFeedback']?.toString() ?? '',
    );
  }

  bool get isGoodPosture => status.toLowerCase().contains('good') || postureScore >= 80;

  factory WebcamPostureData.disconnected() => const WebcamPostureData();
}

/// Service that interfaces with the local AI Posture Tracker engine (Python + MediaPipe).
class WebcamPostureService {
  static final WebcamPostureService instance = WebcamPostureService._internal();

  WebcamPostureService._internal();

  static const String endpoint = 'http://127.0.0.1:8765';

  final ValueNotifier<WebcamPostureData> telemetry =
      ValueNotifier<WebcamPostureData>(WebcamPostureData.disconnected());

  final ValueNotifier<bool> isLaunching = ValueNotifier<bool>(false);
  final ValueNotifier<bool> startupEnabled = ValueNotifier<bool>(false);

  Timer? _pollTimer;
  HealthRepository? _boundRepository;
  String? _userBiologicalSex;

  String? get userBiologicalSex => _userBiologicalSex;

  /// Ensures user biological sex is loaded from memory, auth repository, or local storage.
  void ensureGenderLoaded([AuthRepository? auth]) {
    if (auth != null) {
      final sex = auth.currentProfile.value?.biologicalSex;
      if (sex != null && sex.isNotEmpty) {
        _userBiologicalSex = sex;
      }
    }
    if (!kIsWeb && Platform.isWindows) {
      try {
        final localAppData = Platform.environment['LOCALAPPDATA'] ?? Platform.environment['APPDATA'] ?? '.';
        final f = File('$localAppData/HealthDeviceApp/settings_store.json');
        if (f.existsSync()) {
          final content = f.readAsStringSync();
          final map = jsonDecode(content) as Map<String, dynamic>;
          final profile = map['hd_health_profile'] as Map<String, dynamic>?;
          final bioSex = profile?['biologicalSex'] as String?;
          if (bioSex != null && bioSex.isNotEmpty) {
            _userBiologicalSex = bioSex;
          }
        }
      } catch (_) {}
    }
  }

  void bindRepository(HealthRepository repo) {
    _boundRepository = repo;
  }

  bool get isRunning => telemetry.value.isConnected;

  /// Returns the target voice mode ('sir', 'maam', 'neutral') corresponding to a biological sex string.
  static String mapGenderToVoiceMode(String? biologicalSex) {
    if (biologicalSex == null || biologicalSex.isEmpty) return 'neutral';
    final sex = biologicalSex.toLowerCase();
    if (sex.contains('female') || sex.contains('woman') || sex.contains('girl')) {
      return 'maam';
    } else if (sex.contains('male') || sex.contains('man') || sex.contains('boy')) {
      return 'sir';
    } else {
      return 'neutral';
    }
  }

  /// Updates disk posture_baseline.json files directly so Python starts with the right gender mode
  void _updateBaselineJsonVoiceMode(String targetMode) {
    if (kIsWeb || !Platform.isWindows) return;
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final candidates = [
        '$exeDir\\ai_posture_tracker\\posture_baseline.json',
        '${Directory.current.path}\\ai_posture_tracker\\posture_baseline.json',
        'd:\\SG\\main files\\healthdeviceapp\\ai_posture_tracker\\posture_baseline.json',
        'd:\\SG\\main files\\healthdeviceapp\\build\\windows\\x64\\runner\\Release\\ai_posture_tracker\\posture_baseline.json',
      ];
      for (final p in candidates) {
        final f = File(p);
        if (f.existsSync()) {
          final content = f.readAsStringSync();
          final map = jsonDecode(content) as Map<String, dynamic>;
          map['voice_mode'] = targetMode;
          map['saved_at'] = DateTime.now().toIso8601String();
          f.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(map));
        }
      }
    } catch (_) {}
  }

  /// Updates user biological sex/gender and synchronizes the AI Posture Tracker voice alert.
  Future<bool> syncProfileGender(String? biologicalSex) async {
    if (biologicalSex == null || biologicalSex.isEmpty) return false;
    _userBiologicalSex = biologicalSex;
    final targetMode = mapGenderToVoiceMode(biologicalSex);
    _updateBaselineJsonVoiceMode(targetMode);
    return setVoiceMode(targetMode);
  }

  /// Starts polling the local telemetry server.
  void startListening({HealthRepository? syncWithRepository, String? biologicalSex}) {
    _boundRepository = syncWithRepository;
    if (biologicalSex != null && biologicalSex.isNotEmpty) {
      _userBiologicalSex = biologicalSex;
    } else {
      ensureGenderLoaded();
    }
    checkStartupStatus();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 700), (_) => _pollStatus());
    _pollStatus();
  }

  /// Stops polling.
  void stopListening() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollStatus() async {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) return;

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(milliseconds: 650);
      final request = await client.getUrl(Uri.parse('$endpoint/status'));
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final data = WebcamPostureData.fromJson(json);
        telemetry.value = data;

        // Auto-align voice mode to user's gender profile
        ensureGenderLoaded();
        if (_userBiologicalSex != null) {
          final targetMode = mapGenderToVoiceMode(_userBiologicalSex);
          if (data.voiceMode != targetMode) {
            setVoiceMode(targetMode);
          }
        }

        // Synchronize with main HealthRepository if bound
        _syncToHealthRepository(data);
      } else {
        telemetry.value = WebcamPostureData.disconnected();
      }
      client.close();
    } catch (_) {
      telemetry.value = WebcamPostureData.disconnected();
    }
  }

  void _syncToHealthRepository(WebcamPostureData data) {
    final repo = _boundRepository;
    if (repo == null) return;

    final current = repo.posture.value;
    final updated = current.copyWith(
      classification: data.isGoodPosture
          ? PostureClassification.upright
          : PostureClassification.slouching,
      postureScoreToday: data.postureScore,
      goodPostureTime: Duration(seconds: data.goodPostureSeconds),
      tiltDegrees: data.shoulderTiltDeg,
      timestamp: DateTime.now(),
    );
    repo.updatePosture(updated);
  }

  /// Public getters for Laptop AI Posture charts without clobbering wearable posture
  List<ChartDataPoint> getDayPoints() => [];
  List<ChartDataPoint> getWeekPoints() => [];
  List<ChartDataPoint> getSparklinePoints() => [];

  Future<bool> launchSilentTracker() => launchTrackerProcess(showCameraWindow: false);

  /// Sends a calibration signal to reset the neutral baseline with anti-cheat checks.
  Future<bool> calibrateNeutral() async {
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('$endpoint/calibrate'));
      final response = await request.close();
      client.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Dismisses or snoozes current alert (Ctrl+B equivalent).
  Future<bool> dismissAlert() async {
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('$endpoint/dismiss_alert'));
      final response = await request.close();
      client.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Shows or hides the camera preview window without killing the tracker.
  Future<bool> toggleCameraWindow() async {
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('$endpoint/toggle_window'));
      final response = await request.close();
      client.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Sets the voice mode ('sir', 'maam', 'neutral', 'beep').
  Future<bool> setVoiceMode(String mode) async {
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('$endpoint/set_voice_mode'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'mode': mode}));
      final response = await request.close();
      client.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Toggles audio alert in the tracker.
  Future<bool> toggleBeep() async {
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('$endpoint/toggle_beep'));
      final response = await request.close();
      client.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Stops the AI Posture Tracker and turns off webcam hardware completely.
  Future<bool> stopTracker() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(milliseconds: 1000);
      final request = await client.postUrl(Uri.parse('$endpoint/stop'));
      await request.close();
      client.close();
    } catch (_) {}

    // Fallback: Terminate any lingering pythonw processes
    if (!kIsWeb && Platform.isWindows) {
      try {
        await Process.run('taskkill', ['/F', '/IM', 'pythonw.exe']);
      } catch (_) {}
    }

    telemetry.value = WebcamPostureData.disconnected();
    return true;
  }

  /// Checks if Windows Startup shortcut exists.
  Future<bool> checkStartupStatus() async {
    if (kIsWeb || !Platform.isWindows) return false;
    try {
      final appData = Platform.environment['APPDATA'];
      if (appData == null) return false;
      final startupPath = '$appData\\Microsoft\\Windows\\Start Menu\\Programs\\Startup\\HealthDevice_PostureTracker.bat';
      final exists = File(startupPath).existsSync();
      startupEnabled.value = exists;
      return exists;
    } catch (_) {
      return false;
    }
  }

  /// Enables or disables launching the AI Posture Tracker with Windows startup.
  Future<bool> setStartupEnabled(bool enable) async {
    if (kIsWeb || !Platform.isWindows) return false;
    try {
      final appData = Platform.environment['APPDATA'];
      if (appData == null) return false;
      final startupDir = '$appData\\Microsoft\\Windows\\Start Menu\\Programs\\Startup';
      final startupFile = File('$startupDir\\HealthDevice_PostureTracker.bat');

      if (enable) {
        final batPath = _findBatPath();
        if (batPath == null) return false;
        final content = '@echo off\r\nstart "" "$batPath"\r\n';
        await startupFile.writeAsString(content);
        startupEnabled.value = true;
      } else {
        if (await startupFile.exists()) {
          await startupFile.delete();
        }
        startupEnabled.value = false;
      }
      return true;
    } catch (e) {
      debugPrint('[Startup] Error toggling startup: $e');
      return false;
    }
  }

  String? _findBatPath() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '$exeDir\\Start_AI_Posture_Tracker.bat',
      '${Directory.current.path}\\Start_AI_Posture_Tracker.bat',
      'd:\\SG\\main files\\healthdeviceapp\\Start_AI_Posture_Tracker.bat',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  final ValueNotifier<String?> launchError = ValueNotifier<String?>(null);

  Future<void> runPrerequisitesSetup() async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '$exeDir\\Setup_Prerequisites.bat',
      '${Directory.current.path}\\Setup_Prerequisites.bat',
      'd:\\SG\\main files\\healthdeviceapp\\Setup_Prerequisites.bat',
    ];
    for (final bat in candidates) {
      if (File(bat).existsSync()) {
        try {
          await Process.start('cmd.exe', ['/c', 'start', '""', bat], mode: ProcessStartMode.detached);
          return;
        } catch (_) {}
      }
    }
  }

  String? _findPythonw() {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    final userProfile = Platform.environment['USERPROFILE'];
    final programFiles = Platform.environment['ProgramFiles'];
    final programFilesX86 = Platform.environment['ProgramFiles(x86)'];

    final candidates = <String>[];
    final pyVersions = [
      'Python314',
      'Python313',
      'Python312',
      'Python311',
      'Python310',
      'Python39',
    ];

    for (final v in pyVersions) {
      if (localAppData != null && localAppData.isNotEmpty) {
        candidates.add('$localAppData\\Programs\\Python\\$v\\pythonw.exe');
        candidates.add('$localAppData\\Programs\\Python\\$v\\python.exe');
      }
      if (userProfile != null && userProfile.isNotEmpty) {
        candidates.add('$userProfile\\AppData\\Local\\Programs\\Python\\$v\\pythonw.exe');
        candidates.add('$userProfile\\AppData\\Local\\Programs\\Python\\$v\\python.exe');
      }
      if (programFiles != null && programFiles.isNotEmpty) {
        candidates.add('$programFiles\\Python\\$v\\pythonw.exe');
        candidates.add('$programFiles\\Python\\$v\\python.exe');
        candidates.add('$programFiles\\$v\\pythonw.exe');
        candidates.add('$programFiles\\$v\\python.exe');
      }
      if (programFilesX86 != null && programFilesX86.isNotEmpty) {
        candidates.add('$programFilesX86\\Python\\$v\\pythonw.exe');
        candidates.add('$programFilesX86\\Python\\$v\\python.exe');
      }
      candidates.add('C:\\$v\\pythonw.exe');
      candidates.add('C:\\$v\\python.exe');
      candidates.add('C:\\Python\\$v\\pythonw.exe');
      candidates.add('C:\\Python\\$v\\python.exe');
    }

    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }

    // Try finding via system PATH
    try {
      final resW = Process.runSync('where.exe', ['pythonw.exe']);
      if (resW.exitCode == 0 && resW.stdout.toString().trim().isNotEmpty) {
        return resW.stdout.toString().split(RegExp(r'[\r\n]+')).first.trim();
      }
    } catch (_) {}

    try {
      final resP = Process.runSync('where.exe', ['python.exe']);
      if (resP.exitCode == 0 && resP.stdout.toString().trim().isNotEmpty) {
        return resP.stdout.toString().split(RegExp(r'[\r\n]+')).first.trim();
      }
    } catch (_) {}

    return null;
  }

  /// Launches the AI Posture Tracker completely silently in the background (no console window).
  Future<bool> launchTrackerProcess({bool showCameraWindow = false}) async {
    if (kIsWeb || (!Platform.isWindows && !Platform.isMacOS && !Platform.isLinux)) {
      return false;
    }

    launchError.value = null;

    // Check if tracker is already running and reachable
    await _pollStatus();
    if (telemetry.value.isConnected) {
      if (showCameraWindow && !telemetry.value.windowVisible) {
        await toggleCameraWindow();
      }
      return true;
    }

    try {
      isLaunching.value = true;

      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final candidates = [
        Directory('$exeDir\\ai_posture_tracker'),
        Directory('${Directory.current.path}\\ai_posture_tracker'),
        Directory('d:\\SG\\main files\\healthdeviceapp\\ai_posture_tracker'),
      ];

      Directory? targetDir;
      for (final dir in candidates) {
        if (dir.existsSync() && File('${dir.path}\\posture_tracker.py').existsSync()) {
          targetDir = dir;
          break;
        }
      }

      if (targetDir != null && Platform.isWindows) {
        final scriptPath = '${targetDir.path}\\posture_tracker.py';
        final pythonwPath = _findPythonw();

        if (pythonwPath == null) {
          debugPrint('[WebcamPostureService] Python not found on system.');
          launchError.value = 'Python is not installed or not in PATH on this computer.\nPlease run Setup_Prerequisites.bat to install Python and dependencies.';
          isLaunching.value = false;
          return false;
        }

        debugPrint('[WebcamPostureService] Spawning background ($pythonwPath) at: $scriptPath');

        // Delete previous error log if any
        final errLog = File('${targetDir.path}\\tracker_error.log');
        if (errLog.existsSync()) {
          try { errLog.deleteSync(); } catch (_) {}
        }

        final args = <String>[scriptPath];
        if (showCameraWindow) {
          args.add('--window');
        }
        ensureGenderLoaded();
        if (_userBiologicalSex != null) {
          args.add('--voice-mode');
          args.add(mapGenderToVoiceMode(_userBiologicalSex));
        }

        // ProcessStartMode.detached ensures no terminal window is spawned
        await Process.start(
          pythonwPath,
          args,
          workingDirectory: targetDir.path,
          mode: ProcessStartMode.detached,
        );
      } else {
        // Fallback: Start batch file
        final bat = _findBatPath();
        if (bat != null) {
          await Process.start(bat, [], mode: ProcessStartMode.detached);
        }
      }

      // Proactively poll every 350ms for up to 10 seconds until the tracker responds
      for (int i = 0; i < 28; i++) {
        await Future.delayed(const Duration(milliseconds: 350));
        await _pollStatus();
        if (telemetry.value.isConnected) {
          break;
        }
      }

      if (!telemetry.value.isConnected && targetDir != null) {
        final errLog = File('${targetDir.path}\\tracker_error.log');
        if (errLog.existsSync()) {
          try {
            final content = errLog.readAsStringSync().trim();
            if (content.isNotEmpty) {
              launchError.value = content;
            }
          } catch (_) {}
        } else {
          launchError.value = 'Tracker did not start. MediaPipe or OpenCV libraries might be missing.\nPlease run Setup_Prerequisites.bat to configure the tracker.';
        }
      }

      if (_userBiologicalSex != null && telemetry.value.isConnected) {
        syncProfileGender(_userBiologicalSex);
      }
      isLaunching.value = false;
      return telemetry.value.isConnected;
    } catch (e) {
      debugPrint('[WebcamPostureService] Launch error: $e');
      launchError.value = 'Launch failed: $e';
      isLaunching.value = false;
      return false;
    }
  }
}
