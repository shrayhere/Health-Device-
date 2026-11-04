import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Screen: Button Guide explaining physical hardware button interactions per screen.
/// Directly grounded in authentic HealthDevice ESP32 firmware button handling.
class ButtonGuideScreen extends StatelessWidget {
  const ButtonGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Button Guide',
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
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hardware Button Overview Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.border),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlueLight.withValues(
                              alpha: 0.15,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.cyan.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Icon(
                            Icons.touch_app_rounded,
                            size: 24,
                            color: AppTheme.cyan,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Physical Button Controls',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'The HealthDevice uses a single multi-function tactile button. Actions dynamically adapt to the active screen.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 1. Global & Power Management
                  _buildSectionHeader('GLOBAL & POWER'),
                  _buildGuideCard([
                    _buildActionRow(
                      gesture: 'Hold for 3 Seconds',
                      action:
                          'Enter Low-Power Standby Mode (Display turns off)',
                      icon: Icons.power_settings_new_rounded,
                    ),
                    const Divider(height: 1),
                    _buildActionRow(
                      gesture: 'Single Click or Press',
                      action: 'Wake device from standby mode',
                      icon: Icons.wb_sunny_outlined,
                    ),
                    const Divider(height: 1),
                    _buildActionRow(
                      gesture: 'Double Click (Global)',
                      action: 'Return immediately to the HOME Screen',
                      icon: Icons.home_rounded,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // 2. Heart Rate & SpO2
                  _buildSectionHeader('HEART RATE & SPO₂'),
                  _buildGuideCard([
                    _buildActionRow(
                      gesture: 'Long Press',
                      action: 'Start 8-second optical vital scan',
                      icon: Icons.play_arrow_rounded,
                    ),
                    const Divider(height: 1),
                    _buildActionRow(
                      gesture: 'Double Click',
                      action: 'Cancel active measurement scan',
                      icon: Icons.close_rounded,
                    ),
                    const Divider(height: 1),
                    _buildActionRow(
                      gesture: 'Triple Click',
                      action: 'Cycle sensor modes: 8s Auto-Scan → SpO₂ → Live Continuous Vitals',
                      icon: Icons.refresh_rounded,
                    ),
                    const Divider(height: 1),
                    _buildActionRow(
                      gesture: 'Single Click',
                      action: 'Clear finished result or advance to next screen',
                      icon: Icons.arrow_forward_rounded,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // 3. Posture & Ergonomics
                  _buildSectionHeader('POSTURE MONITOR'),
                  _buildGuideCard([
                    _buildActionRow(
                      gesture: 'Single Click',
                      action: 'Advance to next screen',
                      icon: Icons.arrow_forward_rounded,
                    ),
                    const Divider(height: 1),
                    _buildActionRow(
                      gesture: 'Long Press',
                      action: 'Enter Posture Calibration Setup mode',
                      icon: Icons.accessibility_new_rounded,
                    ),
                    const Divider(height: 1),
                    _buildActionRow(
                      gesture: 'In Setup: Click or Hold',
                      action:
                          'Calibrate current upright spine posture baseline',
                      icon: Icons.check_circle_outline_rounded,
                    ),
                    const Divider(height: 1),
                    _buildActionRow(
                      gesture: 'In Setup: Double Click',
                      action: 'Cancel and return to Posture monitor',
                      icon: Icons.close_rounded,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // 4. Clock, Timer & Stopwatch
                  _buildSectionHeader('CLOCK, TIMER & STOPWATCH'),
                  _buildGuideCard([
                    _buildActionRow(
                      gesture: 'Triple Click',
                      action: 'Cycle modes: Clock → Timer → Stopwatch → Alarms',
                      icon: Icons.swap_horiz_rounded,
                    ),
                    const Divider(height: 1),
                    _buildActionRow(
                      gesture: 'On Timer: Long Press',
                      action: 'Start or Pause countdown timer',
                      icon: Icons.timer_outlined,
                    ),
                    const Divider(height: 1),
                    _buildActionRow(
                      gesture: 'On Timer: Double Click',
                      action: 'Reset running timer, or enter Timer Edit mode if stopped',
                      icon: Icons.replay_rounded,
                    ),
                    const Divider(height: 1),
                    _buildActionRow(
                      gesture: 'On Stopwatch: Long Press',
                      action: 'Start or Pause stopwatch chronometer',
                      icon: Icons.timer_rounded,
                    ),
                    const Divider(height: 1),
                    _buildActionRow(
                      gesture: 'On Stopwatch: Double Click',
                      action: 'Reset stopwatch to 00:00.00',
                      icon: Icons.restart_alt_rounded,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // 5. Wellness & Breathing
                  _buildSectionHeader('WELLNESS & BREATHING'),
                  _buildGuideCard([
                    _buildActionRow(
                      gesture: 'Wellness: Double Click',
                      action: 'Quick Log Water (+1 glass) and dismiss water reminder',
                      icon: Icons.water_drop_rounded,
                    ),
                    const Divider(height: 1),
                    _buildActionRow(
                      gesture: 'Breathing: Long Press',
                      action: 'Start or Pause guided 4-7-8 breathing exercise',
                      icon: Icons.air_rounded,
                    ),
                    const Divider(height: 1),
                    _buildActionRow(
                      gesture: 'Breathing: Single Click',
                      action: 'Stop breathing guide and advance to next screen',
                      icon: Icons.arrow_forward_rounded,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // 6. Reminders & Menus
                  _buildSectionHeader('REMINDERS & DEVICE MENUS'),
                  _buildGuideCard([
                    _buildActionRow(
                      gesture: 'On Reminders: Triple Click',
                      action: 'Open Reminders ON/OFF selection menu',
                      icon: Icons.access_time_rounded,
                    ),
                    const Divider(height: 1),
                    _buildActionRow(
                      gesture: 'In Menu: Single Click',
                      action: 'Cycle down to next item',
                      icon: Icons.arrow_downward_rounded,
                    ),
                    const Divider(height: 1),
                    _buildActionRow(
                      gesture: 'In Menu: Double Click',
                      action: 'Select / Activate highlighted option',
                      icon: Icons.check_rounded,
                    ),
                    const Divider(height: 1),
                    _buildActionRow(
                      gesture: 'In Menu: Triple Click',
                      action: 'Exit selection mode or return to Main Menu',
                      icon: Icons.keyboard_return_rounded,
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // 7. Safety Alerts
                  _buildSectionHeader('SAFETY ALERTS & FALL DETECTION'),
                  _buildGuideCard([
                    _buildActionRow(
                      gesture: 'Any Press / Click',
                      action: 'Dismiss active Alarm, Timer alert, or Fall Detection overlay',
                      icon: Icons.warning_amber_rounded,
                    ),
                  ]),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.cyan,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildGuideCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildActionRow({
    required String gesture,
    required String action,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.cyan),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gesture,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  action,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
