import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../repositories/health_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_charts.dart';

/// Screen D: Data Focus (Vitals) - Heart Rate detail with clean charts & timeframe selector.
class HeartRateDetailScreen extends StatefulWidget {
  final HealthRepository repository;
  final VoidCallback? onNavigateToSpo2;
  final VoidCallback? onNavigateToActivity;

  const HeartRateDetailScreen({
    super.key,
    required this.repository,
    this.onNavigateToSpo2,
    this.onNavigateToActivity,
  });

  @override
  State<HeartRateDetailScreen> createState() => _HeartRateDetailScreenState();
}

class _HeartRateDetailScreenState extends State<HeartRateDetailScreen> {
  MetricTimeframe _timeframe = MetricTimeframe.live;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return ValueListenableBuilder<HeartRateData>(
      valueListenable: widget.repository.heartRate,
      builder: (context, hr, _) {
        return ValueListenableBuilder<Spo2Data>(
          valueListenable: widget.repository.spo2,
          builder: (context, spo2, _) {
            return Scaffold(
              backgroundColor: AppTheme.background,
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: const Text(
                  'Heart Rate',
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
                          // Timeframe Selector: Live | Day | Week | Month
                          _buildTimeframeSelector(),
                          const SizedBox(height: 24),

                          // Current Reading Hero
                          Row(
                            children: [
                              const Icon(
                                Icons.favorite_rounded,
                                size: 28,
                                color: AppTheme.heartRateRed,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '${hr.currentBpm}',
                                        style: const TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.textPrimary,
                                          letterSpacing: -1.0,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'bpm',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Text(
                                    'Normal range',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.goodPostureGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Large Line Chart with Y-axis labels 120, 90, 60, 30
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.card,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppTheme.border),
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                            child: HealthLineChart(
                              points: _getPointsForTimeframe(hr),
                              minY: 30,
                              maxY: 120,
                              yLabels: const [30, 60, 90, 120],
                              lineColor: AppTheme.cyan,
                              gradientColor: AppTheme.primaryBlue,
                              height: 180,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 3 Summary Stat Boxes: Min | Avg | Max
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatBox(
                                  value: '${hr.minToday}',
                                  label: 'Min',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatBox(
                                  value: '${hr.avgToday}',
                                  label: 'Avg',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatBox(
                                  value: '${hr.maxToday}',
                                  label: 'Max',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Secondary Metric Card: SpO2
                          _buildSecondarySpo2Card(spo2),
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

  List<ChartDataPoint> _getPointsForTimeframe(HeartRateData hr) {
    switch (_timeframe) {
      case MetricTimeframe.live:
      case MetricTimeframe.day:
        return hr.dayData;
      case MetricTimeframe.week:
        return hr.weekData;
      case MetricTimeframe.month:
        return hr.monthData;
    }
  }

  Widget _buildStatBox({required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondarySpo2Card(Spo2Data spo2) {
    return Material(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onNavigateToSpo2,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.cyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: AppTheme.cyan,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SpO₂',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${spo2.percentage}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Text(
                          '%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          spo2.statusLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.goodPostureGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 70,
                child: MiniSparkline(
                  points: spo2.sparkline,
                  lineColor: AppTheme.cyan,
                  height: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
