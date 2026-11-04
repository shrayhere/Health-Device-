import 'package:flutter/material.dart';

import '../repositories/health_repository.dart';
import '../theme/app_theme.dart';
import 'about_screen.dart';
import 'button_guide_screen.dart';
import 'device_info_screen.dart';
import 'display_settings_screen.dart';
import 'led_settings_screen.dart';
import 'notifications_screen.dart';
import 'sound_settings_screen.dart';
import 'wifi_settings_screen.dart';

/// Screen: Dedicated Hardware Device Settings for the ESP32-C3.
///
/// Contains strictly hardware/firmware configurations:
/// Device, Sound, Display, LED, Notifications, Wi-Fi, Button Guide, About.
class DeviceSettingsScreen extends StatelessWidget {
  final HealthRepository repository;

  const DeviceSettingsScreen({super.key, required this.repository});

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
          'Device Settings',
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
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hardware synchronization notice
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.bluetooth_connected_rounded,
                          size: 18,
                          color: AppTheme.cyan,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Connected to HealthDevice over BLE. Changes to Sound, Display, LED, Alarms, and Wi-Fi are synchronized directly with your device in real-time.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Hardware Controls Group
                  Material(
                    color: AppTheme.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // 1. Device Info
                        _buildSettingTile(
                          context,
                          icon: Icons.developer_board_rounded,
                          title: 'Device',
                          subtitle:
                              'Firmware, serial number & calibration status',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) =>
                                    DeviceInfoScreen(repository: repository),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),

                        // 2. Sound & Audio
                        _buildSettingTile(
                          context,
                          icon: Icons.volume_up_rounded,
                          title: 'Sound',
                          subtitle: 'Volume, DND schedule & measurement alerts',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) =>
                                    SoundSettingsScreen(repository: repository),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),

                        // 3. Display & OLED
                        _buildSettingTile(
                          context,
                          icon: Icons.tv_rounded,
                          title: 'Display',
                          subtitle:
                              'Sleep timeout & screen rotation',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => DisplaySettingsScreen(
                                  repository: repository,
                                ),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),

                        // 4. LED Indicator
                        _buildSettingTile(
                          context,
                          icon: Icons.light_mode_rounded,
                          title: 'LED',
                          subtitle:
                              'Hardware RGB status diode power on/off',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) =>
                                    LedSettingsScreen(repository: repository),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),

                        // 5. Notifications
                        _buildSettingTile(
                          context,
                          icon: Icons.notifications_active_rounded,
                          title: 'Notifications',
                          subtitle:
                              'Heart rate alarms, SpO₂ drops & posture buzzers',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) =>
                                    NotificationsScreen(repository: repository),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),

                        // 6. Wi-Fi
                        _buildSettingTile(
                          context,
                          icon: Icons.wifi_rounded,
                          title: 'Wi-Fi',
                          subtitle: 'Configure 2.4 GHz credentials for telemetry upload',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) =>
                                    WiFiSettingsScreen(repository: repository),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Documentation & Info Group
                  const Text(
                    'Reference & System',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
                        // Button Guide
                        _buildSettingTile(
                          context,
                          icon: Icons.touch_app_rounded,
                          title: 'Button Guide',
                          subtitle: 'Gestures and actions for hardware tactile button',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => const ButtonGuideScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),

                        // About
                        _buildSettingTile(
                          context,
                          icon: Icons.info_outline_rounded,
                          title: 'About',
                          subtitle: 'ESP32-C3 architecture, sensors & licenses',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) =>
                                    AboutScreen(repository: repository),
                              ),
                            );
                          },
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
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: Icon(icon, size: 22, color: AppTheme.cyan),
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
        trailing: const Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: AppTheme.textMuted,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        onTap: onTap,
      ),
    );
  }
}
