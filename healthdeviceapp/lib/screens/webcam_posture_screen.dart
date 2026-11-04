import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../repositories/auth_repository.dart';
import '../repositories/health_repository.dart';
import '../services/webcam_posture_service.dart';
import '../theme/app_theme.dart';

/// Screen: Dedicated AI Webcam Posture Tracker.
/// Displays live real-time posture tracking telemetry from the laptop webcam,
/// master ON/OFF controls, closeable background camera preview toggle,
/// absence/away notifications, anti-cheat validation, and ergonomic guidance.
class WebcamPostureScreen extends StatefulWidget {
  final HealthRepository repository;
  final AuthRepository? authRepository;
  final bool autoStart;

  const WebcamPostureScreen({
    super.key,
    required this.repository,
    this.authRepository,
    this.autoStart = false,
  });

  @override
  State<WebcamPostureScreen> createState() => _WebcamPostureScreenState();
}

class _WebcamPostureScreenState extends State<WebcamPostureScreen> {
  final _service = WebcamPostureService.instance;

  @override
  void initState() {
    super.initState();
    final auth = widget.authRepository ?? LocalAuthRepository();
    final profileSex = auth.currentProfile.value?.biologicalSex;
    if (profileSex != null) {
      _service.syncProfileGender(profileSex);
    } else {
      _service.ensureGenderLoaded(auth);
    }
    _service.startListening(
      syncWithRepository: widget.repository,
      biologicalSex: _service.userBiologicalSex ?? profileSex,
    );
    if (widget.autoStart && !_service.telemetry.value.isConnected && !_service.isLaunching.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _service.launchTrackerProcess(showCameraWindow: false);
      });
    }
  }

  @override
  void dispose() {
    _service.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
          _service.dismissAlert();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Posture alert snoozed (Ctrl+B). Please sit upright!'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_rounded, size: 20, color: AppTheme.cyan),
                SizedBox(width: 8),
                Text(
                  'AI Posture Tracker',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'Snooze Alert (Ctrl+B)',
                icon: const Icon(Icons.notifications_paused_outlined, size: 20),
                onPressed: () async {
                  await _service.dismissAlert();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Posture alert snoozed.'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 20,
                vertical: 16,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ValueListenableBuilder<WebcamPostureData>(
                    valueListenable: _service.telemetry,
                    builder: (context, data, _) {
                      final isConnected = data.isConnected;
                      final isPerson = data.personDetected;
                      final score = data.postureScore;

                      Color statusColor;
                      if (!isConnected) {
                        statusColor = AppTheme.textMuted;
                      } else if (!isPerson) {
                        statusColor = AppTheme.statusOrange;
                      } else if (score >= 82) {
                        statusColor = AppTheme.neonGreen;
                      } else if (score >= 68) {
                        statusColor = AppTheme.statusOrange;
                      } else {
                        statusColor = AppTheme.heartRateRed;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 0. MASTER ON / OFF BAR
                          _buildMasterControlBar(context, data),
                          const SizedBox(height: 16),

                          ValueListenableBuilder<String?>(
                            valueListenable: _service.launchError,
                            builder: (context, error, _) {
                              if (error == null || isConnected) return const SizedBox.shrink();
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.badPostureOrange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.badPostureOrange.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, color: AppTheme.badPostureOrange, size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        error,
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.tonal(
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      onPressed: () => _service.runPrerequisitesSetup(),
                                      child: const Text('Run Setup', style: TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          // 1. PERSON NOT VISIBLE / AWAY BANNER (If tracker is on but user stepped away)
                          if (isConnected && !isPerson) ...[
                            _buildPersonNotVisibleBanner(),
                            const SizedBox(height: 16),
                          ],

                          // 2. ESCALATED POSTURE WARNING POPUP MODAL (If slouching > 10s post-mute)
                          if (data.showPopup && isPerson) ...[
                            _buildVisualEscalationModal(context),
                            const SizedBox(height: 18),
                          ],

                          // 3. Calibration Anti-Cheat Toast / Feedback
                          if (data.calibrationFeedback.isNotEmpty) ...[
                            _buildCalibrationFeedbackBanner(data.calibrationFeedback),
                            const SizedBox(height: 16),
                          ],

                          // 4. Score & Status Hero Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.card,
                                  statusColor.withValues(alpha: 0.08),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: isConnected ? statusColor : AppTheme.textMuted,
                                            boxShadow: isConnected
                                                ? [
                                                    BoxShadow(
                                                      color: statusColor.withValues(alpha: 0.6),
                                                      blurRadius: 8,
                                                      spreadRadius: 2,
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          data.status,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: statusColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                      ),
                                      child: Text(
                                        !isConnected
                                            ? 'Offline'
                                            : (!isPerson ? 'Away' : (data.windowVisible ? 'Preview Open' : 'Running in BG')),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Posture Score Large Display
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isConnected && isPerson ? '$score' : '--',
                                      style: TextStyle(
                                        fontSize: 64,
                                        fontWeight: FontWeight.w900,
                                        color: isConnected && isPerson ? AppTheme.textPrimary : AppTheme.textMuted,
                                        letterSpacing: -2,
                                        height: 1,
                                      ),
                                    ),
                                    if (isConnected && isPerson) ...[
                                      const SizedBox(width: 4),
                                      const Text(
                                        '%',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textSecondary,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Live Posture Score',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Progress Bar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: isConnected && isPerson ? (score / 100.0) : 0.0,
                                    minHeight: 12,
                                    backgroundColor: AppTheme.cardLight,
                                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Metrics Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildMetricPill(
                                      icon: Icons.timer_outlined,
                                      label: 'Upright Time',
                                      value: isConnected && isPerson
                                          ? '${data.goodPostureSeconds ~/ 60}m ${data.goodPostureSeconds % 60}s'
                                          : '0m 0s',
                                    ),
                                    Container(width: 1, height: 28, color: AppTheme.borderSubtle),
                                    _buildMetricPill(
                                      icon: Icons.trending_down_rounded,
                                      label: 'Slouch Timer',
                                      value: isConnected && isPerson ? '${data.slouchSeconds.toStringAsFixed(1)}s' : '0.0s',
                                      highlightColor: data.slouchSeconds > 2 ? AppTheme.heartRateRed : null,
                                    ),
                                    Container(width: 1, height: 28, color: AppTheme.borderSubtle),
                                    _buildMetricPill(
                                      icon: Icons.balance_rounded,
                                      label: 'Shoulder Tilt',
                                      value: isConnected && isPerson ? '${data.shoulderTiltDeg}°' : '0.0°',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 5. Actions Card (Calibrate & Camera Preview Window Toggle)
                          if (isConnected) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.card,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.accessibility_new_rounded, size: 18),
                                          label: const Text('Calibrate Upright'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.cyan,
                                            side: const BorderSide(color: AppTheme.cyan),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                          onPressed: isPerson
                                              ? () async => await _service.calibrateNeutral()
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: Icon(
                                            data.windowVisible ? Icons.visibility_off_rounded : Icons.videocam_rounded,
                                            size: 18,
                                          ),
                                          label: Text(data.windowVisible ? 'Hide Preview' : 'Show Preview'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppTheme.textPrimary,
                                            side: const BorderSide(color: AppTheme.border),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                          onPressed: () async {
                                            await _service.toggleCameraWindow();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.textMuted),
                                      SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          'Tip: You can close the camera preview anytime. The AI keeps tracking in background!',
                                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 6. Voice & Alert Customization Card
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppTheme.card,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.record_voice_over_rounded, color: AppTheme.cyan, size: 20),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Gender-Based Voice Alert',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                      ),
                                      const Spacer(),
                                      Switch(
                                        value: data.beepEnabled,
                                        activeTrackColor: AppTheme.cyan.withValues(alpha: 0.5),
                                        activeThumbColor: AppTheme.cyan,
                                        onChanged: (val) => _service.toggleBeep(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Personalized natural studio voice alerts tailored to your gender ("Sir" for Male, "Ma\'am" for Female).',
                                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.cyan.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.35)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.person_outline_rounded, size: 14, color: AppTheme.cyan),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Profile Gender: ${_service.userBiologicalSex ?? (widget.authRepository ?? LocalAuthRepository()).currentProfile.value?.biologicalSex ?? "Female"}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.cyan,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Voice Mode Selector Chips
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildVoiceChip('sir', 'Male ("Sir")', 'Sir, please sit straight and fix your posture', data.voiceMode),
                                      _buildVoiceChip('maam', 'Female ("Ma\'am")', 'Ma\'am, please sit straight and fix your posture', data.voiceMode),
                                      _buildVoiceChip('neutral', 'Neutral Voice', 'Please sit straight and fix your posture', data.voiceMode),
                                      _buildVoiceChip('beep', 'Classic Beep', 'Subtle audio tone', data.voiceMode),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surface,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppTheme.borderSubtle),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.volume_up_rounded, size: 16, color: AppTheme.cyan),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            data.voiceMode == 'sir'
                                                ? 'Voice phrase: "Sir, please sit straight and fix your posture."'
                                                : (data.voiceMode == 'maam'
                                                    ? 'Voice phrase: "Ma\'am, please sit straight and fix your posture."'
                                                    : (data.voiceMode == 'neutral'
                                                        ? 'Voice phrase: "Please sit straight and fix your posture."'
                                                        : 'Audio alert: Classic subtle beep')),
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const Divider(height: 28, color: AppTheme.borderSubtle),

                                  // Escalation Lifecycle Notice
                                  const Text(
                                    'Multi-Stage Posture Protection:',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                  ),
                                  const SizedBox(height: 6),
                                  _buildCycleStep('1', 'Detects back bending, torso drop, and forward head slouch.'),
                                  _buildCycleStep('2', '4s continuous slouch -> Soft natural female voice reminder.'),
                                  _buildCycleStep('3', 'Press Ctrl+B or sit straight to snooze.'),
                                  _buildCycleStep('4', 'If slouching continues for >10s post-snooze -> Visual modal popup.'),
                                  _buildCycleStep('5', 'Pauses alerts automatically whenever you step away from camera.'),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),

                          // 7. Windows Startup Toggle
                          if (!kIsWeb && Platform.isWindows)
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: ValueListenableBuilder<bool>(
                                  valueListenable: _service.startupEnabled,
                                  builder: (context, enabled, _) {
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () async => await _service.setStartupEnabled(!enabled),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: AppTheme.surface,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(Icons.power_settings_new_rounded, color: AppTheme.cyan, size: 20),
                                            ),
                                            const SizedBox(width: 14),
                                            const Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Start with Windows',
                                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                                  ),
                                                  SizedBox(height: 2),
                                                  Text(
                                                    'Automatically launch posture tracker when your computer boots up',
                                                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Switch(
                                              value: enabled,
                                              activeThumbColor: AppTheme.cyan,
                                              onChanged: (val) async {
                                                await _service.setStartupEnabled(val);
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),

                          // 8. Ergonomic Setup Tips
                          const Text(
                            'Ergonomic Multi-Factor Detection',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.card,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppTheme.border),
                            ),
                            child: Column(
                              children: [
                                _buildTip(
                                  icon: Icons.compress_rounded,
                                  title: 'Torso & Back Bending Detection',
                                  desc: 'Bending your lumbar spine causes your shoulders and head to sink down. The AI detects this vertical torso drop immediately.',
                                ),
                                const Divider(height: 20, color: AppTheme.borderSubtle),
                                _buildTip(
                                  icon: Icons.visibility_off_rounded,
                                  title: 'Smart Absence Pause',
                                  desc: 'When you leave your desk, tracking pauses automatically without generating false slouch alerts.',
                                ),
                                const Divider(height: 20, color: AppTheme.borderSubtle),
                                _buildTip(
                                  icon: Icons.verified_user_rounded,
                                  title: 'Anti-Cheat Protection',
                                  desc: 'Requires horizontal shoulders and extended neck for calibration. Calibration while slouched is rejected.',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMasterControlBar(BuildContext context, WebcamPostureData data) {
    final isConnected = data.isConnected;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isConnected ? AppTheme.neonGreen.withValues(alpha: 0.4) : AppTheme.border,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isConnected ? AppTheme.neonGreen : AppTheme.surface).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.power_settings_new_rounded,
              color: isConnected ? AppTheme.neonGreen : AppTheme.textMuted,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isConnected ? 'AI Posture Tracker: ON' : 'AI Posture Tracker: OFF',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isConnected ? AppTheme.neonGreen : AppTheme.surface)
                            .withValues(alpha: isConnected ? 0.2 : 0.8),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isConnected ? 'ACTIVE' : 'STOPPED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isConnected ? AppTheme.neonGreen : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isConnected
                      ? 'Running silently in background • Camera active'
                      : 'Camera hardware is released. Tap to start.',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ValueListenableBuilder<bool>(
            valueListenable: _service.isLaunching,
            builder: (context, launching, _) {
              if (launching) {
                return const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cyan),
                );
              }
              return FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: isConnected ? AppTheme.heartRateRed : AppTheme.cyan,
                  foregroundColor: isConnected ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (isConnected) {
                    await _service.stopTracker();
                  } else {
                    final ok = await _service.launchTrackerProcess(showCameraWindow: false);
                    if (!ok && context.mounted) {
                      _showPrerequisitesDialog(context, _service.launchError.value);
                    }
                  }
                },
                child: Text(
                  isConnected ? 'Turn OFF' : 'Turn ON',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showPrerequisitesDialog(BuildContext context, String? error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.statusOrange, size: 24),
            SizedBox(width: 10),
            Text(
              'Prerequisites Required',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error ??
                  'Python 3.10+ or required AI libraries (MediaPipe, OpenCV) were not detected on this computer.',
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: const Text(
                'Click "Run Setup" to automatically launch Setup_Prerequisites.bat and install required AI libraries.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.build_rounded, size: 16),
            label: const Text('Run Setup'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.cyan,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _service.runPrerequisitesSetup();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPersonNotVisibleBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.statusOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.statusOrange.withValues(alpha: 0.4), width: 1.5),
      ),
      child: const Row(
        children: [
          Icon(Icons.person_off_rounded, color: AppTheme.statusOrange, size: 24),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Person Not Visible in Camera',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.statusOrange,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Please sit in front of the webcam to track your posture. Alerts and slouch timer are paused.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceChip(String mode, String label, String preview, String currentMode) {
    final isSelected = currentMode == mode;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      selectedColor: AppTheme.cyan,
      backgroundColor: AppTheme.surface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : AppTheme.textPrimary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      onSelected: (_) async {
        await _service.setVoiceMode(mode);
      },
    );
  }

  Widget _buildCycleStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.cyan.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.cyan),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildCalibrationFeedbackBanner(String feedback) {
    final isError = feedback.toLowerCase().contains('cheat') || feedback.toLowerCase().contains('invalid');
    final color = isError ? AppTheme.heartRateRed : AppTheme.neonGreen;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              feedback,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualEscalationModal(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1418),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.heartRateRed, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.heartRateRed.withValues(alpha: 0.25),
            blurRadius: 16,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppTheme.heartRateRed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'POSTURE WARNING: PLEASE SIT STRAIGHT!',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Back bending or slouching detected for over 10 seconds.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.heartRateRed.withValues(alpha: 0.5)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.person_outline_rounded, color: AppTheme.heartRateRed, size: 36),
                      SizedBox(height: 4),
                      Text('SLOUCHED', style: TextStyle(color: AppTheme.heartRateRed, fontWeight: FontWeight.w700, fontSize: 11)),
                      Text('Curved spine & low chin', style: TextStyle(color: AppTheme.textMuted, fontSize: 10), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.neonGreen.withValues(alpha: 0.5)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.accessibility_new_rounded, color: AppTheme.neonGreen, size: 36),
                      SizedBox(height: 4),
                      Text('UPRIGHT', style: TextStyle(color: AppTheme.neonGreen, fontWeight: FontWeight.w700, fontSize: 11)),
                      Text('Spine straight & shoulders back', style: TextStyle(color: AppTheme.textMuted, fontSize: 10), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sitting straight automatically clears this alert.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.snooze_rounded, size: 16),
                label: const Text('Snooze (Ctrl+B)'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.heartRateRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                onPressed: () => _service.dismissAlert(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required String value,
    Color? highlightColor,
  }) {
    return Column(
      children: [
        Icon(icon, size: 18, color: highlightColor ?? AppTheme.cyan),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: highlightColor ?? AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _buildTip({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppTheme.cyan),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
