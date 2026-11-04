import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../repositories/health_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_charts.dart';

/// Screen D1: SpO2 Detail matching reference Screen D1 with Live/Day/Week/Month selector,
/// cyan curve, and Min/Avg/Max summary blocks.
class Spo2DetailScreen extends StatefulWidget {
  final HealthRepository repository;

  const Spo2DetailScreen({super.key, required this.repository});

  @override
  State<Spo2DetailScreen> createState() => _Spo2DetailScreenState();
}

class _Spo2DetailScreenState extends State<Spo2DetailScreen> {
  MetricTimeframe _timeframe = MetricTimeframe.live;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

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
              'SpO₂',
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
                      // Timeframe selector
                      _buildTimeframeSelector(),
                      const SizedBox(height: 24),

                      // Current Reading Hero
                      Row(
                        children: [
                          const Icon(
                            Icons.water_drop_rounded,
                            size: 28,
                            color: AppTheme.spo2Cyan,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${spo2.percentage}',
                                    style: const TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.textPrimary,
                                      letterSpacing: -1.0,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    '%',
                                    style: TextStyle(
                                      fontSize: 18,
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

                      // Line Chart with Y-axis 100, 95, 90, 85
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.border),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                        child: HealthLineChart(
                          points: _getPointsForTimeframe(spo2),
                          minY: 85,
                          maxY: 100,
                          yLabels: const [85, 90, 95, 100],
                          lineColor: AppTheme.cyan,
                          gradientColor: AppTheme.cyan,
                          height: 180,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3 Summary Stat Boxes: 96 Min | 98 Avg | 99 Max
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatBox(
                              value: '${spo2.minToday}',
                              label: 'Min',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatBox(
                              value: '${spo2.avgToday}',
                              label: 'Avg',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatBox(
                              value: '${spo2.maxToday}',
                              label: 'Max',
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

  List<ChartDataPoint> _getPointsForTimeframe(Spo2Data spo2) {
    switch (_timeframe) {
      case MetricTimeframe.live:
      case MetricTimeframe.day:
        return spo2.dayData;
      case MetricTimeframe.week:
        return spo2.weekData;
      case MetricTimeframe.month:
        return spo2.monthData;
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
}
