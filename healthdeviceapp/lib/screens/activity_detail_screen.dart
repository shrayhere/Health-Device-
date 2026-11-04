import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../repositories/health_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_charts.dart';

/// Screen C1: Activity Details matching reference Screen C1 with Day/Week/Month,
/// date switcher, hourly bar chart, and 3 metric highlights.
class ActivityDetailScreen extends StatefulWidget {
  final HealthRepository repository;

  const ActivityDetailScreen({super.key, required this.repository});

  @override
  State<ActivityDetailScreen> createState() => _ActivityDetailScreenState();
}

class _ActivityDetailScreenState extends State<ActivityDetailScreen> {
  MetricTimeframe _timeframe = MetricTimeframe.day;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return ValueListenableBuilder<ActivityData>(
      valueListenable: widget.repository.activity,
      builder: (context, activity, _) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Activity',
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
                      // Day | Week | Month
                      _buildTimeframeSelector(),
                      const SizedBox(height: 20),

                      // Date switcher: < Mon, 28 Sep 2026 >
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.chevron_left_rounded,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const Text(
                            'Mon, 28 Sep 2026',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.chevron_right_rounded,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Activity Bar Chart Container
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.border),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: HealthBarChart(
                          bars: _getBarsForTimeframe(activity),
                          barColor: AppTheme.primaryBlue,
                          height: 180,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 3 Summary Cards matching Screen C1
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricBlock(
                              icon: Icons.directions_run_rounded,
                              iconColor: AppTheme.cyan,
                              value: _formatNumber(activity.steps),
                              label: 'Steps',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricBlock(
                              icon: Icons.directions_walk_rounded,
                              iconColor: AppTheme.cyan,
                              value: '${activity.activeMinutes} min',
                              label: 'Active time',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricBlock(
                              icon: Icons.local_fire_department_rounded,
                              iconColor: AppTheme.caloriesOrange,
                              value: '${activity.caloriesKcal} kcal',
                              label: 'Calories',
                            ),
                          ),
                        ],
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
  }

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

  List<ChartDataPoint> _getBarsForTimeframe(ActivityData activity) {
    switch (_timeframe) {
      case MetricTimeframe.live:
      case MetricTimeframe.day:
        return activity.hourlyBars;
      case MetricTimeframe.week:
        return activity.weeklyBars;
      case MetricTimeframe.month:
        return activity.monthlyBars;
    }
  }

  Widget _buildMetricBlock({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
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

  String _formatNumber(int val) {
    return val.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
