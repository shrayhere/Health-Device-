import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../repositories/health_repository.dart';
import '../theme/app_theme.dart';

/// Screen for managing individual notification toggles (Settings -> Notifications).
/// Provides dedicated ON/OFF switches for Alarm, Reminder, Heart Rate alert, SpO2 alert,
/// Bad Posture, Fall Detection, Low Battery, Timer, and Device/Connection.
class NotificationsScreen extends StatelessWidget {
  final HealthRepository repository;

  const NotificationsScreen({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return ValueListenableBuilder<NotificationConfig>(
      valueListenable: repository.notificationConfig,
      builder: (context, config, _) {
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Notification Settings',
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
                      const Text(
                        'Device & Health Alerts',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Material(
                        color: AppTheme.card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: AppTheme.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            _buildToggleTile(
                              icon: Icons.alarm_rounded,
                              iconColor: AppTheme.alarmRed,
                              title: 'Alarm',
                              subtitle:
                                  'High-priority wake-up and schedule triggers',
                              value: config.alarm,
                              onChanged: (val) =>
                                  repository.updateNotificationConfig(
                                    config.copyWith(alarm: val),
                                  ),
                            ),
                            const Divider(height: 1),
                            _buildToggleTile(
                              icon: Icons.access_time_rounded,
                              iconColor: AppTheme.cyan,
                              title: 'Reminder',
                              subtitle:
                                  'Scheduled hydration and movement alerts',
                              value: config.reminder,
                              onChanged: (val) =>
                                  repository.updateNotificationConfig(
                                    config.copyWith(reminder: val),
                                  ),
                            ),
                            const Divider(height: 1),
                            _buildToggleTile(
                              icon: Icons.favorite_rounded,
                              iconColor: AppTheme.heartRateRed,
                              title: 'Heart Rate Alert',
                              subtitle: 'Tachycardia and bradycardia threshold warnings',
                              value: config.heartRateAlert,
                              onChanged: (val) =>
                                  repository.updateNotificationConfig(
                                    config.copyWith(heartRateAlert: val),
                                  ),
                            ),
                            const Divider(height: 1),
                            _buildToggleTile(
                              icon: Icons.water_drop_rounded,
                              iconColor: AppTheme.spo2Cyan,
                              title: 'SpO₂ Alert',
                              subtitle:
                                  'Blood oxygen saturation below 90% warnings',
                              value: config.spo2Alert,
                              onChanged: (val) =>
                                  repository.updateNotificationConfig(
                                    config.copyWith(spo2Alert: val),
                                  ),
                            ),
                            const Divider(height: 1),
                            _buildToggleTile(
                              icon: Icons.accessibility_new_rounded,
                              iconColor: AppTheme.badPostureOrange,
                              title: 'Bad Posture',
                              subtitle: 'Haptic and visual warnings on prolonged slouching',
                              value: config.badPosture,
                              onChanged: (val) =>
                                  repository.updateNotificationConfig(
                                    config.copyWith(badPosture: val),
                                  ),
                            ),
                            const Divider(height: 1),
                            _buildToggleTile(
                              icon: Icons.warning_amber_rounded,
                              iconColor: Colors.amber,
                              title: 'Fall Detection',
                              subtitle: 'Immediate safety notification on sudden impact',
                              value: config.fallDetection,
                              onChanged: (val) =>
                                  repository.updateNotificationConfig(
                                    config.copyWith(fallDetection: val),
                                  ),
                            ),
                            const Divider(height: 1),
                            _buildToggleTile(
                              icon: Icons.battery_alert_rounded,
                              iconColor: Colors.orangeAccent,
                              title: 'Low Battery',
                              subtitle: 'Reminder when wearable battery falls below 20%',
                              value: config.lowBattery,
                              onChanged: (val) =>
                                  repository.updateNotificationConfig(
                                    config.copyWith(lowBattery: val),
                                  ),
                            ),
                            const Divider(height: 1),
                            _buildToggleTile(
                              icon: Icons.timer_outlined,
                              iconColor: Colors.purpleAccent,
                              title: 'Timer',
                              subtitle:
                                  'Countdown and measurement period completion',
                              value: config.timer,
                              onChanged: (val) =>
                                  repository.updateNotificationConfig(
                                    config.copyWith(timer: val),
                                  ),
                            ),
                            const Divider(height: 1),
                            _buildToggleTile(
                              icon: Icons.bluetooth_searching_rounded,
                              iconColor: AppTheme.primaryBlueLight,
                              title: 'Device / Connection',
                              subtitle: 'BLE disconnects and reconnection status toasts',
                              value: config.connection,
                              onChanged: (val) =>
                                  repository.updateNotificationConfig(
                                    config.copyWith(connection: val),
                                  ),
                            ),
                          ],
                        ),
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

  Widget _buildToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      secondary: Icon(icon, color: iconColor, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      ),
      activeThumbColor: AppTheme.primaryBlueLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
    );
  }
}
