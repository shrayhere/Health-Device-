import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../repositories/health_repository.dart';
import '../theme/app_theme.dart';

/// Screen: Hardware Audio & Haptics settings for HealthDevice.
class SoundSettingsScreen extends StatelessWidget {
  final HealthRepository repository;

  const SoundSettingsScreen({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return ValueListenableBuilder<SoundSettings>(
      valueListenable: repository.soundSettings,
      builder: (context, sound, _) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Sound & Haptics',
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
                      // Overview Card
                      Material(
                        color: AppTheme.card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: AppTheme.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            // 1. Master Sound Toggle
                            SwitchListTile(
                              value: sound.soundEnabled,
                              onChanged: (val) {
                                repository.updateSoundSettings(
                                  sound.copyWith(soundEnabled: val),
                                );
                              },
                              title: const Text(
                                'Device Sound',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              subtitle: const Text(
                                'Master audio switch for piezo buzzer feedback.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              secondary: const Icon(
                                Icons.volume_up_rounded,
                                color: AppTheme.cyan,
                              ),
                              activeThumbColor: AppTheme.cyan,
                              activeTrackColor: AppTheme.primaryBlueLight
                                  .withValues(alpha: 0.5),
                            ),
                            const Divider(height: 1),

                            // 2. Volume Slider
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Sound Volume',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '${sound.volumePct}%',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.cyan,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor:
                                          AppTheme.primaryBlueLight,
                                      inactiveTrackColor: AppTheme.surface,
                                      thumbColor: AppTheme.cyan,
                                      overlayColor: AppTheme.cyan.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                    child: Slider(
                                      value: sound.volumePct.toDouble(),
                                      min: 0,
                                      max: 100,
                                      divisions: 20,
                                      onChanged: sound.soundEnabled
                                          ? (val) {
                                              repository.updateSoundSettings(
                                                sound.copyWith(
                                                  volumePct: val.round(),
                                                ),
                                              );
                                            }
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Mode & Feedback Settings Card
                      Material(
                        color: AppTheme.card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: AppTheme.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            // 3. Do Not Disturb (DND)
                            SwitchListTile(
                              value: sound.dndEnabled,
                              onChanged: (val) {
                                repository.updateSoundSettings(
                                  sound.copyWith(dndEnabled: val),
                                );
                              },
                              title: const Text(
                                'Do Not Disturb',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              subtitle: const Text(
                                'Suppresses non-critical reminders. Safety alerts & alarms remain active.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              secondary: const Icon(
                                Icons.do_not_disturb_on_rounded,
                                color: AppTheme.textSecondary,
                              ),
                              activeThumbColor: AppTheme.cyan,
                              activeTrackColor: AppTheme.primaryBlueLight
                                  .withValues(alpha: 0.5),
                            ),
                            const Divider(height: 1),

                            // 4. Button / Click Sound
                            SwitchListTile(
                              value: sound.clickSoundEnabled,
                              onChanged: sound.soundEnabled
                                  ? (val) {
                                      repository.updateSoundSettings(
                                        sound.copyWith(clickSoundEnabled: val),
                                      );
                                    }
                                  : null,
                              title: const Text(
                                'Button Click Sound',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              subtitle: const Text(
                                'Soft audio chirp when pressing the physical hardware button.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              secondary: const Icon(
                                Icons.touch_app_rounded,
                                color: AppTheme.textSecondary,
                              ),
                              activeThumbColor: AppTheme.cyan,
                              activeTrackColor: AppTheme.primaryBlueLight
                                  .withValues(alpha: 0.5),
                            ),
                            const Divider(height: 1),

                            // 5. Measurement Sound
                            SwitchListTile(
                              value: sound.measurementSoundEnabled,
                              onChanged: sound.soundEnabled
                                  ? (val) {
                                      repository.updateSoundSettings(
                                        sound.copyWith(
                                          measurementSoundEnabled: val,
                                        ),
                                      );
                                    }
                                  : null,
                              title: const Text(
                                'Measurement Feedback',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              subtitle: const Text(
                                'Beep when optical Heart Rate & SpO₂ scans start and complete.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              secondary: const Icon(
                                Icons.favorite_border_rounded,
                                color: AppTheme.textSecondary,
                              ),
                              activeThumbColor: AppTheme.cyan,
                              activeTrackColor: AppTheme.primaryBlueLight
                                  .withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ESP32 Sync note
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
                                'Sound configurations automatically persist locally and sync to the ESP32 hardware via BLE.',
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
