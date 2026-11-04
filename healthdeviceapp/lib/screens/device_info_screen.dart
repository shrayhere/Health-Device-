import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../repositories/health_repository.dart';
import '../theme/app_theme.dart';
import 'alarms_screen.dart';
import 'reminders_screen.dart';

/// Screen F1: Device Info screen.
/// Displays hardware capsule visual, Device options (Device Name, Alarms, Reminders,
/// LED, Notifications, Wi-Fi), firmware spec rows, and disconnect button.
class DeviceInfoScreen extends StatelessWidget {
  final HealthRepository repository;

  const DeviceInfoScreen({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return ValueListenableBuilder<ConnectionStatus>(
      valueListenable: repository.connectionStatus,
      builder: (context, connection, _) {
        return ValueListenableBuilder<DeviceInfo>(
          valueListenable: repository.deviceInfo,
          builder: (context, info, _) {
            return ValueListenableBuilder<BatteryData>(
              valueListenable: repository.battery,
              builder: (context, battery, _) {
                final isConnected = connection.isConnected;

                return Scaffold(
                  backgroundColor: AppTheme.background,
                  appBar: AppBar(
                    leading: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    title: const Text(
                      'Device',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
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
                            children: [
                              // Device Graphic & Status Card
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.card,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 24,
                                ),
                                child: Row(
                                  children: [
                                    // Device Capsule illustration
                                    Container(
                                      width: 48,
                                      height: 74,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                          color: AppTheme.cyan.withValues(
                                            alpha: 0.6,
                                          ),
                                          width: 2.0,
                                        ),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: AppTheme.cyan.withValues(
                                              alpha: 0.2,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: Icon(
                                              Icons.circle,
                                              size: 6,
                                              color: AppTheme.cyan,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isConnected
                                              ? info.name
                                              : 'No Device Connected',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isConnected
                                              ? info.firmwareVersion
                                              : 'Unavailable',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Container(
                                              width: 7,
                                              height: 7,
                                              decoration: BoxDecoration(
                                                color: isConnected
                                                    ? AppTheme.goodPostureGreen
                                                    : AppTheme.textMuted,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              connection.stateLabel,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: isConnected
                                                    ? AppTheme.goodPostureGreen
                                                    : AppTheme.textMuted,
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Icon(
                                              Icons.battery_5_bar_rounded,
                                              size: 15,
                                              color: battery.isAvailable
                                                  ? AppTheme.cyan
                                                  : AppTheme.textMuted,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              battery.isAvailable
                                                  ? '${battery.percentage}%'
                                                  : 'Unavailable',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: battery.isAvailable
                                                    ? AppTheme.textSecondary
                                                    : AppTheme.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Device Navigation & Specs List Card
                              Material(
                                color: AppTheme.card,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  side: const BorderSide(
                                    color: AppTheme.border,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: [
                                    // 1. Device Name (Fix Screenshot Bug: stays on ONE LINE with ellipsis, never character-split)
                                    InkWell(
                                      onTap: () => _showEditNameDialog(
                                        context,
                                        info.name,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 14,
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.devices_rounded,
                                              size: 20,
                                              color: AppTheme.textSecondary,
                                            ),
                                            const SizedBox(width: 14),
                                            const Text(
                                              'Device Name',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                info.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.end,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.cyan,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.surface,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: AppTheme.borderSubtle,
                                                ),
                                              ),
                                              child: const Text(
                                                'Edit',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      AppTheme.primaryBlueLight,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const Divider(height: 1),

                                    // 2. Alarms
                                    ListTile(
                                      leading: const Icon(
                                        Icons.alarm_rounded,
                                        size: 20,
                                        color: AppTheme.textSecondary,
                                      ),
                                      title: const Text(
                                        'Alarms',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 20,
                                        color: AppTheme.textMuted,
                                      ),
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (ctx) => AlarmsScreen(
                                              repository: repository,
                                            ),
                                          ),
                                        );
                                      },
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 18,
                                          ),
                                    ),
                                    const Divider(height: 1),

                                    // 3. Reminders
                                    ListTile(
                                      leading: const Icon(
                                        Icons.access_time_rounded,
                                        size: 20,
                                        color: AppTheme.textSecondary,
                                      ),
                                      title: const Text(
                                        'Reminders',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 20,
                                        color: AppTheme.textMuted,
                                      ),
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (ctx) => RemindersScreen(
                                              repository: repository,
                                            ),
                                          ),
                                        );
                                      },
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 18,
                                          ),
                                    ),
                                    const Divider(height: 1),

                                    // Firmware Version
                                    ListTile(
                                      leading: const Icon(
                                        Icons.memory_rounded,
                                        size: 20,
                                        color: AppTheme.textSecondary,
                                      ),
                                      title: const Text(
                                        'Firmware Version',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      trailing: Text(
                                        info.firmwareVersion,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 18,
                                          ),
                                    ),
                                    const Divider(height: 1),

                                    // Bluetooth
                                    ListTile(
                                      leading: const Icon(
                                        Icons.bluetooth_rounded,
                                        size: 20,
                                        color: AppTheme.textSecondary,
                                      ),
                                      title: const Text(
                                        'Bluetooth',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      trailing: Text(
                                        connection.stateLabel,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isConnected
                                              ? AppTheme.cyan
                                              : AppTheme.textMuted,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 18,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Disconnect Action Row (Screen F1)
                              Material(
                                color: AppTheme.card,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(
                                    color: AppTheme.border,
                                  ),
                                ),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.link_off_rounded,
                                    size: 20,
                                    color: AppTheme.alarmRed,
                                  ),
                                  title: Text(
                                    isConnected ? 'Disconnect' : 'Connect',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.alarmRed,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: AppTheme.alarmRed,
                                  ),
                                  onTap: () {
                                    if (isConnected) {
                                      repository.disconnect();
                                    } else {
                                      repository.connect();
                                    }
                                  },
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
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
          },
        );
      },
    );
  }

  void _showEditNameDialog(BuildContext context, String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppTheme.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit Device Name',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Set the custom Bluetooth identifier broadcasted by your HealthDevice.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Device Name',
                      labelStyle: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      filled: true,
                      fillColor: AppTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.borderSubtle,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.borderSubtle,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryBlueLight,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            final newName = controller.text.trim();
                            if (newName.isNotEmpty) {
                              repository.updateDeviceName(newName);
                            }
                            Navigator.of(ctx).pop();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlueLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
