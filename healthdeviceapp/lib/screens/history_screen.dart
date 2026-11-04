import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../repositories/health_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_charts.dart';
import '../services/cloud_sync_service.dart';
import 'activity_detail_screen.dart';
import 'heart_rate_detail_screen.dart';
import 'posture_detail_screen.dart';
import 'spo2_detail_screen.dart';

enum HistoryCategoryTab { all, heartRate, spo2, steps }

/// Organized History Screen providing dedicated views and graphs for:
/// 1. Heart Rate (with graph, stats, and filtered HR records)
/// 2. SpO2 (with graph, stats, and filtered SpO2 records)
/// 3. Steps (with graph, stats, and filtered Step records)
/// 4. All Records (combined view with toggleable charts and feed)
class HistoryScreen extends StatefulWidget {
  final HealthRepository repository;

  const HistoryScreen({super.key, required this.repository});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  HistoryCategoryTab _selectedTab = HistoryCategoryTab.all;
  MetricTimeframe _timeframe = MetricTimeframe.day;
  bool _showTimelineFeed = true;

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
            return ValueListenableBuilder<ActivityData>(
              valueListenable: widget.repository.activity,
              builder: (context, activity, _) {
                return Scaffold(
                  backgroundColor: AppTheme.background,
                  appBar: AppBar(
                    title: const Text(
                      'History & Analytics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    centerTitle: true,
                    actions: [
                      IconButton(
                        icon: const Icon(
                          Icons.sync_rounded,
                          size: 20,
                          color: AppTheme.cyan,
                        ),
                        tooltip: 'Sync Cloud & Device',
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Syncing health data from cloud...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                          await CloudSyncService.instance.syncFromCloud(
                            repository: widget.repository,
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          _showTimelineFeed
                              ? Icons.bar_chart_rounded
                              : Icons.format_list_bulleted_rounded,
                          size: 20,
                          color: AppTheme.cyan,
                        ),
                        tooltip: _showTimelineFeed ? 'Show Charts' : 'Show Feed',
                        onPressed: () => setState(
                          () => _showTimelineFeed = !_showTimelineFeed,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                  body: SafeArea(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 32 : 16,
                        vertical: 16,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 860),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Primary Category Tabs: All | Heart Rate | SpO2 | Steps
                              _buildCategoryTabBar(),
                              const SizedBox(height: 16),

                              // 2. Timeframe Selector: Day | Week | Month
                              _buildTimeframeSelector(),
                              const SizedBox(height: 20),

                              // 3. Tab Specific Content (Graph + Stats + Logs)
                              if (_selectedTab == HistoryCategoryTab.heartRate) ...[
                                _buildHeartRateHistoryView(context, hr),
                              ] else if (_selectedTab == HistoryCategoryTab.spo2) ...[
                                _buildSpo2HistoryView(context, spo2),
                              ] else if (_selectedTab == HistoryCategoryTab.steps) ...[
                                _buildStepsHistoryView(context, activity),
                              ] else ...[
                                // All Mode: Supports toggling between feed and charts
                                if (_showTimelineFeed) ...[
                                  _buildFilteredFeed(context, (entry) => true),
                                ] else ...[
                                  _buildChartsStackView(
                                    hr: hr,
                                    spo2: spo2,
                                    activity: activity,
                                  ),
                                ],
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
      },
    );
  }

  // =========================================================================
  // TOP CATEGORY NAVIGATION TABS
  // =========================================================================
  Widget _buildCategoryTabBar() {
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
            child: _buildCategoryTabItem(
              tab: HistoryCategoryTab.all,
              icon: Icons.view_list_rounded,
              color: AppTheme.primaryBlue,
              title: 'All',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildCategoryTabItem(
              tab: HistoryCategoryTab.heartRate,
              icon: Icons.favorite_rounded,
              color: AppTheme.heartRateRed,
              title: 'Heart Rate',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildCategoryTabItem(
              tab: HistoryCategoryTab.spo2,
              icon: Icons.water_drop_rounded,
              color: AppTheme.spo2Cyan,
              title: 'SpO₂',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildCategoryTabItem(
              tab: HistoryCategoryTab.steps,
              icon: Icons.directions_run_rounded,
              color: AppTheme.cyan,
              title: 'Footsteps',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabItem({
    required HistoryCategoryTab tab,
    required IconData icon,
    required Color color,
    required String title,
  }) {
    final isSelected = _selectedTab == tab;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = tab),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.card : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: color.withValues(alpha: 0.4)) : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 6,
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
              size: 16,
              color: isSelected ? color : AppTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 1. HEART RATE DEDICATED VIEW (Graph + Stats + Filtered History)
  // =========================================================================
  Widget _buildHeartRateHistoryView(BuildContext context, HeartRateData hr) {
    List<ChartDataPoint> hrBars;
    String periodSubtitle;
    switch (_timeframe) {
      case MetricTimeframe.day:
      case MetricTimeframe.live:
        hrBars = hr.dayData;
        periodSubtitle = "Today's Hourly Heart Rate (bpm)";
        break;
      case MetricTimeframe.week:
        hrBars = hr.weekData;
        periodSubtitle = '7-Day Daily Average Heart Rate (bpm)';
        break;
      case MetricTimeframe.month:
        hrBars = hr.monthData;
        periodSubtitle = 'Monthly Average by Week (bpm)';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4 Stat KPI cards
        Row(
          children: [
            Expanded(child: _buildMetricKpiBox('Latest', hr.currentBpm > 0 ? '${hr.currentBpm}' : '--', 'bpm', AppTheme.heartRateRed)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricKpiBox('Min', hr.minToday > 0 ? '${hr.minToday}' : '--', 'bpm', AppTheme.goodPostureGreen)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricKpiBox('Avg', hr.avgToday > 0 ? '${hr.avgToday}' : '--', 'bpm', AppTheme.cyan)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricKpiBox('Max', hr.maxToday > 0 ? '${hr.maxToday}' : '--', 'bpm', AppTheme.statusOrange)),
          ],
        ),
        const SizedBox(height: 18),

        // Dedicated Heart Rate Chart Container
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite_rounded, size: 16, color: AppTheme.heartRateRed),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      periodSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  _buildLegendIndicator('Normal (60–100)', AppTheme.goodPostureGreen),
                  _buildLegendIndicator('High (>100)', AppTheme.heartRateRed),
                ],
              ),
              const SizedBox(height: 16),
              HealthBarChart(
                bars: hrBars,
                barColor: AppTheme.heartRateRed,
                height: 170,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Section Title: Logged Heart Rate Records
        const Text(
          'Heart Rate Readings Log',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 12),

        // Filtered Heart Rate History Feed
        _buildFilteredFeed(context, (entry) => _isHeartRateEntry(entry)),
      ],
    );
  }

  // =========================================================================
  // 2. SPO2 DEDICATED VIEW (Graph + Stats + Filtered History)
  // =========================================================================
  Widget _buildSpo2HistoryView(BuildContext context, Spo2Data spo2) {
    List<ChartDataPoint> spo2Bars;
    String periodSubtitle;
    switch (_timeframe) {
      case MetricTimeframe.day:
      case MetricTimeframe.live:
        spo2Bars = spo2.dayData;
        periodSubtitle = "Today's Hourly Blood Oxygen (% SpO₂)";
        break;
      case MetricTimeframe.week:
        spo2Bars = spo2.weekData;
        periodSubtitle = '7-Day Daily Average SpO₂ (%)';
        break;
      case MetricTimeframe.month:
        spo2Bars = spo2.monthData;
        periodSubtitle = 'Monthly Average by Week (% SpO₂)';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4 Stat KPI cards
        Row(
          children: [
            Expanded(child: _buildMetricKpiBox('Latest', spo2.percentage > 0 ? '${spo2.percentage}%' : '--', 'SpO₂', AppTheme.spo2Cyan)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricKpiBox('Min', spo2.minToday > 0 ? '${spo2.minToday}%' : '--', 'Lowest', AppTheme.cyan)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricKpiBox('Avg', spo2.avgToday > 0 ? '${spo2.avgToday}%' : '--', 'Mean', AppTheme.goodPostureGreen)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricKpiBox('Target', '≥95%', 'Clinical', AppTheme.goodPostureGreen)),
          ],
        ),
        const SizedBox(height: 18),

        // Dedicated SpO2 Chart Container
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.water_drop_rounded, size: 16, color: AppTheme.spo2Cyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      periodSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  _buildLegendIndicator('Normal (≥95%)', AppTheme.goodPostureGreen),
                  _buildLegendIndicator('Low (<95%)', AppTheme.cyan),
                ],
              ),
              const SizedBox(height: 16),
              HealthBarChart(
                bars: spo2Bars,
                barColor: AppTheme.cyan,
                height: 170,
                maxVal: 105,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Section Title: Logged SpO2 Records
        const Text(
          'Blood Oxygen (SpO₂) Readings Log',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 12),

        // Filtered SpO2 History Feed
        _buildFilteredFeed(context, (entry) => _isSpo2Entry(entry)),
      ],
    );
  }

  // =========================================================================
  // 3. STEPS DEDICATED VIEW (Graph + Stats + Filtered History)
  // =========================================================================
  Widget _buildStepsHistoryView(BuildContext context, ActivityData activity) {
    List<ChartDataPoint> activityBars;
    String periodSubtitle;
    switch (_timeframe) {
      case MetricTimeframe.day:
      case MetricTimeframe.live:
        activityBars = activity.hourlyBars;
        periodSubtitle = "Today's Hourly Steps Distribution";
        break;
      case MetricTimeframe.week:
        activityBars = activity.weeklyBars;
        periodSubtitle = '7-Day Daily Steps vs Goal';
        break;
      case MetricTimeframe.month:
        activityBars = activity.monthlyBars;
        periodSubtitle = 'Monthly Total Steps by Week';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4 Stat KPI cards
        Row(
          children: [
            Expanded(child: _buildMetricKpiBox('Steps', activity.steps > 0 ? '${activity.steps}' : '--', 'Today', AppTheme.cyan)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricKpiBox('Distance', '${activity.distanceKm.toStringAsFixed(1)}', 'km', AppTheme.goodPostureGreen)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricKpiBox('Calories', '${activity.caloriesKcal}', 'kcal', AppTheme.statusOrange)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricKpiBox('Active', '${activity.activeMinutes}', 'mins', AppTheme.primaryBlue)),
          ],
        ),
        const SizedBox(height: 18),

        // Dedicated Footsteps Chart Container
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_run_rounded, size: 16, color: AppTheme.cyan),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      periodSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  _buildLegendIndicator('Steps', AppTheme.cyan),
                  _buildLegendIndicator('Goal (10,000)', AppTheme.goodPostureGreen),
                ],
              ),
              const SizedBox(height: 16),
              HealthBarChart(
                bars: activityBars,
                barColor: AppTheme.cyan,
                height: 170,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Section Title: Logged Footsteps Records
        const Text(
          'Footsteps Activity Log',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 12),

        // Filtered Steps History Feed
        _buildFilteredFeed(context, (entry) => _isStepsEntry(entry)),
      ],
    );
  }

  // =========================================================================
  // CHARTS STACK VIEW (Day / Week / Month Multi-Chart view)
  // =========================================================================
  Widget _buildChartsStackView({
    required HeartRateData hr,
    required Spo2Data spo2,
    required ActivityData activity,
  }) {
    List<ChartDataPoint> hrBars;
    List<ChartDataPoint> spo2Bars;
    List<ChartDataPoint> activityBars;
    String periodSubtitle;

    switch (_timeframe) {
      case MetricTimeframe.day:
      case MetricTimeframe.live:
        hrBars = hr.dayData;
        spo2Bars = spo2.dayData;
        activityBars = activity.hourlyBars;
        periodSubtitle = "Today's Hourly Readings (8 AM – 8 PM)";
        break;
      case MetricTimeframe.week:
        hrBars = hr.weekData;
        spo2Bars = spo2.weekData;
        activityBars = activity.weeklyBars;
        periodSubtitle = "7-Day Range Daily Aggregation (Mon – Sun)";
        break;
      case MetricTimeframe.month:
        hrBars = hr.monthData;
        spo2Bars = spo2.monthData;
        activityBars = activity.monthlyBars;
        periodSubtitle = "Monthly Aggregation by Week (W1 – W4)";
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          periodSubtitle,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.cyan,
          ),
        ),
        const SizedBox(height: 14),

        // Heart Rate
        _buildStackedChartHeader('Heart Rate (bpm)', Icons.favorite_rounded, AppTheme.heartRateRed, [
          _buildLegendIndicator('Normal (60–100)', AppTheme.goodPostureGreen),
          _buildLegendIndicator('High (>100)', AppTheme.heartRateRed),
        ]),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.all(18),
          child: HealthBarChart(
            bars: hrBars,
            barColor: AppTheme.primaryBlue,
            height: 160,
          ),
        ),
        const SizedBox(height: 24),

        // SpO2
        _buildStackedChartHeader('SpO₂ (%)', Icons.water_drop_rounded, AppTheme.spo2Cyan, [
          _buildLegendIndicator('Normal (≥95%)', AppTheme.goodPostureGreen),
          _buildLegendIndicator('Low (<95%)', AppTheme.cyan),
        ]),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.all(18),
          child: HealthBarChart(
            bars: spo2Bars,
            barColor: AppTheme.cyan,
            height: 160,
            maxVal: 105,
          ),
        ),
        const SizedBox(height: 24),

        // Steps
        _buildStackedChartHeader('Footsteps', Icons.directions_run_rounded, AppTheme.cyan, [
          _buildLegendIndicator('Steps', AppTheme.cyan),
          _buildLegendIndicator('Goal (10k)', AppTheme.goodPostureGreen),
        ]),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          padding: const EdgeInsets.all(18),
          child: HealthBarChart(
            bars: activityBars,
            barColor: AppTheme.cyan,
            height: 160,
          ),
        ),
      ],
    );
  }

  Widget _buildStackedChartHeader(String title, IconData icon, Color color, List<Widget> legends) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        Row(
          children: legends.expand((w) => [w, const SizedBox(width: 10)]).take(legends.length * 2 - 1).toList(),
        ),
      ],
    );
  }

  // =========================================================================
  // SHARED FEED & LOG RENDERER
  // =========================================================================
  Widget _buildFilteredFeed(BuildContext context, bool Function(HistoryEntry) filter) {
    return ValueListenableBuilder<List<HistoryEntry>>(
      valueListenable: widget.repository.historyEntries,
      builder: (context, allEntries, _) {
        return FutureBuilder<List<HistoryEntry>>(
          future: widget.repository.getHistoryEntries(timeframe: _timeframe),
          builder: (context, snapshot) {
            final raw = snapshot.data ?? [];
            final entries = raw.where(filter).toList();

            if (entries.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Center(
                  child: Text(
                    'No records found for this period.\\nSync data from device or cloud to view records.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
              );
            }

            // Group entries dynamically by section
            final sections = <String, List<HistoryEntry>>{};
            for (final e in entries) {
              sections.putIfAbsent(e.section, () => []).add(e);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusSummaryHeader(entries),
                ...sections.entries.map((sec) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sec.key,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildFeedCard(context, sec.value),
                      const SizedBox(height: 20),
                    ],
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatusSummaryHeader(List<HistoryEntry> entries) {
    int normalCount = 0;
    int highCount = 0;
    int lowCount = 0;

    for (final e in entries) {
      if (_isStepsEntry(e)) continue; // Footsteps are cumulative activity towards a daily goal, not clinical vitals
      final s = e.status.toLowerCase();
      if (s.contains('high') || s.contains('elevated')) {
        highCount++;
      } else if (s.contains('normal') || s.contains('optimal') || s.contains('good')) {
        normalCount++;
      } else if (s.contains('low')) {
        lowCount++;
      }
    }

    if (normalCount == 0 && highCount == 0 && lowCount == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          if (normalCount > 0)
            _buildStatusChip('Normal: $normalCount', AppTheme.goodPostureGreen),
          if (highCount > 0) ...[
            const SizedBox(width: 8),
            _buildStatusChip('High: $highCount', AppTheme.heartRateRed),
          ],
          if (lowCount > 0) ...[
            const SizedBox(width: 8),
            _buildStatusChip('Low: $lowCount', AppTheme.cyan),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedCard(BuildContext context, List<HistoryEntry> entries) {
    return Material(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entries.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = entries[index];
          final iconData = _getCategoryIcon(item.category);
          final iconColor = _getCategoryColor(item.category, item.status);
          final statusColor = _getStatusColor(item.status);

          return ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(iconData, size: 20, color: iconColor),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${item.valueDisplay} ${item.unit}'.trim(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: iconColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.status.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      item.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                item.detail,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppTheme.textMuted,
            ),
            onTap: () => _navigateToDetail(context, item.category),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
          );
        },
      ),
    );
  }

  // Helpers to classify entries
  bool _isHeartRateEntry(HistoryEntry e) {
    final cat = e.category.toLowerCase();
    final title = e.title.toLowerCase();
    final unit = e.unit.toLowerCase();
    return cat.contains('heart') || title.contains('heart') || unit.contains('bpm');
  }

  bool _isSpo2Entry(HistoryEntry e) {
    final cat = e.category.toLowerCase();
    final title = e.title.toLowerCase();
    return cat.contains('spo2') || title.contains('spo2') || title.contains('oxygen');
  }

  bool _isStepsEntry(HistoryEntry e) {
    final cat = e.category.toLowerCase();
    final title = e.title.toLowerCase();
    final unit = e.unit.toLowerCase();
    return cat.contains('step') || cat.contains('activity') || title.contains('step') || unit.contains('step');
  }

  Widget _buildMetricKpiBox(String title, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textMuted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color)),
          ),
          Text(unit, style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary)),
        ],
      ),
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
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendIndicator(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('heart')) {
      return Icons.favorite_rounded;
    } else if (lower.contains('spo2') || lower.contains('oxygen')) {
      return Icons.water_drop_rounded;
    } else if (lower.contains('posture') || lower.contains('ergonomic')) {
      return Icons.accessibility_new_rounded;
    } else if (lower.contains('activity') || lower.contains('step')) {
      return Icons.directions_run_rounded;
    } else {
      return Icons.insights_rounded;
    }
  }

  Color _getCategoryColor(String cat, String status) {
    final lower = cat.toLowerCase();
    if (lower.contains('heart')) {
      return AppTheme.heartRateRed;
    } else if (lower.contains('spo2') || lower.contains('oxygen')) {
      return AppTheme.spo2Cyan;
    } else if (lower.contains('posture') || lower.contains('ergonomic')) {
      return status.toLowerCase().contains('bad') ||
              status.toLowerCase().contains('slouch')
          ? AppTheme.badPostureOrange
          : AppTheme.goodPostureGreen;
    } else if (lower.contains('activity') || lower.contains('step')) {
      return AppTheme.cyan;
    } else {
      return AppTheme.primaryBlue;
    }
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('high') || s.contains('elevated')) {
      return AppTheme.heartRateRed;
    }
    if (s.contains('normal') || s.contains('optimal') || s.contains('good') || s.contains('met')) {
      return AppTheme.goodPostureGreen;
    }
    if (s.contains('low')) {
      return AppTheme.cyan;
    }
    if (s.contains('bad') || s.contains('slouch')) {
      return AppTheme.badPostureOrange;
    }
    return AppTheme.textSecondary;
  }

  void _navigateToDetail(BuildContext context, String category) {
    if (category.toLowerCase().contains('heart')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => HeartRateDetailScreen(
            repository: widget.repository,
            onNavigateToSpo2: () {
              Navigator.of(ctx).pop();
              _navigateToDetail(context, 'spo2');
            },
          ),
        ),
      );
    } else if (category.toLowerCase().contains('spo2') ||
        category.toLowerCase().contains('oxygen')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => Spo2DetailScreen(repository: widget.repository),
        ),
      );
    } else if (category.toLowerCase().contains('activity') ||
        category.toLowerCase().contains('step')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => ActivityDetailScreen(repository: widget.repository),
        ),
      );
    } else if (category.toLowerCase().contains('posture') ||
        category.toLowerCase().contains('ergonomic')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (ctx) => PostureDetailScreen(repository: widget.repository),
        ),
      );
    }
  }
}