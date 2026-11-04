import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'models/health_metrics.dart';
import 'repositories/auth_repository.dart';
import 'repositories/health_repository.dart';
import 'repositories/mock_health_repository.dart';
import 'screens/health_profile_setup_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/ble_device_manager.dart';
import 'services/cloud_sync_service.dart';
import 'services/settings_storage_service.dart';
import 'services/supabase_service.dart';
import 'services/webcam_posture_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_scaffold.dart';

/// Kills the AI Posture Tracker process on app exit.
/// Uses synchronous taskkill so it completes before the process dies.
void _killPostureTrackerOnExit() {
  if (kIsWeb || !Platform.isWindows) return;
  if (Platform.environment.containsKey('FLUTTER_TEST')) return;
  try {
    WebcamPostureService.instance.stopTracker();
  } catch (_) {}
  try {
    Process.runSync('taskkill', ['/F', '/IM', 'pythonw.exe']);
    Process.runSync('taskkill', ['/F', '/IM', 'python.exe', '/FI', 'WINDOWTITLE eq HealthDevice*']);
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init();
  await SettingsStorageService().init();

  final repository = MockHealthRepository();
  final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
  final authRepository = LocalAuthRepository(autoSignInDefault: isTest);

  runApp(
    HealthDeviceApp(repository: repository, authRepository: authRepository),
  );

  // Initialize BLE Device Manager on app startup
  if (!isTest) {
    try {
      await BleDeviceManager().init();
    } catch (_) {}
  }

  // Sync cloud readings on startup and keep periodically synced every 15s in production
  if (!isTest) {
    Future.delayed(const Duration(seconds: 2), () {
      CloudSyncService.instance.startPeriodicSync(repository);
    });
  }
}

/// Root widget for the HealthDevice companion application.
class HealthDeviceApp extends StatefulWidget {
  final HealthRepository repository;
  final AuthRepository? authRepository;

  const HealthDeviceApp({
    super.key,
    required this.repository,
    this.authRepository,
  });

  @override
  State<HealthDeviceApp> createState() => _HealthDeviceAppState();
}

class _HealthDeviceAppState extends State<HealthDeviceApp> {
  late final AuthRepository _auth;
  AppLifecycleListener? _lifecycleListener;

  @override
  void initState() {
    super.initState();
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    _auth = widget.authRepository ??
        LocalAuthRepository(autoSignInDefault: isTest);

    // Initialize repository user data isolation from active authenticated user
    widget.repository.resetForUser(_auth.currentUser.value?.email);
    _auth.currentUser.addListener(() {
      widget.repository.resetForUser(_auth.currentUser.value?.email);
    });

    // Bind repository to webcam posture service so posture tracking updates the dashboard (Windows only)
    if (!kIsWeb && Platform.isWindows) {
      WebcamPostureService.instance.bindRepository(widget.repository);

      // Synchronize gender-based posture voice alerts from active user profile
      final initialSex = _auth.currentProfile.value?.biologicalSex;
      if (initialSex != null) {
        WebcamPostureService.instance.syncProfileGender(initialSex);
      } else {
        WebcamPostureService.instance.ensureGenderLoaded(_auth);
      }
      _auth.currentProfile.addListener(() {
        final updatedSex = _auth.currentProfile.value?.biologicalSex;
        if (updatedSex != null) {
          WebcamPostureService.instance.syncProfileGender(updatedSex);
        }
      });
    }

    // Kill posture tracker when the app window is closed (X button / End Task)
    if (!isTest) {
      _lifecycleListener = AppLifecycleListener(
        onExitRequested: () async {
          _killPostureTrackerOnExit();
          return AppExitResponse.exit;
        },
        onDetach: _killPostureTrackerOnExit,
      );
    }
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _killPostureTrackerOnExit();
    widget.repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Device',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: ValueListenableBuilder<bool>(
        valueListenable: _auth.isAuthenticated,
        builder: (context, isAuthenticated, _) {
          if (!isAuthenticated) {
            return WelcomeScreen(
              authRepository: _auth,
              healthRepository: widget.repository,
            );
          }

          return ValueListenableBuilder<UserHealthProfile?>(
            valueListenable: _auth.currentProfile,
            builder: (context, profile, _) {
              if (profile == null) {
                return HealthProfileSetupScreen(
                  authRepository: _auth,
                  healthRepository: widget.repository,
                  user:
                      _auth.currentUser.value ??
                      AuthUser(
                        id: 'usr_new',
                        email: 'user@healthdevice.com',
                        name: 'User',
                        createdAt: DateTime.now(),
                      ),
                );
              }

              return AppScaffold(
                repository: widget.repository,
                authRepository: _auth,
              );
            },
          );
        },
      ),
    );
  }
}
