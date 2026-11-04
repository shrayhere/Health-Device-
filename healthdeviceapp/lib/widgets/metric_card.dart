import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../theme/app_theme.dart';
import 'app_avatar_widget.dart';
import 'custom_charts.dart';

/// Top header banner with HealthDevice title, connection dot, battery, and action icon
/// matching reference Screen B / A / C.
class DeviceTopHeader extends StatelessWidget {
  final ConnectionStatus connection;
  final BatteryData battery;
  final VoidCallback? onSettingsPressed;
  final VoidCallback? onNotificationPressed;
  final VoidCallback? onViewModeToggle;
  final VoidCallback? onAvatarPressed;
  final String? avatarId;
  final bool isModularDashboard;

  const DeviceTopHeader({
    super.key,
    required this.connection,
    required this.battery,
    this.onSettingsPressed,
    this.onNotificationPressed,
    this.onViewModeToggle,
    this.onAvatarPressed,
    this.avatarId,
    this.isModularDashboard = true,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = connection.isConnected;
    final dotColor = isConnected ? AppTheme.cyan : AppTheme.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Text(
                'HealthDevice',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              children: [
                if (onViewModeToggle != null)
                  IconButton(
                    onPressed: onViewModeToggle,
                    icon: Icon(
                      isModularDashboard
                          ? Icons.view_agenda_outlined
                          : Icons.grid_view_rounded,
                      size: 19,
                      color: AppTheme.cyan,
                    ),
                    tooltip: isModularDashboard
                        ? 'Switch to Feed View'
                        : 'Switch to Dashboard View',
                    visualDensity: VisualDensity.compact,
                  ),
                if (onNotificationPressed != null)
                  IconButton(
                    onPressed: onNotificationPressed,
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                if (onSettingsPressed != null)
                  IconButton(
                    onPressed: onSettingsPressed,
                    icon: const Icon(
                      Icons.settings_outlined,
                      size: 20,
                      color: AppTheme.textSecondary,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                if (onAvatarPressed != null) ...[
                  const SizedBox(width: 8),
                  AppAvatarWidget(
                    avatarId: avatarId,
                    size: 32,
                    onTap: onAvatarPressed,
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    boxShadow: isConnected
                        ? [
                            BoxShadow(
                              color: AppTheme.cyan.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  connection.stateLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(
                  battery.isCharging
                      ? Icons.battery_charging_full_rounded
                      : Icons.battery_5_bar_rounded,
                  size: 16,
                  color: battery.isAvailable
                      ? AppTheme.cyan
                      : AppTheme.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  battery.isAvailable ? '${battery.percentage}%' : '--',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: battery.isAvailable
                        ? AppTheme.textSecondary
                        : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Modular Heart Rate card matching Screen B.
class HeartRateModularCard extends StatelessWidget {
  final HeartRateData data;
  final VoidCallback onTap;

  const HeartRateModularCard({
    super.key,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ModularBaseCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.favorite_rounded,
                size: 18,
                color: AppTheme.heartRateRed,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Heart Rate',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Text(
                'Just now',
                style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                data.currentBpm > 0 ? '${data.currentBpm}' : '--',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'bpm',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          MiniSparkline(
            points: data.sparkline,
            lineColor: AppTheme.primaryBlueLight,
            height: 30,
          ),
          const SizedBox(height: 6),
          Text(
            data.statusLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modular SpO2 card matching Screen B.
class Spo2ModularCard extends StatelessWidget {
  final Spo2Data data;
  final VoidCallback onTap;

  const Spo2ModularCard({super.key, required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ModularBaseCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.water_drop_rounded,
                size: 18,
                color: AppTheme.spo2Cyan,
              ),
              const SizedBox(width: 6),
              const Text(
                'SpO₂',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                data.percentage > 0 ? '${data.percentage}' : '--',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 2),
              const Text(
                '%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          MiniSparkline(
            points: data.sparkline,
            lineColor: AppTheme.cyan,
            height: 30,
          ),
          const SizedBox(height: 6),
          Text(
            data.statusLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modular Posture card matching Screen B.
class PostureModularCard extends StatelessWidget {
  final PostureData data;
  final VoidCallback onTap;

  const PostureModularCard({
    super.key,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGood = data.isGood;
    final postureColor = isGood
        ? AppTheme.goodPostureGreen
        : AppTheme.badPostureOrange;

    final hasData = data.postureScoreToday > 0 || data.tiltDegrees > 0;
    final primaryLabel = hasData
        ? (isGood ? 'Upright' : (data.isSlouching ? 'Slouching' : data.classificationLabel))
        : (isGood ? 'Good' : 'Resting');

    return _ModularBaseCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.accessibility_new_rounded,
                size: 18,
                color: postureColor,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Posture',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: postureColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  data.postureScoreToday > 0
                      ? '${data.postureScoreToday} pts'
                      : (data.tiltDegrees > 0 ? '${data.tiltDegrees.toStringAsFixed(1)}°' : 'Active'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: postureColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  primaryLabel,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: isGood ? AppTheme.textPrimary : AppTheme.badPostureOrange,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 4),
                if (data.tiltDegrees > 0)
                  Text(
                    '${data.tiltDegrees.toStringAsFixed(1)}°',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          MiniSparkline(
            points: data.sparkline,
            lineColor: postureColor,
            height: 30,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                isGood
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                size: 13,
                color: postureColor,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  isGood
                      ? 'Optimal Alignment'
                      : 'Tilt detected (${data.tiltDegrees.toStringAsFixed(1)}°)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: postureColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modular Steps card matching Screen B.
class StepsModularCard extends StatelessWidget {
  final ActivityData data;
  final VoidCallback onTap;

  const StepsModularCard({super.key, required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ModularBaseCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(
                Icons.directions_run_rounded,
                size: 18,
                color: AppTheme.cyan,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Steps',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Text(
                'Today',
                style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _formatNumber(data.steps),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'steps',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 30,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: data.goalProgress,
                  minHeight: 6,
                  backgroundColor: AppTheme.cyan.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.cyan),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '/ ${_formatNumber(data.stepGoal)} (${(data.goalProgress * 100).toInt()}%)',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatNumber(int val) {
    return val.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

/// Wide "Today's Activity" card matching Screen B.
class TodaysActivityCard extends StatelessWidget {
  final ActivityData data;
  final VoidCallback onTap;

  const TodaysActivityCard({
    super.key,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ModularBaseCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Activity",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Active Time
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.directions_walk_rounded,
                      size: 24,
                      color: AppTheme.cyan,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data.activeMinutes} min',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Text(
                          'Active time',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(height: 32, width: 1, color: AppTheme.border),
              const SizedBox(width: 16),
              // Calories
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 24,
                      color: AppTheme.caloriesOrange,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data.caloriesKcal} kcal',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Text(
                          'Calories',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Base container for modular cards ensuring unified padding, border, and ink response.
class _ModularBaseCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _ModularBaseCard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTheme.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
        hoverColor: AppTheme.cardLight,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}
