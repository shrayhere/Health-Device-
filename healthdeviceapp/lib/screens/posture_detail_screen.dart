import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../repositories/health_repository.dart';
import '../services/webcam_posture_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_charts.dart';
import 'webcam_posture_screen.dart';

/// Posture History Detail Screen — Divided into TWO distinct systems:
/// 1. Wearable Device Posture (ESP32 hardware IMU accelerometer & tilt sensor)
/// 2. Laptop Webcam AI Posture (Computer Vision MediaPipe tracker - Desktop only)
class PostureDetailScreen extends StatefulWidget {
  final HealthRepository repository;
  final VoidCallback? onNavigateToPostureTracker;

  const PostureDetailScreen({
    super.key,
    required this.repository,
    this.onNavigateToPostureTracker,
  });

  @override
  State<PostureDetailScreen> createState() => _PostureDetailScreenState();
}

class _PostureDetailScreenState extends State<PostureDetailScreen> {
  MetricTimeframe _timeframe = MetricTimeframe.live;
  int _selectedSource = 0; // 0 = Wearable Device, 1 = Laptop Webcam AI
  bool _isCalibrating = false;

  bool get _isDesktopPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;
    final isDesktopPlatform = _isDesktopPlatform;

    return ValueListenableBuilder<PostureData>(
      valueListenable: widget.repository.posture,
      builder: (context, devicePosture, _) {
        return ValueListenableBuilder<WebcamPostureData>(
          valueListenable: WebcamPostureService.instance.telemetry,
          builder: (context, webcamPosture, _) {
            return Scaffold(
              backgroundColor: AppTheme.background,
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: const Text(
                  'Posture Analysis',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                centerTitle: true,
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 32 : 20,
                    vertical: 16,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Two-Part Source Switcher (Only on Desktop / Windows)
                          if (isDesktopPlatform) ...[
                            _buildSourceSwitcher(),
                            const SizedBox(height: 20),
                          ],

                          if (!isDesktopPlatform || _selectedSource == 0) ...[
                            // PART 1: Wearable Device Posture (ESP32 IMU)
                            _buildDevicePostureSection(context, devicePosture),
                          ] else ...[
                            // PART 2: Laptop Webcam AI Posture (Desktop only)
                            _buildLaptopPostureSection(context, webcamPosture),
                          ],
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Two-Segment Source Switcher (Wearable Device vs Laptop Webcam AI)
  Widget _buildSourceSwitcher() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildSourceTab(
              index: 0,
              icon: Icons.watch_rounded,
              title: 'Wearable Device',
              subtitle: 'ESP32 Hardware IMU',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildSourceTab(
              index: 1,
              icon: Icons.videocam_rounded,
              title: 'Laptop Webcam',
              subtitle: 'MediaPipe AI Vision',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceTab({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedSource == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedSource = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.card : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: AppTheme.border) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppTheme.cyan : AppTheme.textMuted,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? AppTheme.cyan : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // PART 1: WEARABLE DEVICE POSTURE (ESP32 MPU6050 Accelerometer / Tilt)
  // =========================================================================
  Widget _buildDevicePostureSection(
      BuildContext context, PostureData posture) {
    final isGood = posture.isGood;
    final isInactive = posture.classification == PostureClassification.inactive;
    final tilt = posture.tiltDegrees;

    final Color statusColor = isInactive
        ? AppTheme.textMuted
        : (isGood ? AppTheme.goodPostureGreen : AppTheme.badPostureOrange);

    final String statusLabel = isInactive
        ? 'Not Calibrated'
        : (isGood ? 'Good Posture (Upright)' : 'Slouching / Tilted');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isInactive
                      ? Icons.tune_rounded
                      : (isGood
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded),
                  size: 32,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Live Tilt Deviation: ${tilt.toStringAsFixed(1)}° from baseline',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3 Key Stats
        Row(
          children: [
            Expanded(
              child: _buildStatBox(
                value: '${tilt.toStringAsFixed(1)}°',
                label: 'Live Tilt',
                color: statusColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatBox(
                value: isInactive ? 'Setup' : (isGood ? 'Upright' : 'Slouch'),
                label: 'Posture State',
                color: statusColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatBox(
                value: '15.0°',
                label: 'Tolerance',
                color: AppTheme.cyan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Calibration Control Card
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
                children: const [
                  Icon(Icons.straighten_rounded,
                      size: 20, color: AppTheme.cyan),
                  SizedBox(width: 8),
                  Text(
                    'Device Posture Calibration',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Sit straight with good posture and press Calibrate. The device will zero its pitch and roll angles as your upright reference baseline.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isCalibrating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(_isCalibrating
                      ? 'Calibrating Baseline...'
                      : 'Calibrate Device Baseline Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isCalibrating
                      ? null
                      : () async {
                          setState(() => _isCalibrating = true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Hold still! Calibrating posture on HealthDevice...'),
                              duration: Duration(seconds: 3),
                            ),
                          );
                          await widget.repository.calibratePosture();
                          await Future.delayed(const Duration(seconds: 3));
                          if (mounted) {
                            setState(() => _isCalibrating = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Device baseline calibrated successfully!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Timeframe selector
        _buildTimeframeSelector(),
        const SizedBox(height: 16),

        // Device Chart
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Device Posture Score Trend',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    isGood ? 'Optimal (Upright)' : 'Slouching',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _getPointsForTimeframe(posture).isEmpty
                  ? _buildEmptyChart('Awaiting hardware posture logs from ESP32')
                  : HealthLineChart(
                      points: _getPointsForTimeframe(posture),
                      minY: 0,
                      maxY: 100,
                      yLabels: const [0, 25, 50, 75, 100],
                      lineColor: statusColor,
                      gradientColor: statusColor,
                      height: 180,
                    ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // PART 2: LAPTOP WEBCAM AI POSTURE (MediaPipe Tracker)
  // =========================================================================
  Widget _buildLaptopPostureSection(
      BuildContext context, WebcamPostureData webcam) {
    final isConnected = webcam.isConnected;
    final isGood = webcam.isGoodPosture;
    final score = webcam.postureScore;

    Color scoreColor;
    String scoreLabel;
    if (!isConnected) {
      scoreColor = AppTheme.textMuted;
      scoreLabel = 'Tracker Inactive';
    } else if (score >= 80) {
      scoreColor = AppTheme.goodPostureGreen;
      scoreLabel = 'Good Alignment';
    } else if (score >= 60) {
      scoreColor = AppTheme.statusOrange;
      scoreLabel = 'Mild Slouch';
    } else {
      scoreColor = AppTheme.heartRateRed;
      scoreLabel = 'Poor Posture';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Score Hero
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.videocam_rounded,
                  size: 32,
                  color: scoreColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          isConnected && score > 0 ? '$score%' : '--',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          scoreLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: scoreColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isConnected
                          ? (webcam.personDetected
                              ? 'Person detected • Shoulder tilt: ${webcam.shoulderTiltDeg.toStringAsFixed(1)}°'
                              : 'No person in camera frame')
                          : 'Laptop webcam posture tracker is offline',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3 Key Stats
        Row(
          children: [
            Expanded(
              child: _buildStatBox(
                value: isConnected
                    ? '${webcam.shoulderTiltDeg.toStringAsFixed(1)}°'
                    : '--',
                label: 'Shoulder Tilt',
                color: scoreColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatBox(
                value: isConnected
                    ? (webcam.personDetected ? 'Yes' : 'No')
                    : 'Offline',
                label: 'Person Seen',
                color: AppTheme.cyan,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatBox(
                value: isConnected ? '${webcam.goodPostureSeconds ~/ 60}m' : '--',
                label: 'Good Time',
                color: AppTheme.goodPostureGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: Icon(
                  isConnected
                      ? Icons.stop_circle_rounded
                      : Icons.play_arrow_rounded,
                  size: 18,
                ),
                label: Text(isConnected ? 'Stop Tracker' : 'Start Camera AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isConnected
                      ? AppTheme.statusOrange
                      : AppTheme.goodPostureGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (isConnected) {
                    await WebcamPostureService.instance.stopTracker();
                  } else {
                    await WebcamPostureService.instance.launchSilentTracker();
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.fullscreen_rounded, size: 18),
                label: const Text('Live Visualizer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.cyan,
                  side: const BorderSide(color: AppTheme.cyan),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => WebcamPostureScreen(
                        repository: widget.repository,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Webcam Chart
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Laptop AI Posture Score History',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              WebcamPostureService.instance.getDayPoints().isEmpty
                  ? _buildEmptyChart('Start the Camera AI to record posture trends')
                  : HealthLineChart(
                      points: WebcamPostureService.instance.getDayPoints(),
                      minY: 0,
                      maxY: 100,
                      yLabels: const [0, 25, 50, 75, 100],
                      lineColor: scoreColor,
                      gradientColor: scoreColor,
                      height: 180,
                    ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // SHARED UTILITIES
  // =========================================================================
  Widget _buildTimeframeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildPill(MetricTimeframe.live, 'Live'),
          _buildPill(MetricTimeframe.day, 'Day'),
          _buildPill(MetricTimeframe.week, 'Week'),
          _buildPill(MetricTimeframe.month, 'Month'),
        ],
      ),
    );
  }

  Widget _buildPill(MetricTimeframe tf, String label) {
    final isSelected = _timeframe == tf;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _timeframe = tf),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppTheme.textPrimary
                    : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<ChartDataPoint> _getPointsForTimeframe(PostureData posture) {
    switch (_timeframe) {
      case MetricTimeframe.live:
        return posture.sparkline;
      case MetricTimeframe.day:
        return posture.dayData;
      case MetricTimeframe.week:
        return posture.weekData;
      case MetricTimeframe.month:
        return posture.monthData;
    }
  }

  Widget _buildStatBox({
    required String value,
    required String label,
    Color color = AppTheme.textPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChart(String message) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 36,
              color: AppTheme.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
