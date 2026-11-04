import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../theme/app_theme.dart';

/// Top header banner displaying HealthDevice connection state, battery level,
/// and fast sync action.
class ConnectionStatusHeader extends StatelessWidget {
  final ConnectionStatus connection;
  final BatteryData battery;
  final VoidCallback onSyncPressed;
  final VoidCallback onDeviceTap;

  const ConnectionStatusHeader({
    super.key,
    required this.connection,
    required this.battery,
    required this.onSyncPressed,
    required this.onDeviceTap,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = connection.isConnected;
    final isConnecting = connection.isConnecting;

    final statusColor = isConnected
        ? AppTheme.statusGreen
        : (isConnecting ? AppTheme.statusOrange : AppTheme.textMuted);

    return InkWell(
      onTap: onDeviceTap,
      borderRadius: BorderRadius.circular(16),
      hoverColor: AppTheme.cardHover,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isConnected
                ? AppTheme.border
                : AppTheme.statusOrange.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            // Status Icon Container
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isConnected
                    ? Icons.bluetooth_connected_rounded
                    : (isConnecting
                          ? Icons.bluetooth_searching_rounded
                          : Icons.bluetooth_disabled_rounded),
                size: 20,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 14),

            // Device Name and Connection Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          connection.deviceName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Small status badge
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        connection.stateLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: statusColor,
                        ),
                      ),
                      if (connection.lastSyncTime != null && isConnected) ...[
                        const Text(
                          ' • ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            _formatLastSync(connection.lastSyncTime!),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Battery telemetry
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.borderSubtle, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    battery.isCharging
                        ? Icons.battery_charging_full_rounded
                        : _batteryIcon(battery.percentage),
                    size: 16,
                    color: !battery.isAvailable
                        ? AppTheme.textMuted
                        : (battery.isLow
                              ? AppTheme.statusOrange
                              : (battery.isCharging
                                    ? AppTheme.statusGreen
                                    : AppTheme.textSecondary)),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    battery.isAvailable ? '${battery.percentage}%' : '--',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: battery.isAvailable
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Quick sync action
            IconButton(
              onPressed: onSyncPressed,
              tooltip: 'Sync with HealthDevice',
              icon: const Icon(
                Icons.sync_rounded,
                size: 20,
                color: AppTheme.primaryBlueLight,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  IconData _batteryIcon(int level) {
    if (level >= 85) return Icons.battery_full_rounded;
    if (level >= 60) return Icons.battery_6_bar_rounded;
    if (level >= 40) return Icons.battery_4_bar_rounded;
    if (level >= 20) return Icons.battery_2_bar_rounded;
    return Icons.battery_alert_rounded;
  }

  String _formatLastSync(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
