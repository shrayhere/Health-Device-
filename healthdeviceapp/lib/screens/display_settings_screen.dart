import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../repositories/health_repository.dart';
import '../theme/app_theme.dart';

/// Screen: Wearable OLED Display settings for HealthDevice.
class DisplaySettingsScreen extends StatelessWidget {
  final HealthRepository repository;

  const DisplaySettingsScreen({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return ValueListenableBuilder<DisplaySettings>(
      valueListenable: repository.displaySettings,
      builder: (context, display, _) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Display Settings',
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
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Screen Timeout Card (Clean vertical layout)
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
                            const Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  color: AppTheme.cyan,
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Screen Auto-Off Timeout',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Preserves battery by putting OLED display into sleep mode.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppTheme.borderSubtle,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: display.screenTimeoutSec,
                                  dropdownColor: AppTheme.card,
                                  isExpanded: true,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: AppTheme.cyan,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.cyan,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 10,
                                      child: Text('10 seconds'),
                                    ),
                                    DropdownMenuItem(
                                      value: 15,
                                      child: Text('15 seconds'),
                                    ),
                                    DropdownMenuItem(
                                      value: 30,
                                      child: Text('30 seconds'),
                                    ),
                                    DropdownMenuItem(
                                      value: 60,
                                      child: Text('1 minute'),
                                    ),
                                    DropdownMenuItem(
                                      value: 0,
                                      child: Text('Never (Always On)'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      repository.updateDisplaySettings(
                                        display.copyWith(
                                          screenTimeoutSec: val,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // OLED Screen Orientation Card
                      Material(
                        color: AppTheme.card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: AppTheme.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [

                            // Screen Orientation (0° vs 180° for Left/Right wrist)
                            Material(
                              type: MaterialType.transparency,
                              child: SwitchListTile(
                                value: display.orientationFlipped,
                                onChanged: (val) {
                                  repository.updateDisplaySettings(
                                    display.copyWith(orientationFlipped: val),
                                  );
                                },
                                title: const Text(
                                  'Rotate Screen 180°',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  display.orientationFlipped
                                      ? 'Left-wrist orientation (Buttons pointing right)'
                                      : 'Right-wrist orientation (Standard 0°)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                secondary: const Icon(
                                  Icons.screen_rotation_rounded,
                                  color: AppTheme.textSecondary,
                                  size: 20,
                                ),
                                activeThumbColor: AppTheme.cyan,
                                activeTrackColor: AppTheme.primaryBlueLight
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            const Divider(height: 1),

                            // 24-Hour Time Format
                            Material(
                              type: MaterialType.transparency,
                              child: SwitchListTile(
                                value: display.use24HourTime,
                                onChanged: (val) {
                                  repository.updateDisplaySettings(
                                    display.copyWith(use24HourTime: val),
                                  );
                                },
                                title: const Text(
                                  '24-Hour Clock',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  display.use24HourTime
                                      ? 'Display time as 14:30 on OLED clock'
                                      : 'Display time as 02:30 PM on OLED clock',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                secondary: const Icon(
                                  Icons.schedule_rounded,
                                  color: AppTheme.textSecondary,
                                  size: 20,
                                ),
                                activeThumbColor: AppTheme.cyan,
                                activeTrackColor: AppTheme.primaryBlueLight
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // OLED specs note
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.borderSubtle),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: AppTheme.cyan,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Hardware: 0.96-inch monochrome I2C OLED display (128x64 px). Display configuration syncs over BLE to ESP32 settings storage.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
