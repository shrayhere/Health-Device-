import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../services/ble_command_service.dart';
import '../services/ble_device_manager.dart';
import '../services/settings_storage_service.dart';
import '../services/wifi_scanner_service.dart';
import 'health_repository.dart';

/// Clean default repository implementation providing data reflecting the UI reference
/// for both mobile (Android) and responsive desktop (Windows).
/// Handles local persistence and syncs directly with BleDeviceManager for truthful BLE state.
class MockHealthRepository implements HealthRepository {
  final SettingsStorageService _storage = SettingsStorageService();
  final WiFiScannerService _scanner = WiFiScannerService();

  late final ValueNotifier<ConnectionStatus> _connectionStatus;
  late final ValueNotifier<BatteryData> _battery;
  late final ValueNotifier<HeartRateData> _heartRate;
  late final ValueNotifier<Spo2Data> _spo2;
  late final ValueNotifier<PostureData> _posture;
  late final ValueNotifier<ActivityData> _activity;
  late final ValueNotifier<DeviceInfo> _deviceInfo;
  late final ValueNotifier<LedSettingsState> _ledSettings;
  late final ValueNotifier<List<AlarmItem>> _alarms;
  late final ValueNotifier<List<ReminderItem>> _reminders;
  late final ValueNotifier<NotificationConfig> _notificationConfig;
  late final ValueNotifier<WiFiState> _wifiState;
  late final ValueNotifier<SoundSettings> _soundSettings;
  late final ValueNotifier<DisplaySettings> _displaySettings;

  MockHealthRepository() {
    _soundSettings = ValueNotifier<SoundSettings>(const SoundSettings());
    _displaySettings = ValueNotifier<DisplaySettings>(const DisplaySettings());

    // Truthful default state: disconnected until real BLE connection is established
    _connectionStatus = ValueNotifier<ConnectionStatus>(
      const ConnectionStatus(
        state: DeviceConnectionState.disconnected,
        deviceName: 'HealthDevice',
        rssi: null,
        lastSyncTime: null,
      ),
    );

    // Truthful battery state: unavailable until real BLE battery characteristic provides it
    _battery = ValueNotifier<BatteryData>(BatteryData.unavailable());

    _posture = ValueNotifier<PostureData>(
      PostureData(
        classification: PostureClassification.upright,
        tiltDegrees: 0.0,
        postureScoreToday: 0,
        goodPostureTime: Duration.zero,
        timestamp: DateTime.now(),
      ),
    );

    _deviceInfo = ValueNotifier<DeviceInfo>(
      const DeviceInfo(
        name: 'HealthDevice',
        model: 'ESP32-C3',
        hardwareRevision: 'Unavailable (Firmware v1.0.0)',
        firmwareVersion: 'Awaiting BLE Sync',
        macAddress: 'Unavailable',
        isCalibrated: false,
        pairedAt: null,
      ),
    );

    // Bind to single source of truth: BleDeviceManager
    final ble = BleDeviceManager();
    ble.connectionState.addListener(_onBleStateChanged);
    ble.batteryData.addListener(_onBleStateChanged);
    ble.deviceInfo.addListener(_onBleStateChanged);
    ble.firmwareStatus.addListener(_onBleStateChanged);
    ble.liveRssi.addListener(_onBleStateChanged);
    ble.liveHardwareState.addListener(_onLiveHardwareStateChanged);
    _onBleStateChanged();
    _startAlarmReminderTimer();

    // General LED settings: ONLY sensor events. Alarms and Reminders removed.
    _ledSettings = ValueNotifier<LedSettingsState>(
      const LedSettingsState(
        isEnabled: true,
        eventConfigs: [
          LedEventConfig(
            id: 'hr',
            eventName: 'Heart Rate',
            rgbColor: RgbColor.cyan(),
            description: 'Pulse sync flash on optical capture',
          ),
          LedEventConfig(
            id: 'spo2',
            eventName: 'SpO₂',
            rgbColor: RgbColor.cyan(),
            description: 'Oxygen saturation completion indicator',
          ),
          LedEventConfig(
            id: 'good_posture',
            eventName: 'Good Posture',
            rgbColor: RgbColor.green(),
            description: 'Ergonomic alignment confirmation',
          ),
          LedEventConfig(
            id: 'bad_posture',
            eventName: 'Bad Posture',
            rgbColor: RgbColor.orange(),
            description: 'Slouch alert warning indicator',
          ),
        ],
      ),
    );

    // Default alarms with custom RGB LED colors
    _alarms = ValueNotifier<List<AlarmItem>>([
      const AlarmItem(
        id: 'alarm_1',
        name: 'Wake Up',
        time: '07:30 AM',
        enabled: true,
        repeatDays: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
        soundEnabled: true,
        ledColor: RgbColor.redColor(),
      ),
      const AlarmItem(
        id: 'alarm_2',
        name: 'Gym Workout',
        time: '06:00 PM',
        enabled: false,
        repeatDays: ['Mon', 'Wed', 'Fri'],
        soundEnabled: true,
        ledColor: RgbColor.orange(),
      ),
    ]);

    // Default reminders with custom RGB LED colors
    _reminders = ValueNotifier<List<ReminderItem>>([
      const ReminderItem(
        id: 'rem_1',
        name: 'Drink Water',
        time: '02:00 PM',
        enabled: true,
        repeatSchedule: 'Daily',
        soundEnabled: true,
        ledColor: RgbColor.cyan(),
      ),
      const ReminderItem(
        id: 'rem_2',
        name: 'Posture Check',
        time: '11:00 AM',
        enabled: true,
        repeatSchedule: 'Weekdays',
        soundEnabled: false,
        ledColor: RgbColor.purple(),
      ),
    ]);

    // Default notification toggles
    _notificationConfig = ValueNotifier<NotificationConfig>(
      const NotificationConfig(),
    );

    // Default Wi-Fi networks with priorities
    final defaultNetworks = [
      const WiFiNetworkItem(
        id: 'wifi_1',
        ssid: 'Home_WiFi',
        password: 'password123',
        priority: 1,
        enabled: true,
      ),
      const WiFiNetworkItem(
        id: 'wifi_2',
        ssid: 'College WiFi',
        password: 'campus_secure',
        priority: 2,
        enabled: true,
      ),
      const WiFiNetworkItem(
        id: 'wifi_3',
        ssid: 'Phone Hotspot',
        password: 'mobile_share',
        priority: 3,
        enabled: true,
      ),
    ];

    _wifiState = ValueNotifier<WiFiState>(
      WiFiState(
        connectedSsid: 'Home_WiFi',
        isConnected: true,
        ipAddress: '192.168.1.24',
        savedNetworks: defaultNetworks,
      ),
    );

    _heartRate = ValueNotifier<HeartRateData>(HeartRateData.empty());
    _spo2 = ValueNotifier<Spo2Data>(Spo2Data.empty());
    _activity = ValueNotifier<ActivityData>(ActivityData.empty());

    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      _currentUserEmail = 'guptashaurya020@gmail.com';
      _restoreOwnerBaseline();
    }

    _initPersistence();
  }

  String? _currentUserEmail;

  @override
  String? get currentUserEmail => _currentUserEmail;

  static bool _isHardwareOwnerEmail(String? email) {
    if (email == null) return false;
    final clean = email.trim().toLowerCase();
    return clean == 'guptashaurya020@gmail.com' || clean == 'user@healthdevice.com';
  }

  @override
  void resetForUser(String? email) {
    _currentUserEmail = email?.trim().toLowerCase();
    if (_isHardwareOwnerEmail(_currentUserEmail)) {
      _restoreOwnerBaseline();
    } else {
      _clearToZeroState();
    }
  }

  void _clearToZeroState() {
    _heartRate.value = HeartRateData.empty();
    _spo2.value = Spo2Data.empty();
    _activity.value = ActivityData.empty();
    _posture.value = PostureData(
      classification: PostureClassification.upright,
      tiltDegrees: 0.0,
      postureScoreToday: 0,
      goodPostureTime: Duration.zero,
      timestamp: DateTime.now(),
    );
    _historyNotifier.value = [];
  }

  void _restoreOwnerBaseline() {
    final hrSpark = [
      const ChartDataPoint(x: 0, y: 68),
      const ChartDataPoint(x: 1, y: 70),
      const ChartDataPoint(x: 2, y: 66),
      const ChartDataPoint(x: 3, y: 74),
      const ChartDataPoint(x: 4, y: 72),
      const ChartDataPoint(x: 5, y: 78),
      const ChartDataPoint(x: 6, y: 71),
      const ChartDataPoint(x: 7, y: 72),
    ];

    final hrDay = [
      const ChartDataPoint(x: 8, y: 62, label: '8AM'),
      const ChartDataPoint(x: 9, y: 68),
      const ChartDataPoint(x: 10, y: 75),
      const ChartDataPoint(x: 11, y: 71),
      const ChartDataPoint(x: 12, y: 92, label: '12PM'),
      const ChartDataPoint(x: 13, y: 84),
      const ChartDataPoint(x: 14, y: 66),
      const ChartDataPoint(x: 15, y: 73),
      const ChartDataPoint(x: 16, y: 102, label: '4PM'),
      const ChartDataPoint(x: 17, y: 89),
      const ChartDataPoint(x: 18, y: 78),
      const ChartDataPoint(x: 19, y: 70),
      const ChartDataPoint(x: 20, y: 68, label: '8PM'),
    ];

    final hrWeek = [
      const ChartDataPoint(x: 1, y: 70, label: 'Mon'),
      const ChartDataPoint(x: 2, y: 72, label: 'Tue'),
      const ChartDataPoint(x: 3, y: 68, label: 'Wed'),
      const ChartDataPoint(x: 4, y: 74, label: 'Thu'),
      const ChartDataPoint(x: 5, y: 76, label: 'Fri'),
      const ChartDataPoint(x: 6, y: 69, label: 'Sat'),
      const ChartDataPoint(x: 7, y: 71, label: 'Sun'),
    ];

    final hrMonth = [
      const ChartDataPoint(x: 1, y: 71, label: 'W1'),
      const ChartDataPoint(x: 2, y: 73, label: 'W2'),
      const ChartDataPoint(x: 3, y: 70, label: 'W3'),
      const ChartDataPoint(x: 4, y: 72, label: 'W4'),
    ];

    _heartRate.value = HeartRateData(
      currentBpm: 72,
      restingBpm: 64,
      minToday: 62,
      avgToday: 74,
      maxToday: 102,
      timestamp: DateTime.now().subtract(const Duration(seconds: 45)),
      sparkline: hrSpark,
      dayData: hrDay,
      weekData: hrWeek,
      monthData: hrMonth,
    );

    final spo2Spark = [
      const ChartDataPoint(x: 0, y: 98),
      const ChartDataPoint(x: 1, y: 97),
      const ChartDataPoint(x: 2, y: 98),
      const ChartDataPoint(x: 3, y: 99),
      const ChartDataPoint(x: 4, y: 98),
      const ChartDataPoint(x: 5, y: 98),
    ];

    final spo2Day = [
      const ChartDataPoint(x: 8, y: 98, label: '8AM'),
      const ChartDataPoint(x: 10, y: 97),
      const ChartDataPoint(x: 12, y: 99, label: '12PM'),
      const ChartDataPoint(x: 14, y: 98),
      const ChartDataPoint(x: 16, y: 96, label: '4PM'),
      const ChartDataPoint(x: 18, y: 98),
      const ChartDataPoint(x: 20, y: 98, label: '8PM'),
    ];

    final spo2Week = [
      const ChartDataPoint(x: 1, y: 98, label: 'Mon'),
      const ChartDataPoint(x: 2, y: 98, label: 'Tue'),
      const ChartDataPoint(x: 3, y: 97, label: 'Wed'),
      const ChartDataPoint(x: 4, y: 99, label: 'Thu'),
      const ChartDataPoint(x: 5, y: 98, label: 'Fri'),
      const ChartDataPoint(x: 6, y: 98, label: 'Sat'),
      const ChartDataPoint(x: 7, y: 98, label: 'Sun'),
    ];

    final spo2Month = [
      const ChartDataPoint(x: 1, y: 98, label: 'W1'),
      const ChartDataPoint(x: 2, y: 98, label: 'W2'),
      const ChartDataPoint(x: 3, y: 97, label: 'W3'),
      const ChartDataPoint(x: 4, y: 98, label: 'W4'),
    ];

    _spo2.value = Spo2Data(
      percentage: 98,
      minToday: 96,
      avgToday: 98,
      maxToday: 99,
      timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
      sparkline: spo2Spark,
      dayData: spo2Day,
      weekData: spo2Week,
      monthData: spo2Month,
    );

    final hourlyBars = [
      const ChartDataPoint(x: 0, y: 0, label: '12AM'),
      const ChartDataPoint(x: 2, y: 0),
      const ChartDataPoint(x: 4, y: 20),
      const ChartDataPoint(x: 6, y: 140, label: '6AM'),
      const ChartDataPoint(x: 8, y: 380),
      const ChartDataPoint(x: 10, y: 220),
      const ChartDataPoint(x: 12, y: 490, label: '12PM'),
      const ChartDataPoint(x: 14, y: 310),
      const ChartDataPoint(x: 16, y: 210),
      const ChartDataPoint(x: 18, y: 180, label: '6PM'),
    ];

    final weeklyBars = [
      const ChartDataPoint(x: 1, y: 4800, label: 'Mon'),
      const ChartDataPoint(x: 2, y: 6200, label: 'Tue'),
      const ChartDataPoint(x: 3, y: 5400, label: 'Wed'),
      const ChartDataPoint(x: 4, y: 7100, label: 'Thu'),
      const ChartDataPoint(x: 5, y: 3900, label: 'Fri'),
      const ChartDataPoint(x: 6, y: 8200, label: 'Sat'),
      const ChartDataPoint(x: 7, y: 1250, label: 'Sun'),
    ];

    final monthlyBars = [
      const ChartDataPoint(x: 1, y: 38500, label: 'W1'),
      const ChartDataPoint(x: 2, y: 42100, label: 'W2'),
      const ChartDataPoint(x: 3, y: 39800, label: 'W3'),
      const ChartDataPoint(x: 4, y: 28400, label: 'W4'),
    ];

    _activity.value = ActivityData(
      steps: 1250,
      stepGoal: 5000,
      distanceKm: 1.2,
      caloriesKcal: 92,
      activeMinutes: 18,
      currentMovementState: 'Light movement',
      timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      hourlyBars: hourlyBars,
      weeklyBars: weeklyBars,
      monthlyBars: monthlyBars,
    );

    final postureSpark = [
      const ChartDataPoint(x: 0, y: 1.2),
      const ChartDataPoint(x: 1, y: 1.5),
      const ChartDataPoint(x: 2, y: 2.1),
      const ChartDataPoint(x: 3, y: 1.8),
      const ChartDataPoint(x: 4, y: 2.5),
      const ChartDataPoint(x: 5, y: 2.0),
      const ChartDataPoint(x: 6, y: 1.7),
      const ChartDataPoint(x: 7, y: 1.9),
    ];

    _posture.value = PostureData(
      classification: PostureClassification.upright,
      tiltDegrees: 0.0,
      postureScoreToday: 0,
      goodPostureTime: Duration.zero,
      timestamp: DateTime.now(),
      sparkline: postureSpark,
    );
  }

  Future<void> _initPersistence() async {
    await _storage.init();

    // 1. Device Name
    final savedName = _storage.getDeviceName();
    if (savedName != null && savedName.trim().isNotEmpty) {
      _deviceInfo.value = _deviceInfo.value.copyWith(name: savedName);
      _connectionStatus.value = _connectionStatus.value.copyWith(
        deviceName: savedName,
      );
    }

    // 2. LED Settings
    final savedLed = _storage.getLedSettings();
    if (savedLed != null) {
      try {
        final parsed = LedSettingsState.fromJson(savedLed);
        _ledSettings.value = parsed;
      } catch (_) {}
    }

    // 3. Alarms
    final savedAlarms = _storage.getAlarms();
    if (savedAlarms != null) {
      try {
        final list = savedAlarms.map((m) => AlarmItem.fromJson(m)).toList();
        if (list.isNotEmpty) _alarms.value = list;
      } catch (_) {}
    }

    // 4. Reminders
    final savedReminders = _storage.getReminders();
    if (savedReminders != null) {
      try {
        final list = savedReminders
            .map((m) => ReminderItem.fromJson(m))
            .toList();
        if (list.isNotEmpty) _reminders.value = list;
      } catch (_) {}
    }

    // 5. Notifications
    final savedNotifs = _storage.getNotifications();
    if (savedNotifs != null) {
      try {
        final parsed = NotificationConfig.fromJson(savedNotifs);
        _notificationConfig.value = parsed;
      } catch (_) {}
    }

    // 6. Wi-Fi
    final savedWifi = _storage.getWiFiNetworks();
    if (savedWifi != null) {
      try {
        final list = savedWifi.map((m) => WiFiNetworkItem.fromJson(m)).toList();
        if (list.isNotEmpty) {
          _wifiState.value = _wifiState.value.copyWith(savedNetworks: list);
        }
      } catch (_) {}
    }

    // 7. Sound Settings
    final savedSound = _storage.getSoundSettings();
    if (savedSound != null) {
      try {
        _soundSettings.value = SoundSettings.fromJson(savedSound);
      } catch (_) {}
    }

    // 8. Display Settings
    final savedDisplay = _storage.getDisplaySettings();
    if (savedDisplay != null) {
      try {
        _displaySettings.value = DisplaySettings.fromJson(savedDisplay);
      } catch (_) {}
    }
  }

  @override
  ValueListenable<ConnectionStatus> get connectionStatus => _connectionStatus;

  @override
  ValueListenable<BatteryData> get battery => _battery;

  @override
  ValueListenable<HeartRateData> get heartRate => _heartRate;

  @override
  ValueListenable<Spo2Data> get spo2 => _spo2;

  @override
  ValueListenable<PostureData> get posture => _posture;

  @override
  ValueListenable<ActivityData> get activity => _activity;

  @override
  ValueListenable<DeviceInfo> get deviceInfo => _deviceInfo;

  @override
  ValueListenable<LedSettingsState> get ledSettings => _ledSettings;

  @override
  ValueListenable<List<AlarmItem>> get alarms => _alarms;

  @override
  ValueListenable<List<ReminderItem>> get reminders => _reminders;

  @override
  ValueListenable<NotificationConfig> get notificationConfig =>
      _notificationConfig;

  @override
  ValueListenable<WiFiState> get wifiState => _wifiState;

  @override
  ValueListenable<SoundSettings> get soundSettings => _soundSettings;

  @override
  ValueListenable<DisplaySettings> get displaySettings => _displaySettings;

  @override
  Future<List<HistoryEntry>> getHistoryEntries({
    String? category,
    MetricTimeframe? timeframe,
  }) async {
    if (!_isHardwareOwnerEmail(_currentUserEmail)) {
      var entries = _historyNotifier.value;
      if (category != null && category != 'All') {
        entries = entries
            .where((e) => e.category.toLowerCase() == category.toLowerCase())
            .toList();
      }
      return entries;
    }

    final now = DateTime.now();
    final tf = timeframe ?? MetricTimeframe.day;

    List<HistoryEntry> entries = [];

    switch (tf) {
      case MetricTimeframe.day:
      case MetricTimeframe.live:
        // Day view: Hourly events from today
        entries = [
          HistoryEntry(
            id: 'd1',
            timestamp: now.subtract(const Duration(minutes: 5)),
            title: 'Heart Rate',
            category: 'Heart Rate',
            valueDisplay: '72',
            unit: 'bpm',
            status: 'Normal',
            detail: '09:41',
            section: 'Today',
          ),
          HistoryEntry(
            id: 'd2',
            timestamp: now.subtract(const Duration(minutes: 15)),
            title: 'SpO₂',
            category: 'SpO2',
            valueDisplay: '98',
            unit: '%',
            status: 'Normal',
            detail: '09:35',
            section: 'Today',
          ),
          HistoryEntry(
            id: 'd3',
            timestamp: now.subtract(const Duration(minutes: 30)),
            title: 'Posture',
            category: 'Posture',
            valueDisplay: 'Good',
            unit: '',
            status: 'Upright',
            detail: '09:20',
            section: 'Today',
          ),
          HistoryEntry(
            id: 'd4',
            timestamp: now.subtract(const Duration(minutes: 45)),
            title: 'Activity',
            category: 'Activity',
            valueDisplay: '1,250',
            unit: 'steps',
            status: 'Goal 5,000',
            detail: '09:15',
            section: 'Today',
          ),
        ];
        break;

      case MetricTimeframe.week:
        // Week view: Daily summary entries covering the past 7 days
        entries = [
          HistoryEntry(
            id: 'w1',
            timestamp: now.subtract(const Duration(hours: 4)),
            title: 'Heart Rate Daily Avg',
            category: 'Heart Rate',
            valueDisplay: '71',
            unit: 'bpm',
            status: 'Normal',
            detail: 'Sunday',
            section: 'This Week',
          ),
          HistoryEntry(
            id: 'w2',
            timestamp: now.subtract(const Duration(days: 1)),
            title: 'SpO₂ Daily Avg',
            category: 'SpO2',
            valueDisplay: '98',
            unit: '%',
            status: 'Normal',
            detail: 'Saturday',
            section: 'This Week',
          ),
          HistoryEntry(
            id: 'w3',
            timestamp: now.subtract(const Duration(days: 1, hours: 2)),
            title: 'Steps Target Reached',
            category: 'Activity',
            valueDisplay: '8,200',
            unit: 'steps',
            status: '164% Goal',
            detail: 'Saturday',
            section: 'This Week',
          ),
          HistoryEntry(
            id: 'w4',
            timestamp: now.subtract(const Duration(days: 2)),
            title: 'Posture Alignment Score',
            category: 'Posture',
            valueDisplay: '94%',
            unit: 'score',
            status: 'Optimal',
            detail: 'Friday',
            section: 'This Week',
          ),
          HistoryEntry(
            id: 'w5',
            timestamp: now.subtract(const Duration(days: 3)),
            title: 'Activity Daily Total',
            category: 'Activity',
            valueDisplay: '7,100',
            unit: 'steps',
            status: 'Goal Met',
            detail: 'Thursday',
            section: 'Past 7 Days',
          ),
          HistoryEntry(
            id: 'w6',
            timestamp: now.subtract(const Duration(days: 4)),
            title: 'Heart Rate Resting Avg',
            category: 'Heart Rate',
            valueDisplay: '66',
            unit: 'bpm',
            status: 'Resting',
            detail: 'Wednesday',
            section: 'Past 7 Days',
          ),
        ];
        break;

      case MetricTimeframe.month:
        // Month view: 4 weekly summary milestones
        entries = [
          HistoryEntry(
            id: 'm1',
            timestamp: now.subtract(const Duration(days: 2)),
            title: 'Week 4 Aggregate Activity',
            category: 'Activity',
            valueDisplay: '28,400',
            unit: 'steps',
            status: 'In Progress',
            detail: 'Sep 21–27',
            section: 'September 2026',
          ),
          HistoryEntry(
            id: 'm2',
            timestamp: now.subtract(const Duration(days: 7)),
            title: 'Week 3 Heart Rate Baseline',
            category: 'Heart Rate',
            valueDisplay: '70',
            unit: 'bpm avg',
            status: 'Steady',
            detail: 'Sep 14–20',
            section: 'September 2026',
          ),
          HistoryEntry(
            id: 'm3',
            timestamp: now.subtract(const Duration(days: 14)),
            title: 'Week 2 Oxygen Saturation',
            category: 'SpO2',
            valueDisplay: '98%',
            unit: 'avg',
            status: 'Optimal',
            detail: 'Sep 07–13',
            section: 'September 2026',
          ),
          HistoryEntry(
            id: 'm4',
            timestamp: now.subtract(const Duration(days: 21)),
            title: 'Week 1 Ergonomics Score',
            category: 'Posture',
            valueDisplay: '89%',
            unit: 'good posture',
            status: 'Consistent',
            detail: 'Sep 01–06',
            section: 'September 2026',
          ),
        ];
        break;
    }

    final combined = [..._historyNotifier.value, ...entries];
    if (category == null || category == 'All') {
      return combined;
    }
    return combined
        .where((e) => e.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  void _onBleStateChanged() {
    final ble = BleDeviceManager();
    final isConnected = ble.isConnected;
    final bleState = ble.connectionState.value;

    DeviceConnectionState connState;
    switch (bleState) {
      case BleDeviceState.connected:
        connState = DeviceConnectionState.connected;
        break;
      case BleDeviceState.connecting:
      case BleDeviceState.discoveringServices:
        connState = DeviceConnectionState.connecting;
        break;
      case BleDeviceState.disconnected:
      case BleDeviceState.bluetoothDisabled:
      case BleDeviceState.unsupported:
      case BleDeviceState.connectionFailed:
      case BleDeviceState.scanning:
        connState = DeviceConnectionState.disconnected;
        break;
    }

    _connectionStatus.value = ConnectionStatus(
      state: connState,
      deviceName: ble.connectedDevice.value?.platformName.isNotEmpty == true
          ? ble.connectedDevice.value!.platformName
          : (ble.deviceInfo.value.name.isNotEmpty
                ? ble.deviceInfo.value.name
                : 'HealthDevice'),
      rssi: ble.liveRssi.value,
      lastSyncTime: isConnected ? DateTime.now() : null,
    );

    _battery.value = ble.batteryData.value;
    _deviceInfo.value = ble.deviceInfo.value;
  }

  void _onLiveHardwareStateChanged() {
    final state = BleDeviceManager().liveHardwareState.value;
    if (state == null) return;

    // Heart Rate
    if (state.containsKey('hr')) {
      final hr = (state['hr'] as num).toInt();
      if (hr > 30 && hr < 220) {
        _heartRate.value = _heartRate.value.copyWith(
          currentBpm: hr,
          timestamp: DateTime.now(),
        );
      }
    }

    // SpO2
    if (state.containsKey('spo2')) {
      final spo2 = (state['spo2'] as num).toInt();
      if (spo2 > 70 && spo2 <= 100) {
        _spo2.value = _spo2.value.copyWith(
          percentage: spo2,
          timestamp: DateTime.now(),
        );
      }
    }

    // Steps & Activity
    if (state.containsKey('steps')) {
      final steps = (state['steps'] as num).toInt();
      final dist = state.containsKey('distance')
          ? double.tryParse(state['distance'].toString()) ??
              _activity.value.distanceKm
          : _activity.value.distanceKm;
      final cals = state.containsKey('calories')
          ? (state['calories'] as num).toInt()
          : _activity.value.caloriesKcal;
      final actMin = state.containsKey('activeMin')
          ? (state['activeMin'] as num).toInt()
          : _activity.value.activeMinutes;

      _activity.value = _activity.value.copyWith(
        steps: steps,
        distanceKm: dist,
        caloriesKcal: cals,
        activeMinutes: actMin,
        timestamp: DateTime.now(),
      );
    }

    // Posture
    if (state.containsKey('posture_tilt') || state.containsKey('posture_good')) {
      final isGood = state['posture_good'] == true;
      final tilt = state.containsKey('posture_tilt')
          ? double.tryParse(state['posture_tilt'].toString()) ?? 0.0
          : 0.0;
      _posture.value = _posture.value.copyWith(
        classification:
            isGood ? PostureClassification.upright : PostureClassification.slouching,
        tiltDegrees: tilt,
        timestamp: DateTime.now(),
      );
    }
  }

  Timer? _alarmReminderTimer;
  int _lastTriggerMinute = -1;

  void _startAlarmReminderTimer() {
    // Avoid creating pending timers in automated test runners
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    _alarmReminderTimer?.cancel();
    _alarmReminderTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final now = DateTime.now();
      final minuteOfDay = now.hour * 60 + now.minute;
      if (minuteOfDay == _lastTriggerMinute) return;

      final currentH = now.hour;
      final currentM = now.minute;
      final currentWeekday = now.weekday; // 1=Mon..7=Sun
      final daysNames = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
      final todayStr = daysNames[currentWeekday - 1];

      // Check Alarms
      for (final alarm in _alarms.value) {
        if (!alarm.enabled) continue;
        final hm = _parseHourMinute(alarm.time);
        if (hm[0] == currentH && hm[1] == currentM) {
          final repeat = alarm.repeatDays.map((d) => d.toLowerCase()).toList();
          final matchesDay =
              repeat.isEmpty || repeat.any((d) => d.startsWith(todayStr));
          if (matchesDay) {
            _lastTriggerMinute = minuteOfDay;
            debugPrint('[AlarmEngine] Triggering alarm: ${alarm.name} at ${alarm.time}');
            addHistoryEntry(HistoryEntry(
              id: 'alarm_${DateTime.now().millisecondsSinceEpoch}',
              timestamp: DateTime.now(),
              title: 'Alarm: ${alarm.name}',
              category: 'Alarm',
              valueDisplay: alarm.time,
              unit: '',
              status: 'Triggered',
              detail: 'Scheduled alert sounded',
              section: 'Today',
            ));
            break;
          }
        }
      }

      // Check Reminders
      for (final reminder in _reminders.value) {
        if (!reminder.enabled) continue;
        final hm = _parseHourMinute(reminder.time);
        if (hm[0] == currentH && hm[1] == currentM) {
          _lastTriggerMinute = minuteOfDay;
          debugPrint('[ReminderEngine] Triggering reminder: ${reminder.name} at ${reminder.time}');
          addHistoryEntry(HistoryEntry(
            id: 'reminder_${DateTime.now().millisecondsSinceEpoch}',
            timestamp: DateTime.now(),
            title: 'Reminder: ${reminder.name}',
            category: 'Reminder',
            valueDisplay: reminder.time,
            unit: '',
            status: 'Triggered',
            detail: reminder.repeatSchedule,
            section: 'Today',
          ));
          break;
        }
      }
    });
  }

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

  @override
  Future<void> connect() async {
    final ble = BleDeviceManager();
    final hd = ble.discoveredDevices.value
        .where((d) => d.isHealthDevice)
        .firstOrNull;
    if (hd != null) {
      await ble.connectToDevice(hd.device);
    } else {
      await ble.startScan();
    }
  }

  @override
  Future<void> disconnect() async {
    await BleDeviceManager().disconnect();
  }

  @override
  Future<void> syncNow() async {
    await BleCommandService().triggerMeasurement();
  }

  @override
  Future<void> calibratePosture() async {
    BleCommandService().calibratePosture();
    await Future.delayed(const Duration(milliseconds: 500));
    _posture.value = _posture.value.copyWith(
      tiltDegrees: 0.0,
      classification: PostureClassification.upright,
      timestamp: DateTime.now(),
    );
  }

  @override
  Future<void> pingDevice() async {
    await BleCommandService().requestState();
  }

  // --- Device Name ---
  @override
  Future<void> updateDeviceName(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;

    _deviceInfo.value = _deviceInfo.value.copyWith(name: trimmed);
    _connectionStatus.value = _connectionStatus.value.copyWith(
      deviceName: trimmed,
    );
    BleDeviceManager().deviceInfo.value =
        BleDeviceManager().deviceInfo.value.copyWith(name: trimmed);

    await _storage.saveDeviceName(trimmed);
  }

  // --- General LED Settings ---
  @override
  Future<void> toggleLedEnabled(bool enabled) async {
    final updated = _ledSettings.value.copyWith(isEnabled: enabled);
    _ledSettings.value = updated;
    await _storage.saveLedSettings(updated.toJson());
    BleCommandService().syncLedSettings(updated);
  }

  @override
  Future<void> updateLedColor(String eventId, Color newColor) async {
    await updateLedRgbColor(eventId, RgbColor.fromColor(newColor));
  }

  @override
  Future<void> updateLedRgbColor(String eventId, RgbColor newColor) async {
    final updatedConfigs = _ledSettings.value.eventConfigs.map((cfg) {
      if (cfg.id == eventId) {
        return cfg.copyWith(rgbColor: newColor);
      }
      return cfg;
    }).toList();

    final updated = _ledSettings.value.copyWith(eventConfigs: updatedConfigs);
    _ledSettings.value = updated;
    await _storage.saveLedSettings(updated.toJson());
    BleCommandService().syncLedSettings(updated);
    BleCommandService().testLed(newColor);
  }

  // --- Alarms ---
  @override
  Future<void> addAlarm(AlarmItem alarm) async {
    final list = List<AlarmItem>.from(_alarms.value)..add(alarm);
    _alarms.value = list;
    await _storage.saveAlarms(list.map((a) => a.toJson()).toList());
    BleCommandService().syncAlarms(list);
  }

  @override
  Future<void> updateAlarm(AlarmItem alarm) async {
    final list = _alarms.value
        .map((a) => a.id == alarm.id ? alarm : a)
        .toList();
    _alarms.value = list;
    await _storage.saveAlarms(list.map((a) => a.toJson()).toList());
    BleCommandService().syncAlarms(list);
  }

  @override
  Future<void> toggleAlarm(String id, bool enabled) async {
    final list = _alarms.value
        .map((a) => a.id == id ? a.copyWith(enabled: enabled) : a)
        .toList();
    _alarms.value = list;
    await _storage.saveAlarms(list.map((a) => a.toJson()).toList());
    BleCommandService().syncAlarms(list);
  }

  @override
  Future<void> deleteAlarm(String id) async {
    final list = List<AlarmItem>.from(_alarms.value)
      ..removeWhere((a) => a.id == id);
    _alarms.value = list;
    await _storage.saveAlarms(list.map((a) => a.toJson()).toList());
    BleCommandService().syncAlarms(list);
  }

  // --- Reminders ---
  @override
  Future<void> addReminder(ReminderItem reminder) async {
    final list = List<ReminderItem>.from(_reminders.value)..add(reminder);
    _reminders.value = list;
    await _storage.saveReminders(list.map((r) => r.toJson()).toList());
    BleCommandService().syncReminders(list);
  }

  @override
  Future<void> updateReminder(ReminderItem reminder) async {
    final list = _reminders.value
        .map((r) => r.id == reminder.id ? reminder : r)
        .toList();
    _reminders.value = list;
    await _storage.saveReminders(list.map((r) => r.toJson()).toList());
    BleCommandService().syncReminders(list);
  }

  @override
  Future<void> toggleReminder(String id, bool enabled) async {
    final list = _reminders.value
        .map((r) => r.id == id ? r.copyWith(enabled: enabled) : r)
        .toList();
    _reminders.value = list;
    await _storage.saveReminders(list.map((r) => r.toJson()).toList());
    BleCommandService().syncReminders(list);
  }

  @override
  Future<void> deleteReminder(String id) async {
    final list = List<ReminderItem>.from(_reminders.value)
      ..removeWhere((r) => r.id == id);
    _reminders.value = list;
    await _storage.saveReminders(list.map((r) => r.toJson()).toList());
    BleCommandService().syncReminders(list);
  }

  // --- Notifications ---
  @override
  Future<void> updateNotificationConfig(NotificationConfig config) async {
    _notificationConfig.value = config;
    await _storage.saveNotifications(config.toJson());
  }

  // --- Wi-Fi ---
  @override
  Future<void> addWiFiNetwork(WiFiNetworkItem network) async {
    final currentList = List<WiFiNetworkItem>.from(
      _wifiState.value.savedNetworks,
    );
    final existingIndex = currentList.indexWhere(
      (n) =>
          n.id == network.id ||
          n.ssid.toLowerCase() == network.ssid.toLowerCase(),
    );

    if (existingIndex >= 0) {
      // Update existing entry, preserve original ID, do not duplicate!
      final existing = currentList[existingIndex];
      currentList[existingIndex] = existing.copyWith(
        ssid: network.ssid,
        password: network.password.isNotEmpty
            ? network.password
            : existing.password,
        priority: network.priority,
        securityType: network.securityType,
        frequency: network.frequency,
      );
    } else {
      currentList.add(network);
    }

    currentList.sort((a, b) => a.priority.compareTo(b.priority));
    _wifiState.value = _wifiState.value.copyWith(savedNetworks: currentList);
    await _storage.saveWiFiNetworks(
      currentList.map((n) => n.toJson()).toList(),
    );
  }

  @override
  Future<void> updateWiFiNetwork(WiFiNetworkItem network) async {
    final currentList = List<WiFiNetworkItem>.from(
      _wifiState.value.savedNetworks,
    );
    final existingIndex = currentList.indexWhere(
      (n) =>
          n.id == network.id ||
          n.ssid.toLowerCase() == network.ssid.toLowerCase(),
    );

    if (existingIndex >= 0) {
      // Preserve original ID, update in place
      final originalId = currentList[existingIndex].id;
      currentList[existingIndex] = network.copyWith(id: originalId);
    } else {
      currentList.add(network);
    }

    currentList.sort((a, b) => a.priority.compareTo(b.priority));
    _wifiState.value = _wifiState.value.copyWith(savedNetworks: currentList);
    await _storage.saveWiFiNetworks(
      currentList.map((n) => n.toJson()).toList(),
    );
  }

  @override
  Future<void> deleteWiFiNetwork(String id) async {
    final list = List<WiFiNetworkItem>.from(_wifiState.value.savedNetworks)
      ..removeWhere((n) => n.id == id);
    _wifiState.value = _wifiState.value.copyWith(savedNetworks: list);
    await _storage.saveWiFiNetworks(list.map((n) => n.toJson()).toList());
  }

  @override
  Future<void> setWiFiPriority(String id, int newPriority) async {
    final list = _wifiState.value.savedNetworks
        .map((n) => n.id == id ? n.copyWith(priority: newPriority) : n)
        .toList();
    list.sort((a, b) => a.priority.compareTo(b.priority));
    _wifiState.value = _wifiState.value.copyWith(savedNetworks: list);
    await _storage.saveWiFiNetworks(list.map((n) => n.toJson()).toList());
  }

  @override
  Future<void> moveWiFiPriorityUp(String id) async {
    final list = List<WiFiNetworkItem>.from(_wifiState.value.savedNetworks);
    final index = list.indexWhere((n) => n.id == id);
    if (index > 0) {
      final current = list[index];
      final above = list[index - 1];
      final tempPriority = above.priority;
      list[index - 1] = above.copyWith(priority: current.priority);
      list[index] = current.copyWith(priority: tempPriority);
      list.sort((a, b) => a.priority.compareTo(b.priority));
      _wifiState.value = _wifiState.value.copyWith(savedNetworks: list);
      await _storage.saveWiFiNetworks(list.map((n) => n.toJson()).toList());
    }
  }

  @override
  Future<void> moveWiFiPriorityDown(String id) async {
    final list = List<WiFiNetworkItem>.from(_wifiState.value.savedNetworks);
    final index = list.indexWhere((n) => n.id == id);
    if (index >= 0 && index < list.length - 1) {
      final current = list[index];
      final below = list[index + 1];
      final tempPriority = below.priority;
      list[index + 1] = below.copyWith(priority: current.priority);
      list[index] = current.copyWith(priority: tempPriority);
      list.sort((a, b) => a.priority.compareTo(b.priority));
      _wifiState.value = _wifiState.value.copyWith(savedNetworks: list);
      await _storage.saveWiFiNetworks(list.map((n) => n.toJson()).toList());
    }
  }

  @override
  Future<void> scanWiFi() async {
    _wifiState.value = _wifiState.value.copyWith(
      isScanning: true,
      scanError: null,
    );
    try {
      final results = await _scanner.scanNearbyNetworks();
      _wifiState.value = _wifiState.value.copyWith(
        isScanning: false,
        scannedNetworks: results,
      );
    } catch (e) {
      _wifiState.value = _wifiState.value.copyWith(
        isScanning: false,
        scanError: e.toString(),
      );
    }
  }

  @override
  Future<void> connectWiFi(String ssid) async {
    _wifiState.value = _wifiState.value.copyWith(
      connectedSsid: ssid,
      isConnected: true,
      ipAddress: '192.168.1.24',
    );
  }

  @override
  Future<void> disconnectWiFi() async {
    _wifiState.value = _wifiState.value.copyWith(
      connectedSsid: null,
      isConnected: false,
      ipAddress: null,
    );
  }

  @override
  Future<void> updateSoundSettings(SoundSettings settings) async {
    _soundSettings.value = settings;
    await _storage.saveSoundSettings(settings.toJson());
    BleCommandService().syncSoundSettings(settings);
  }

  @override
  Future<void> updateDisplaySettings(DisplaySettings settings) async {
    _displaySettings.value = settings;
    await _storage.saveDisplaySettings(settings.toJson());
    BleCommandService().syncDisplaySettings(settings);
  }

  final ValueNotifier<List<HistoryEntry>> _historyNotifier =
      ValueNotifier<List<HistoryEntry>>([]);

  @override
  ValueListenable<List<HistoryEntry>> get historyEntries => _historyNotifier;

  @override
  void updateHeartRate(HeartRateData data) {
    _heartRate.value = data;
  }

  @override
  void updateSpo2(Spo2Data data) {
    _spo2.value = data;
  }

  @override
  void updateActivity(ActivityData data) {
    _activity.value = data;
  }

  @override
  void updatePosture(PostureData data) {
    _posture.value = data;
  }

  @override
  void addHistoryEntry(HistoryEntry entry) {
    _historyNotifier.value = [entry, ..._historyNotifier.value];
  }

  @override
  void addHistoryEntries(List<HistoryEntry> entries) {
    _historyNotifier.value = [...entries, ..._historyNotifier.value];
  }

  @override
  void dispose() {
    _alarmReminderTimer?.cancel();
    _historyNotifier.dispose();
    _connectionStatus.dispose();
    _battery.dispose();
    _heartRate.dispose();
    _spo2.dispose();
    _posture.dispose();
    _activity.dispose();
    _deviceInfo.dispose();
    _ledSettings.dispose();
    _alarms.dispose();
    _reminders.dispose();
    _notificationConfig.dispose();
    _wifiState.dispose();
    _soundSettings.dispose();
    _displaySettings.dispose();
  }
}
