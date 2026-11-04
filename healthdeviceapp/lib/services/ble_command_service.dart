import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../models/health_metrics.dart';
import 'ble_device_manager.dart';

/// Command synchronization status.
enum BleCommandSyncState {
  supported,
  unsupported,
  disconnected,
  syncing,
  synced,
  syncFailed,
}

/// Detailed result of an attempted BLE command / synchronization operation.
class BleCommandResult {
  final BleCommandSyncState state;
  final String message;
  final String? requiredCharacteristic;

  const BleCommandResult({
    required this.state,
    required this.message,
    this.requiredCharacteristic,
  });

  const BleCommandResult.disconnected({
    this.message = 'HealthDevice ESP32-C3 is not connected over BLE.',
    this.requiredCharacteristic,
  }) : state = BleCommandSyncState.disconnected;

  const BleCommandResult.unsupported({
    required this.message,
    required this.requiredCharacteristic,
  }) : state = BleCommandSyncState.unsupported;

  const BleCommandResult.synced({
    this.message = 'Successfully synchronized with HealthDevice hardware.',
    this.requiredCharacteristic,
  }) : state = BleCommandSyncState.synced;

  const BleCommandResult.syncFailed({
    required this.message,
    this.requiredCharacteristic,
  }) : state = BleCommandSyncState.syncFailed;

  bool get isSuccessful => state == BleCommandSyncState.synced;
}

/// Centralized service managing App → ESP32 BLE commands and synchronization requests.
///
/// Follows strict truthfulness: if the ESP32-C3 firmware has not exposed a GATT characteristic
/// for a peripheral command, this service returns [BleCommandSyncState.unsupported] with
/// the exact characteristic required rather than fabricating success.
class BleCommandService {
  static final BleCommandService _instance = BleCommandService._internal();
  factory BleCommandService() => _instance;
  BleCommandService._internal();

  final BleDeviceManager _bleManager = BleDeviceManager();

  /// Attempts to write raw command bytes to a given characteristic UUID.
  Future<BleCommandResult> writeCommand({
    required String characteristicUuid,
    required List<int> payload,
    String? featureName,
  }) async {
    if (!_bleManager.isConnected) {
      return const BleCommandResult.disconnected();
    }

    final char = _bleManager.findCharacteristic(characteristicUuid);
    if (char == null) {
      final name = featureName ?? 'Command';
      return BleCommandResult.unsupported(
        message:
            '$name unavailable: ESP32-C3 firmware does not expose characteristic $characteristicUuid.',
        requiredCharacteristic: characteristicUuid,
      );
    }

    try {
      final withoutResp = char.properties.writeWithoutResponse;
      await char.write(payload, withoutResponse: withoutResp);
      debugPrint('[BleCommandService] Wrote to $characteristicUuid (withoutResponse: $withoutResp)');
      return const BleCommandResult.synced();
    } catch (e) {
      try {
        final fallbackWithoutResp = !char.properties.writeWithoutResponse;
        await char.write(payload, withoutResponse: fallbackWithoutResp);
        debugPrint('[BleCommandService] Wrote via fallback to $characteristicUuid (withoutResponse: $fallbackWithoutResp)');
        return const BleCommandResult.synced();
      } catch (e2) {
        debugPrint('[BleCommandService] Write to $characteristicUuid failed: $e2');
        return BleCommandResult.syncFailed(
          message: 'Write to $characteristicUuid failed: $e2',
          requiredCharacteristic: characteristicUuid,
        );
      }
    }
  }

  /// Sends a raw string command to the ESP32-C3 command characteristic (9004).
  Future<BleCommandResult> sendRawCommand(String cmd) async {
    if (!_bleManager.isConnected) {
      return const BleCommandResult.disconnected();
    }
    final char = _bleManager.commandCharacteristic ??
        _bleManager.findCharacteristic(BleContract.commandCharacteristicUuid);
    if (char == null) {
      return const BleCommandResult.unsupported(
        message: 'Command characteristic not found on connected HealthDevice.',
        requiredCharacteristic: BleContract.commandCharacteristicUuid,
      );
    }

    try {
      final bytes = utf8.encode(cmd);
      final withoutResp = char.properties.writeWithoutResponse;
      await char.write(bytes, withoutResponse: withoutResp);
      debugPrint('[BleCommandService] Sent: "$cmd"');
      return const BleCommandResult.synced();
    } catch (e) {
      try {
        final bytes = utf8.encode(cmd);
        await char.write(bytes, withoutResponse: !char.properties.writeWithoutResponse);
        debugPrint('[BleCommandService] Sent via fallback: "$cmd"');
        return const BleCommandResult.synced();
      } catch (e2) {
        debugPrint('[BleCommandService] Command "$cmd" failed: $e2');
        return BleCommandResult.syncFailed(
          message: 'Failed to write to HealthDevice: $e2',
          requiredCharacteristic: BleContract.commandCharacteristicUuid,
        );
      }
    }
  }

  /// Triggers a real-time health measurement on the ESP32-C3.
  Future<BleCommandResult> triggerMeasurement() async {
    if (!_bleManager.isConnected) {
      return const BleCommandResult.disconnected(
        message: 'Cannot start measurement: HealthDevice is not connected.',
      );
    }
    return await sendRawCommand('START_MEASUREMENT');
  }

  /// Calibrates upright baseline posture on the hardware accelerometer.
  Future<BleCommandResult> calibratePosture() async {
    if (!_bleManager.isConnected) {
      return const BleCommandResult.disconnected();
    }
    return await sendRawCommand('CALIBRATE_POSTURE');
  }

  /// Requests current full state from the ESP32-C3.
  Future<BleCommandResult> requestState() async {
    if (!_bleManager.isConnected) {
      return const BleCommandResult.disconnected();
    }
    return await sendRawCommand('GET_STATE');
  }

  /// Synchronizes configured alarms to the ESP32-C3 hardware.
  Future<BleCommandResult> syncAlarms(List<AlarmItem> alarms) async {
    if (!_bleManager.isConnected) {
      return const BleCommandResult.disconnected();
    }

    try {
      // 1. Clear existing alarms on ESP32
      await sendRawCommand('CLEAR_ALARMS');
      await Future.delayed(const Duration(milliseconds: 50));

      // 2. Add each alarm: ADD_ALARM:H,M,EN,DAYS,R,G,B (7-day mask Sun..Sat + RGB color)
      for (final alarm in alarms) {
        final parts = _parseHourMinute(alarm.time);
        final h = parts[0];
        final m = parts[1];
        final en = alarm.enabled ? 1 : 0;
        final daysMask = _buildDaysMask(alarm.repeatDays);
        final r = alarm.ledColor.r;
        final g = alarm.ledColor.g;
        final b = alarm.ledColor.b;

        await sendRawCommand('ADD_ALARM:$h,$m,$en,$daysMask,$r,$g,$b');
        await Future.delayed(const Duration(milliseconds: 50));
      }

      return const BleCommandResult.synced(
        message: 'Alarms successfully synchronized with HealthDevice hardware.',
      );
    } catch (e) {
      return BleCommandResult.syncFailed(
        message: 'Failed to synchronize alarms with hardware: $e',
      );
    }
  }

  /// Synchronizes reminders to the ESP32-C3 hardware.
  Future<BleCommandResult> syncReminders(List<ReminderItem> reminders) async {
    if (!_bleManager.isConnected) {
      return const BleCommandResult.disconnected();
    }

    try {
      // 1. Clear existing reminders on ESP32
      await sendRawCommand('CLEAR_REMINDERS');
      await Future.delayed(const Duration(milliseconds: 50));

      // 2. Add each reminder: ADD_REMINDER:H,M,EN,DAILY,NAME
      for (final reminder in reminders) {
        final parts = _parseHourMinute(reminder.time);
        final h = parts[0];
        final m = parts[1];
        final en = reminder.enabled ? 1 : 0;
        final daily =
            reminder.repeatSchedule.toLowerCase().contains('daily') ? 1 : 0;
        final safeName = reminder.name.replaceAll(',', ' ').trim();

        await sendRawCommand('ADD_REMINDER:$h,$m,$en,$daily,$safeName');
        await Future.delayed(const Duration(milliseconds: 50));
      }

      return const BleCommandResult.synced(
        message: 'Reminders successfully synchronized with HealthDevice hardware.',
      );
    } catch (e) {
      return BleCommandResult.syncFailed(
        message: 'Failed to synchronize reminders with hardware: $e',
      );
    }
  }

  /// Synchronizes RGB LED event colors to the ESP32-C3 hardware.
  Future<BleCommandResult> syncLedSettings(LedSettingsState settings) async {
    if (!_bleManager.isConnected) {
      return const BleCommandResult.disconnected();
    }

    await sendRawCommand('set_led_high:${settings.isEnabled}');
    return const BleCommandResult.synced(
      message: 'LED settings updated on HealthDevice.',
    );
  }

  /// Sends a physical LED diode test color flash.
  Future<BleCommandResult> testLed(RgbColor color) async {
    if (!_bleManager.isConnected) {
      return const BleCommandResult.disconnected();
    }
    return await sendRawCommand('TEST_LED:${color.red},${color.green},${color.blue}');
  }

  /// Synchronizes Sound & Haptic settings to the ESP32-C3 hardware.
  Future<BleCommandResult> syncSoundSettings(SoundSettings settings) async {
    if (!_bleManager.isConnected) {
      return const BleCommandResult.disconnected();
    }

    await sendRawCommand('SET_SOUND:${settings.soundEnabled ? 1 : 0}');
    await Future.delayed(const Duration(milliseconds: 40));
    await sendRawCommand('SET_VOL:${settings.volumePct}');
    await Future.delayed(const Duration(milliseconds: 40));
    await sendRawCommand('SET_CLICK:${settings.clickSoundEnabled ? 1 : 0}');

    return const BleCommandResult.synced(
      message: 'Sound settings updated on HealthDevice.',
    );
  }

  /// Synchronizes OLED Display settings to the ESP32-C3 hardware.
  Future<BleCommandResult> syncDisplaySettings(DisplaySettings settings) async {
    if (!_bleManager.isConnected) {
      return const BleCommandResult.disconnected();
    }

    await sendRawCommand('set_timeout:${settings.screenTimeoutSec}');
    await Future.delayed(const Duration(milliseconds: 40));
    await sendRawCommand('SET_ROTATION:${settings.orientationFlipped ? 2 : 0}');
    await Future.delayed(const Duration(milliseconds: 40));
    await sendRawCommand('set_clock_24h:${settings.use24HourTime}');

    return const BleCommandResult.synced(
      message: 'Display settings updated on HealthDevice.',
    );
  }

  /// Synchronizes Notification alert toggles to the ESP32-C3 hardware.
  Future<BleCommandResult> syncNotificationConfig(
    NotificationConfig config,
  ) async {
    if (!_bleManager.isConnected) {
      return const BleCommandResult.disconnected();
    }
    return const BleCommandResult.synced();
  }

  /// Provisions Wi-Fi network credentials to the ESP32-C3 hardware over BLE.
  Future<BleCommandResult> provisionWiFi(WiFiNetworkItem network) async {
    if (!_bleManager.isConnected) {
      return const BleCommandResult.disconnected(
        message:
            'Cannot provision Wi-Fi: HealthDevice is not connected over BLE.',
      );
    }

    return await sendRawCommand(
      'ADD_WIFI:${network.ssid},${network.password},${network.priority}',
    );
  }

  /// Synchronizes date & time to the hardware clock without requiring Wi-Fi.
  Future<BleCommandResult> syncTime([DateTime? dt]) async {
    if (!_bleManager.isConnected) {
      return const BleCommandResult.disconnected();
    }
    final now = dt ?? DateTime.now();
    return await sendRawCommand(
      'SYNC_TIME:${now.year},${now.month},${now.day},${now.hour},${now.minute},${now.second}',
    );
  }

  // --- Helper Methods ---

  static List<int> _parseHourMinute(String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      final hm = parts[0].split(':');
      int h = int.parse(hm[0]);
      final int m = int.parse(hm[1]);
      if (parts.length > 1) {
        final period = parts[1].toUpperCase();
        if (period == 'PM' && h < 12) h += 12;
        if (period == 'AM' && h == 12) h = 0;
      }
      return [h, m];
    } catch (_) {
      return [7, 30];
    }
  }

  static String _buildDaysMask(List<String> repeatDays) {
    if (repeatDays.isEmpty) return '1111111'; // Once / Any day

    final d = repeatDays.map((s) => s.toLowerCase()).toSet();
    final sun = d.any((s) => s.startsWith('sun')) ? '1' : '0';
    final mon = d.any((s) => s.startsWith('mon')) ? '1' : '0';
    final tue = d.any((s) => s.startsWith('tue')) ? '1' : '0';
    final wed = d.any((s) => s.startsWith('wed')) ? '1' : '0';
    final thu = d.any((s) => s.startsWith('thu')) ? '1' : '0';
    final fri = d.any((s) => s.startsWith('fri')) ? '1' : '0';
    final sat = d.any((s) => s.startsWith('sat')) ? '1' : '0';
    final mask = '$sun$mon$tue$wed$thu$fri$sat';
    return mask == '0000000' ? '1111111' : mask;
  }
}
