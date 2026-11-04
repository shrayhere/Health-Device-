import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../repositories/health_repository.dart';
import '../services/ble_command_service.dart';
import '../services/ble_device_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/metric_card.dart';
import 'alarms_screen.dart';
import 'device_info_screen.dart';
import 'device_settings_screen.dart';
import 'reminders_screen.dart';

/// Screen: Device Screen specifically for the connected HealthDevice hardware.
///
/// Contains:
/// - Truthful device name & firmware info
/// - Connection status (real BLE link to ESP32-C3 via BleDeviceManager)
/// - Truthful battery percentage (shows unavailable if not provided by hardware)
/// - Alarms & Reminders
/// - Prominent Device Settings entry
class DeviceScreen extends StatefulWidget {
  final HealthRepository repository;
  final VoidCallback? onNavigateToSettings;

  const DeviceScreen({
    super.key,
    required this.repository,
    this.onNavigateToSettings,
  });

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  HealthRepository get repository => widget.repository;
  VoidCallback? get onNavigateToSettings => widget.onNavigateToSettings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ble = BleDeviceManager();
      if (!ble.isConnected &&
          !ble.isScanning.value &&
          ble.connectionState.value != BleDeviceState.connecting &&
          ble.connectionState.value != BleDeviceState.discoveringServices) {
        ble.startScan();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;
    final ble = BleDeviceManager();

    return ValueListenableBuilder<BleDeviceState>(
      valueListenable: ble.connectionState,
      builder: (context, bleState, _) {
        return ValueListenableBuilder<BatteryData>(
          valueListenable: ble.batteryData,
          builder: (context, battery, _) {
            return ValueListenableBuilder<DeviceInfo>(
              valueListenable: ble.deviceInfo,
              builder: (context, info, _) {
                return ValueListenableBuilder<String?>(
                  valueListenable: ble.firmwareStatus,
                  builder: (context, firmwareStatus, _) {
                    final isConnected = ble.isConnected;
                    final connection = ConnectionStatus(
                      state: isConnected
                          ? DeviceConnectionState.connected
                          : (bleState == BleDeviceState.connecting ||
                                    bleState ==
                                        BleDeviceState.discoveringServices
                                ? DeviceConnectionState.connecting
                                : DeviceConnectionState.disconnected),
                      deviceName:
                          ble.connectedDevice.value?.platformName.isNotEmpty ==
                              true
                          ? ble.connectedDevice.value!.platformName
                          : (isConnected
                                ? 'HealthDevice'
                                : 'No Device Connected'),
                      rssi: ble.liveRssi.value,
                      lastSyncTime: isConnected ? DateTime.now() : null,
                    );

                    return Scaffold(
                      backgroundColor: AppTheme.background,
                      body: SafeArea(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 32 : 20,
                            vertical: 20,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 860),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Header (Connection & truthful battery: shows '--' when unavailable)
                                  DeviceTopHeader(
                                    connection: connection,
                                    battery: battery,
                                    onSettingsPressed: null,
                                  ),
                                  const SizedBox(height: 16),

                                  // Real ESP32-C3 BLE Link Card (scanning, independent discovered list, status)
                                  _buildRealBleCard(context),

                                  // Device Capsule Overview Card
                                  _buildDeviceCapsuleCard(
                                    context,
                                    info,
                                    battery,
                                    isConnected: isConnected,
                                    firmwareStatus: firmwareStatus,
                                  ),
                                  const SizedBox(height: 16),

                                  // Options Card (Device Name, Alarms, Reminders, Device Settings)
                                  _buildOptionsCard(context, info),
                                  const SizedBox(height: 24),

                                  // Current Status Section
                                  const Text(
                                    'Current Status',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildCurrentStatusCard(
                                    isConnected: isConnected,
                                    firmwareStatus: firmwareStatus,
                                  ),
                                  const SizedBox(height: 24),

                                  // Primary Action Button: "Start Measurement"
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: FilledButton(
                                      onPressed: () async {
                                        final cmd = BleCommandService();
                                        final result = await cmd
                                            .triggerMeasurement();
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(result.message),
                                            backgroundColor: result.isSuccessful
                                                ? AppTheme.statusGreen
                                                : (result.state ==
                                                          BleCommandSyncState
                                                              .unsupported
                                                      ? AppTheme.surface
                                                      : AppTheme.alarmRed),
                                            behavior: SnackBarBehavior.floating,
                                            duration: const Duration(
                                              seconds: 4,
                                            ),
                                          ),
                                        );
                                      },
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            AppTheme.primaryBlueLight,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Start Measurement',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
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
      },
    );
  }

  /// Real ESP32-C3 BLE link card reflecting physical connection, scanning,
  /// and received status characteristic messages.
  Widget _buildRealBleCard(BuildContext context) {
    final ble = BleDeviceManager();

    return ValueListenableBuilder<BleDeviceState>(
      valueListenable: ble.connectionState,
      builder: (context, state, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: ble.firmwareStatus,
          builder: (context, statusMsg, _) {
            final isConnected = state == BleDeviceState.connected;
            final isConnecting =
                state == BleDeviceState.connecting ||
                state == BleDeviceState.discoveringServices;

            Color badgeColor;
            String stateLabel;
            switch (state) {
              case BleDeviceState.connected:
                badgeColor = AppTheme.goodPostureGreen;
                stateLabel = 'Connected (ESP32-C3)';
                break;
              case BleDeviceState.connecting:
              case BleDeviceState.discoveringServices:
                badgeColor = AppTheme.cyan;
                stateLabel = 'Connecting...';
                break;
              case BleDeviceState.scanning:
                badgeColor = AppTheme.badPostureOrange;
                stateLabel = 'Scanning for HealthDevice...';
                break;
              case BleDeviceState.bluetoothDisabled:
                badgeColor = AppTheme.heartRateRed;
                stateLabel = 'Bluetooth Disabled';
                break;
              case BleDeviceState.unsupported:
                badgeColor = AppTheme.heartRateRed;
                stateLabel = 'BLE Unsupported';
                break;
              case BleDeviceState.connectionFailed:
                badgeColor = AppTheme.heartRateRed;
                stateLabel = 'Connection Failed';
                break;
              case BleDeviceState.disconnected:
                badgeColor = AppTheme.textMuted;
                stateLabel = 'Not Connected';
                break;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isConnected
                      ? AppTheme.cyan.withValues(alpha: 0.4)
                      : AppTheme.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.bluetooth_rounded,
                              size: 20,
                              color: isConnected
                                  ? AppTheme.cyan
                                  : AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            const Flexible(
                              child: Text(
                                'ESP32-C3 Link',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: badgeColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: badgeColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              stateLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: badgeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (statusMsg != null && statusMsg.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Text(
                        'Firmware Status: "$statusMsg"',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.cyan,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  ValueListenableBuilder<bool>(
                    valueListenable: ble.isScanning,
                    builder: (context, scanning, _) {
                      if (!isConnected) {
                        return SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: scanning || isConnecting
                                ? () => ble.stopScan()
                                : () => ble.startScan(),
                            icon: Icon(
                              scanning
                                  ? Icons.stop_rounded
                                  : Icons.search_rounded,
                              size: 16,
                            ),
                            label: Text(
                              scanning
                                  ? 'Stop Scan'
                                  : isConnecting
                                  ? 'Connecting...'
                                  : 'Scan for HealthDevice',
                              style: const TextStyle(fontSize: 13),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlueLight,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        );
                      } else {
                        return Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: scanning
                                    ? () => ble.stopScan()
                                    : () => ble.startScan(),
                                icon: Icon(
                                  scanning
                                      ? Icons.stop_rounded
                                      : Icons.search_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  scanning ? 'Stop Scan' : 'Scan Nearby',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: AppTheme.border,
                                  ),
                                  foregroundColor: AppTheme.cyan,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => ble.disconnect(),
                                icon: const Icon(
                                  Icons.bluetooth_disabled_rounded,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Disconnect',
                                  style: TextStyle(fontSize: 13),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: AppTheme.heartRateRed,
                                  ),
                                  foregroundColor: AppTheme.heartRateRed,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),

                  // Discovered devices list: persists across connection and only displays HealthDevice
                  ValueListenableBuilder<List<DiscoveredBleDevice>>(
                    valueListenable: ble.discoveredDevices,
                    builder: (context, devices, _) {
                      return ValueListenableBuilder<bool>(
                        valueListenable: ble.isScanning,
                        builder: (context, scanning, _) {
                          if (devices.isEmpty) {
                            if (scanning) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 14),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.cyan,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Searching for HealthDevice (ESP32-C3)...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.cyan,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Main HealthDevice:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                  if (!scanning)
                                    InkWell(
                                      onTap: () => ble.clearScannedDevices(),
                                      child: const Text(
                                        'Clear',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ...devices.map((d) {
                                final isThisConnected =
                                    isConnected &&
                                    ble.connectedDevice.value?.remoteId.str ==
                                        d.remoteId;

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isThisConnected
                                        ? AppTheme.cyan.withValues(alpha: 0.08)
                                        : AppTheme.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isThisConnected
                                          ? AppTheme.cyan.withValues(alpha: 0.4)
                                          : AppTheme.borderSubtle,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isThisConnected
                                            ? Icons.bluetooth_connected_rounded
                                            : Icons.bluetooth_rounded,
                                        size: 18,
                                        color: isThisConnected
                                            ? AppTheme.goodPostureGreen
                                            : AppTheme.cyan,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    d.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: isThisConnected
                                                          ? AppTheme
                                                                .goodPostureGreen
                                                          : AppTheme.cyan,
                                                    ),
                                                  ),
                                                ),
                                                if (isThisConnected) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 1.5,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme
                                                          .goodPostureGreen
                                                          .withValues(
                                                            alpha: 0.15,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                      border: Border.all(
                                                        color: AppTheme
                                                            .goodPostureGreen
                                                            .withValues(
                                                              alpha: 0.4,
                                                            ),
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      'Connected',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: AppTheme
                                                            .goodPostureGreen,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'RSSI: ${d.rssi} dBm • ID: ${d.remoteId}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (isThisConnected)
                                        TextButton(
                                          onPressed: () => ble.disconnect(),
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                AppTheme.heartRateRed,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                            ),
                                            minimumSize: const Size(60, 32),
                                          ),
                                          child: const Text(
                                            'Disconnect',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        )
                                      else
                                        FilledButton(
                                          onPressed: () =>
                                              ble.connectToDevice(d.device),
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                                AppTheme.primaryBlueLight,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            minimumSize: const Size(64, 32),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text(
                                            'Connect',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDeviceCapsuleCard(
    BuildContext context,
    DeviceInfo info,
    BatteryData battery, {
    required bool isConnected,
    required String? firmwareStatus,
  }) {
    final displayName = isConnected
        ? (info.name.isNotEmpty ? info.name : 'HealthDevice')
        : 'No Device Connected';
    final displayFirmware = isConnected
        ? (firmwareStatus ?? 'HealthDevice Connected')
        : 'Disconnected';

    return Material(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => DeviceInfoScreen(repository: repository),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              // Pill Device visual
              Container(
                width: 32,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isConnected
                        ? AppTheme.cyan.withValues(alpha: 0.6)
                        : AppTheme.textMuted.withValues(alpha: 0.3),
                    width: 1.8,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isConnected
                          ? AppTheme.cyan.withValues(alpha: 0.3)
                          : AppTheme.textMuted.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayFirmware,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
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
                              : 'Battery unavailable',
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
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsCard(BuildContext context, DeviceInfo info) {
    return Material(
      color: AppTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 1. Device Name (Protected from character-split with Expanded and ellipsis)
          InkWell(
            onTap: () => _showEditNameDialog(context, info.name),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
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
                      color: AppTheme.textPrimary,
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
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppTheme.textMuted,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // 2. Alarms
          Material(
            type: MaterialType.transparency,
            child: ValueListenableBuilder<List<AlarmItem>>(
              valueListenable: repository.alarms,
              builder: (context, alarms, _) {
                final activeCount = alarms.where((a) => a.enabled).length;
                return ListTile(
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (alarms.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: Text(
                            '$activeCount active',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.cyan,
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppTheme.textMuted,
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => AlarmsScreen(repository: repository),
                      ),
                    );
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                );
              },
            ),
          ),
          const Divider(height: 1),

          // 3. Reminders
          Material(
            type: MaterialType.transparency,
            child: ValueListenableBuilder<List<ReminderItem>>(
              valueListenable: repository.reminders,
              builder: (context, reminders, _) {
                final activeCount = reminders.where((r) => r.enabled).length;
                return ListTile(
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
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (reminders.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.borderSubtle),
                          ),
                          child: Text(
                            '$activeCount active',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.cyan,
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppTheme.textMuted,
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => RemindersScreen(repository: repository),
                      ),
                    );
                  },
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                );
              },
            ),
          ),
          const Divider(height: 1),

          // 4. Device Settings Entry
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              leading: const Icon(
                Icons.tune_rounded,
                size: 20,
                color: AppTheme.cyan,
              ),
              title: const Text(
                'Device Settings',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              subtitle: const Text(
                'Sound, Display, LED, Wi-Fi, Notifications & About',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.textMuted,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) =>
                        DeviceSettingsScreen(repository: repository),
                  ),
                );
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStatusCard({
    required bool isConnected,
    required String? firmwareStatus,
  }) {
    return ValueListenableBuilder<HeartRateData>(
      valueListenable: repository.heartRate,
      builder: (context, hr, _) {
        return ValueListenableBuilder<Spo2Data>(
          valueListenable: repository.spo2,
          builder: (context, spo2, _) {
            return ValueListenableBuilder<PostureData>(
              valueListenable: repository.posture,
              builder: (context, posture, _) {
                return ValueListenableBuilder<ActivityData>(
                  valueListenable: repository.activity,
                  builder: (context, activity, _) {
                    final hrVal = isConnected || hr.currentBpm > 0
                        ? '${hr.currentBpm} BPM'
                        : '--';
                    final spo2Val = isConnected || spo2.percentage > 0
                        ? '${spo2.percentage}%'
                        : '--';
                    final postureVal = isConnected || posture.postureScoreToday > 0
                        ? '${posture.classificationLabel} (${posture.postureScoreToday}%)'
                        : '--';
                    final stepsVal = '${activity.steps} steps';

                    return Material(
                      color: AppTheme.card,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: AppTheme.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            color: AppTheme.surface,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 15,
                                  color: AppTheme.cyan,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isConnected
                                        ? 'Firmware status: "${firmwareStatus ?? "HealthDevice Connected"}". Real-time hardware telemetry is synchronized.'
                                        : 'Connect to HealthDevice via BLE to view hardware link and live status.',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          _buildStatusRow(
                            icon: Icons.favorite_rounded,
                            iconColor: AppTheme.heartRateRed,
                            title: 'Heart Rate',
                            value: hrVal,
                            valueColor: hrVal != '--' ? AppTheme.heartRateRed : AppTheme.textSecondary,
                          ),
                          const Divider(height: 1),
                          _buildStatusRow(
                            icon: Icons.water_drop_rounded,
                            iconColor: AppTheme.spo2Cyan,
                            title: 'SpO₂',
                            value: spo2Val,
                            valueColor: spo2Val != '--' ? AppTheme.spo2Cyan : AppTheme.textSecondary,
                          ),
                          const Divider(height: 1),
                          _buildStatusRow(
                            icon: Icons.accessibility_new_rounded,
                            iconColor: AppTheme.goodPostureGreen,
                            title: 'Posture',
                            value: postureVal,
                            valueColor: postureVal != '--' ? AppTheme.goodPostureGreen : AppTheme.textSecondary,
                          ),
                          const Divider(height: 1),
                          _buildStatusRow(
                            icon: Icons.directions_run_rounded,
                            iconColor: AppTheme.cyan,
                            title: 'Steps',
                            value: stepsVal,
                            valueColor: AppTheme.cyan,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    Color valueColor = AppTheme.textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
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
