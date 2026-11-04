import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/health_metrics.dart';

/// Abstract contract for device telemetry, health metrics, and hardware peripherals.
/// Decouples UI presentation from physical ESP32 BLE / Wi-Fi implementation.
abstract class HealthRepository {
  ValueListenable<ConnectionStatus> get connectionStatus;
  ValueListenable<BatteryData> get battery;
  ValueListenable<HeartRateData> get heartRate;
  ValueListenable<Spo2Data> get spo2;
  ValueListenable<PostureData> get posture;
  ValueListenable<ActivityData> get activity;
  ValueListenable<DeviceInfo> get deviceInfo;
  ValueListenable<LedSettingsState> get ledSettings;
  ValueListenable<List<AlarmItem>> get alarms;
  ValueListenable<List<ReminderItem>> get reminders;
  ValueListenable<NotificationConfig> get notificationConfig;
  ValueListenable<WiFiState> get wifiState;
  ValueListenable<SoundSettings> get soundSettings;
  ValueListenable<DisplaySettings> get displaySettings;

  ValueListenable<List<HistoryEntry>> get historyEntries;
  String? get currentUserEmail;
  void resetForUser(String? email);

  Future<List<HistoryEntry>> getHistoryEntries({
    String? category,
    MetricTimeframe? timeframe,
  });

  void updateHeartRate(HeartRateData data);
  void updateSpo2(Spo2Data data);
  void updateActivity(ActivityData data);
  void updatePosture(PostureData data);
  void addHistoryEntry(HistoryEntry entry);
  void addHistoryEntries(List<HistoryEntry> entries);

  Future<void> connect();
  Future<void> disconnect();
  Future<void> syncNow();
  Future<void> calibratePosture();
  Future<void> pingDevice();

  // Device Name (Settings -> Device -> Device Name)
  Future<void> updateDeviceName(String newName);

  // General LED Settings (Sensor events only; Alarms & Reminders separated)
  Future<void> toggleLedEnabled(bool enabled);
  Future<void> updateLedColor(String eventId, Color newColor);
  Future<void> updateLedRgbColor(String eventId, RgbColor newColor);

  // Alarms
  Future<void> addAlarm(AlarmItem alarm);
  Future<void> updateAlarm(AlarmItem alarm);
  Future<void> toggleAlarm(String id, bool enabled);
  Future<void> deleteAlarm(String id);

  // Reminders
  Future<void> addReminder(ReminderItem reminder);
  Future<void> updateReminder(ReminderItem reminder);
  Future<void> toggleReminder(String id, bool enabled);
  Future<void> deleteReminder(String id);

  // Notifications
  Future<void> updateNotificationConfig(NotificationConfig config);

  // Wi-Fi
  Future<void> addWiFiNetwork(WiFiNetworkItem network);
  Future<void> updateWiFiNetwork(WiFiNetworkItem network);
  Future<void> deleteWiFiNetwork(String id);
  Future<void> setWiFiPriority(String id, int newPriority);
  Future<void> moveWiFiPriorityUp(String id);
  Future<void> moveWiFiPriorityDown(String id);
  Future<void> scanWiFi();
  Future<void> connectWiFi(String ssid);
  Future<void> disconnectWiFi();

  // Sound & Display
  Future<void> updateSoundSettings(SoundSettings settings);
  Future<void> updateDisplaySettings(DisplaySettings settings);

  void dispose();
}
