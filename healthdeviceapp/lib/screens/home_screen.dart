import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../repositories/health_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_charts.dart';
import '../widgets/metric_card.dart';
import 'activity_detail_screen.dart';
import 'ai_assistant_screen.dart';
import 'heart_rate_detail_screen.dart';
import 'notifications_screen.dart';
import 'posture_detail_screen.dart';
import 'spo2_detail_screen.dart';
import 'webcam_posture_screen.dart';
import '../repositories/auth_repository.dart';

/// Screen B: Modular Dashboard & Screen A: Today Feed.
/// Primary landing screen matching the reference image.
class HomeScreen extends StatefulWidget {
  final HealthRepository repository;
  final AuthRepository? authRepository;
  final VoidCallback onNavigateToDevice;
  final VoidCallback onNavigateToHistory;
  final VoidCallback onNavigateToProfile;

  const HomeScreen({
    super.key,
    required this.repository,
    this.authRepository,
    required this.onNavigateToDevice,
    required this.onNavigateToHistory,
    required this.onNavigateToProfile,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Option to switch between Modular Dashboard (Screen B) and Today Feed (Screen A)
  bool _isModularDashboard = true;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return ValueListenableBuilder<ConnectionStatus>(
      valueListenable: widget.repository.connectionStatus,
      builder: (context, connection, _) {
        return ValueListenableBuilder<BatteryData>(
          valueListenable: widget.repository.battery,
          builder: (context, battery, _) {
            return ValueListenableBuilder<HeartRateData>(
              valueListenable: widget.repository.heartRate,
              builder: (context, hr, _) {
                return ValueListenableBuilder<Spo2Data>(
                  valueListenable: widget.repository.spo2,
                  builder: (context, spo2, _) {
                    return ValueListenableBuilder<PostureData>(
                      valueListenable: widget.repository.posture,
                      builder: (context, posture, _) {
                        return ValueListenableBuilder<ActivityData>(
                          valueListenable: widget.repository.activity,
                          builder: (context, activity, _) {
                            return Scaffold(
                              backgroundColor: AppTheme.background,
                              body: SafeArea(
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isDesktop ? 32 : 20,
                                    vertical: 20,
                                  ),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 1040,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Top Header matching Screen B / A with custom avatar shortcut
                                          ValueListenableBuilder<
                                            UserHealthProfile?
                                          >(
                                            valueListenable:
                                                widget
                                                    .authRepository
                                                    ?.currentProfile ??
                                                ValueNotifier<
                                                  UserHealthProfile?
                                                >(null),
                                            builder: (context, profile, _) {
                                              return DeviceTopHeader(
                                                connection: connection,
                                                battery: battery,
                                                onSettingsPressed: null,
                                                avatarId: profile?.avatarId,
                                                onAvatarPressed:
                                                    widget.onNavigateToProfile,
                                                onViewModeToggle: () => setState(
                                                  () => _isModularDashboard =
                                                      !_isModularDashboard,
                                                ),
                                                isModularDashboard:
                                                    _isModularDashboard,
                                                onNotificationPressed: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (ctx) =>
                                                          NotificationsScreen(
                                                            repository: widget
                                                                .repository,
                                                          ),
                                                    ),
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 18),

                                          _buildAiAssistantCard(context),
                                          const SizedBox(height: 18),

                                          if (!kIsWeb && Platform.isWindows) ...[
                                            _buildAiPostureTrackerCard(context),
                                            const SizedBox(height: 18),
                                          ],

                                          if (_isModularDashboard)
                                            _buildModularDashboard(
                                              context,
                                              isDesktop: isDesktop,
                                              hr: hr,
                                              spo2: spo2,
                                              posture: posture,
                                              activity: activity,
                                            )
                                          else
                                            _buildTodayFeed(
                                              context,
                                              isDesktop: isDesktop,
                                              hr: hr,
                                              spo2: spo2,
                                              posture: posture,
                                              activity: activity,
                                            ),

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
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  /// Screen B: Modular Dashboard (2x2 key metric cards + Today's Activity banner)
  Widget _buildModularDashboard(
    BuildContext context, {
    required bool isDesktop,
    required HeartRateData hr,
    required Spo2Data spo2,
    required PostureData posture,
    required ActivityData activity,
  }) {
    return Column(
      children: [
        // 2x2 Modular Grid (responsive on desktop)
        if (isDesktop) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: HeartRateModularCard(
                  data: hr,
                  onTap: () => _openHeartRateDetail(context),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Spo2ModularCard(
                  data: spo2,
                  onTap: () => _openSpo2Detail(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: PostureModularCard(
                  data: posture,
                  onTap: () => _openPostureDetail(context),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StepsModularCard(
                  data: activity,
                  onTap: () => _openActivityDetail(context),
                ),
              ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: HeartRateModularCard(
                  data: hr,
                  onTap: () => _openHeartRateDetail(context),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Spo2ModularCard(
                  data: spo2,
                  onTap: () => _openSpo2Detail(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PostureModularCard(
                  data: posture,
                  onTap: () => _openPostureDetail(context),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: StepsModularCard(
                  data: activity,
                  onTap: () => _openActivityDetail(context),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 16),

        // Wide Today's Activity Card (Screen B)
        TodaysActivityCard(
          data: activity,
          onTap: () => _openActivityDetail(context),
        ),
      ],
    );
  }

  /// Screen A: Today Feed (Big Heart Rate Card with vertical bar graph + list items)
  Widget _buildTodayFeed(
    BuildContext context, {
    required bool isDesktop,
    required HeartRateData hr,
    required Spo2Data spo2,
    required PostureData posture,
    required ActivityData activity,
  }) {
    return Column(
      children: [
        // Big Heart Rate Hero Card with bar chart
        Material(
          color: AppTheme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppTheme.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openHeartRateDetail(context),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.favorite_rounded,
                            size: 20,
                            color: AppTheme.heartRateRed,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Heart Rate',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppTheme.textMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        hr.currentBpm > 0 ? '${hr.currentBpm}' : '--',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'bpm',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  HealthBarChart(
                    bars: const [
                      ChartDataPoint(x: 0, y: 64),
                      ChartDataPoint(x: 1, y: 70),
                      ChartDataPoint(x: 2, y: 68),
                      ChartDataPoint(x: 3, y: 72),
                      ChartDataPoint(x: 4, y: 88),
                      ChartDataPoint(x: 5, y: 74),
                      ChartDataPoint(x: 6, y: 92),
                      ChartDataPoint(x: 7, y: 71),
                      ChartDataPoint(x: 8, y: 68),
                      ChartDataPoint(x: 9, y: 75),
                      ChartDataPoint(x: 10, y: 72),
                    ],
                    barColor: AppTheme.primaryBlue,
                    height: 80,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // List Rows (Screen A)
        _buildListMetricRow(
          icon: Icons.water_drop_rounded,
          iconColor: AppTheme.spo2Cyan,
          title: 'SpO₂',
          value: '${spo2.percentage} %',
          subtitle: 'Just now',
          onTap: () => _openSpo2Detail(context),
        ),
        const SizedBox(height: 12),
        _buildListMetricRow(
          icon: Icons.accessibility_new_rounded,
          iconColor: AppTheme.goodPostureGreen,
          title: 'Posture',
          value: posture.classificationLabel,
          subtitle: posture.subLabel,
          onTap: () => _openPostureDetail(context),
        ),
        const SizedBox(height: 12),
        _buildListMetricRow(
          icon: Icons.directions_run_rounded,
          iconColor: AppTheme.cyan,
          title: 'Steps',
          value: activity.steps.toString(),
          subtitle: 'Today',
          onTap: () => _openActivityDetail(context),
        ),
      ],
    );
  }

  Widget _buildListMetricRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(icon, size: 22, color: iconColor),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppTheme.textMuted,
            ),
          ],
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
      ),
    );
  }

  void _openHeartRateDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => HeartRateDetailScreen(
          repository: widget.repository,
          onNavigateToSpo2: () {
            Navigator.of(ctx).pop();
            _openSpo2Detail(context);
          },
        ),
      ),
    );
  }

  void _openSpo2Detail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Spo2DetailScreen(repository: widget.repository),
      ),
    );
  }

  void _openActivityDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => ActivityDetailScreen(repository: widget.repository),
      ),
    );
  }

  void _openPostureDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => PostureDetailScreen(repository: widget.repository),
      ),
    );
  }

  Widget _buildAiAssistantCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.cyan.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => AiAssistantScreen(
                  healthRepository: widget.repository,
                  authRepository: widget.authRepository,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.cyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.cyan.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: AppTheme.cyan,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HealthDevice AI Assistant',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Ask about your vitals, trend analysis & posture guidance',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlueLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ask AI',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickPill(context, '📊 Daily Summary'),
                      const SizedBox(width: 8),
                      _buildQuickPill(context, '📈 Trend Analysis'),
                      const SizedBox(width: 8),
                      _buildQuickPill(context, '🧍 Posture Habits'),
                      const SizedBox(width: 8),
                      _buildQuickPill(context, '⌚ Hardware Guide'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickPill(BuildContext context, String title) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => AiAssistantScreen(
              healthRepository: widget.repository,
              authRepository: widget.authRepository,
              initialPrompt: title,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  /// AI Posture Tracker launcher card matching the reference UI
  Widget _buildAiPostureTrackerCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.borderSubtle,
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => WebcamPostureScreen(
                  repository: widget.repository,
                  authRepository: widget.authRepository,
                  autoStart: true,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.cyan.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Icon(
                    Icons.videocam_rounded,
                    size: 22,
                    color: AppTheme.cyan,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          const Text(
                            'AI Posture Tracker',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF334155),
                              ),
                            ),
                            child: const Text(
                              'CAMERA AI',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Webcam pose tracking & voice alert',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.cyan,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Launch',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
