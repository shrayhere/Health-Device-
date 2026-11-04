import 'package:flutter/material.dart';

/// Connection state of the HealthDevice.
enum DeviceConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

/// Timeframe selection matching reference tabs (Live, Day, Week, Month).
enum MetricTimeframe { live, day, week, month }

/// Information about device connection and signal.
class ConnectionStatus {
  final DeviceConnectionState state;
  final String deviceName;
  final int? rssi;
  final DateTime? lastSyncTime;

  const ConnectionStatus({
    required this.state,
    required this.deviceName,
    this.rssi,
    this.lastSyncTime,
  });

  bool get isConnected => state == DeviceConnectionState.connected;
  bool get isConnecting => state == DeviceConnectionState.connecting;

  String get stateLabel {
    switch (state) {
      case DeviceConnectionState.connected:
        return 'Connected';
      case DeviceConnectionState.connecting:
        return 'Connecting...';
      case DeviceConnectionState.disconnecting:
        return 'Disconnecting...';
      case DeviceConnectionState.disconnected:
        return 'Disconnected';
    }
  }

  ConnectionStatus copyWith({
    DeviceConnectionState? state,
    String? deviceName,
    int? rssi,
    DateTime? lastSyncTime,
  }) {
    return ConnectionStatus(
      state: state ?? this.state,
      deviceName: deviceName ?? this.deviceName,
      rssi: rssi ?? this.rssi,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

/// Device battery telemetry.
class BatteryData {
  final int percentage;
  final bool isCharging;
  final String estimatedRemaining;
  final bool isAvailable;

  const BatteryData({
    required this.percentage,
    required this.isCharging,
    required this.estimatedRemaining,
    this.isAvailable = true,
  });

  factory BatteryData.unavailable() => const BatteryData(
    percentage: 0,
    isCharging: false,
    estimatedRemaining: 'Unavailable',
    isAvailable: false,
  );

  bool get isLow => isAvailable && percentage <= 20;

  BatteryData copyWith({
    int? percentage,
    bool? isCharging,
    String? estimatedRemaining,
    bool? isAvailable,
  }) {
    return BatteryData(
      percentage: percentage ?? this.percentage,
      isCharging: isCharging ?? this.isCharging,
      estimatedRemaining: estimatedRemaining ?? this.estimatedRemaining,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

/// A single discrete graph point for sparklines and detail charts.
class ChartDataPoint {
  final double x; // e.g. hour 0..24 or day index
  final double y; // value
  final String label;

  const ChartDataPoint({required this.x, required this.y, this.label = ''});
}

/// Heart rate sensor readings and historical curves.
class HeartRateData {
  final int currentBpm;
  final int restingBpm;
  final int minToday;
  final int avgToday;
  final int maxToday;
  final DateTime timestamp;
  final List<ChartDataPoint> sparkline;
  final List<ChartDataPoint> dayData;
  final List<ChartDataPoint> weekData;
  final List<ChartDataPoint> monthData;

  const HeartRateData({
    required this.currentBpm,
    required this.restingBpm,
    required this.minToday,
    required this.avgToday,
    required this.maxToday,
    required this.timestamp,
    this.sparkline = const [],
    this.dayData = const [],
    this.weekData = const [],
    this.monthData = const [],
  });

  factory HeartRateData.empty() => HeartRateData(
    currentBpm: 0,
    restingBpm: 0,
    minToday: 0,
    avgToday: 0,
    maxToday: 0,
    timestamp: DateTime.now(),
    sparkline: const [],
    dayData: const [],
    weekData: const [],
    monthData: const [],
  );

  String get statusLabel {
    if (currentBpm == 0) return 'No Data';
    if (currentBpm < 55) return 'Low';
    if (currentBpm <= 100) return 'Normal';
    return 'Elevated';
  }

  HeartRateData copyWith({
    int? currentBpm,
    int? restingBpm,
    int? minToday,
    int? avgToday,
    int? maxToday,
    DateTime? timestamp,
    List<ChartDataPoint>? sparkline,
    List<ChartDataPoint>? dayData,
    List<ChartDataPoint>? weekData,
    List<ChartDataPoint>? monthData,
  }) {
    return HeartRateData(
      currentBpm: currentBpm ?? this.currentBpm,
      restingBpm: restingBpm ?? this.restingBpm,
      minToday: minToday ?? this.minToday,
      avgToday: avgToday ?? this.avgToday,
      maxToday: maxToday ?? this.maxToday,
      timestamp: timestamp ?? this.timestamp,
      sparkline: sparkline ?? this.sparkline,
      dayData: dayData ?? this.dayData,
      weekData: weekData ?? this.weekData,
      monthData: monthData ?? this.monthData,
    );
  }
}

/// Blood oxygen saturation (SpO2) readings and curves.
class Spo2Data {
  final int percentage;
  final int minToday;
  final int avgToday;
  final int maxToday;
  final DateTime timestamp;
  final List<ChartDataPoint> sparkline;
  final List<ChartDataPoint> dayData;
  final List<ChartDataPoint> weekData;
  final List<ChartDataPoint> monthData;

  const Spo2Data({
    required this.percentage,
    this.minToday = 96,
    this.avgToday = 98,
    this.maxToday = 99,
    required this.timestamp,
    this.sparkline = const [],
    this.dayData = const [],
    this.weekData = const [],
    this.monthData = const [],
  });

  factory Spo2Data.empty() => Spo2Data(
    percentage: 0,
    minToday: 0,
    avgToday: 0,
    maxToday: 0,
    timestamp: DateTime.now(),
    sparkline: const [],
    dayData: const [],
    weekData: const [],
    monthData: const [],
  );

  String get statusLabel {
    if (percentage == 0) return 'No Data';
    if (percentage >= 95) return 'Normal';
    if (percentage >= 90) return 'Acceptable';
    return 'Low';
  }

  Spo2Data copyWith({
    int? percentage,
    int? minToday,
    int? avgToday,
    int? maxToday,
    DateTime? timestamp,
    List<ChartDataPoint>? sparkline,
    List<ChartDataPoint>? dayData,
    List<ChartDataPoint>? weekData,
    List<ChartDataPoint>? monthData,
  }) {
    return Spo2Data(
      percentage: percentage ?? this.percentage,
      minToday: minToday ?? this.minToday,
      avgToday: avgToday ?? this.avgToday,
      maxToday: maxToday ?? this.maxToday,
      timestamp: timestamp ?? this.timestamp,
      sparkline: sparkline ?? this.sparkline,
      dayData: dayData ?? this.dayData,
      weekData: weekData ?? this.weekData,
      monthData: monthData ?? this.monthData,
    );
  }
}

/// Posture orientation states.
enum PostureClassification { upright, slouching, leaning, inactive }

/// Posture telemetry from device IMU/accelerometer.
class PostureData {
  final PostureClassification classification;
  final double tiltDegrees;
  final int postureScoreToday;
  final Duration goodPostureTime;
  final DateTime timestamp;

  final List<ChartDataPoint> sparkline;
  final List<ChartDataPoint> dayData;
  final List<ChartDataPoint> weekData;
  final List<ChartDataPoint> monthData;
  final int minToday;
  final int avgToday;
  final int maxToday;

  const PostureData({
    required this.classification,
    required this.tiltDegrees,
    required this.postureScoreToday,
    required this.goodPostureTime,
    required this.timestamp,
    this.sparkline = const [],
    this.dayData = const [],
    this.weekData = const [],
    this.monthData = const [],
    this.minToday = 0,
    this.avgToday = 0,
    this.maxToday = 0,
  });

  String get classificationLabel {
    switch (classification) {
      case PostureClassification.upright:
        return 'Good';
      case PostureClassification.slouching:
        return 'Bad posture';
      case PostureClassification.leaning:
        return 'Leaning';
      case PostureClassification.inactive:
        return 'Resting';
    }
  }

  String get subLabel {
    switch (classification) {
      case PostureClassification.upright:
        return 'Upright';
      case PostureClassification.slouching:
        return 'Slouching';
      case PostureClassification.leaning:
        return 'Tilted';
      case PostureClassification.inactive:
        return 'Sedentary';
    }
  }

  bool get isGood => classification == PostureClassification.upright;
  bool get isSlouching => classification == PostureClassification.slouching;

  PostureData copyWith({
    PostureClassification? classification,
    double? tiltDegrees,
    int? postureScoreToday,
    Duration? goodPostureTime,
    DateTime? timestamp,
    List<ChartDataPoint>? sparkline,
    List<ChartDataPoint>? dayData,
    List<ChartDataPoint>? weekData,
    List<ChartDataPoint>? monthData,
    int? minToday,
    int? avgToday,
    int? maxToday,
  }) {
    return PostureData(
      classification: classification ?? this.classification,
      tiltDegrees: tiltDegrees ?? this.tiltDegrees,
      postureScoreToday: postureScoreToday ?? this.postureScoreToday,
      goodPostureTime: goodPostureTime ?? this.goodPostureTime,
      timestamp: timestamp ?? this.timestamp,
      sparkline: sparkline ?? this.sparkline,
      dayData: dayData ?? this.dayData,
      weekData: weekData ?? this.weekData,
      monthData: monthData ?? this.monthData,
      minToday: minToday ?? this.minToday,
      avgToday: avgToday ?? this.avgToday,
      maxToday: maxToday ?? this.maxToday,
    );
  }
}

/// Activity & movement metrics.
class ActivityData {
  final int steps;
  final int stepGoal;
  final double distanceKm;
  final int caloriesKcal;
  final int activeMinutes;
  final String currentMovementState;
  final DateTime timestamp;
  final List<ChartDataPoint> hourlyBars;
  final List<ChartDataPoint> weeklyBars;
  final List<ChartDataPoint> monthlyBars;

  const ActivityData({
    required this.steps,
    required this.stepGoal,
    required this.distanceKm,
    required this.caloriesKcal,
    required this.activeMinutes,
    required this.currentMovementState,
    required this.timestamp,
    this.hourlyBars = const [],
    this.weeklyBars = const [],
    this.monthlyBars = const [],
  });

  factory ActivityData.empty() => ActivityData(
    steps: 0,
    stepGoal: 5000,
    distanceKm: 0.0,
    caloriesKcal: 0,
    activeMinutes: 0,
    currentMovementState: 'Resting',
    timestamp: DateTime.now(),
    hourlyBars: const [],
    weeklyBars: const [],
    monthlyBars: const [],
  );

  double get goalProgress => (steps / stepGoal).clamp(0.0, 1.0);

  ActivityData copyWith({
    int? steps,
    int? stepGoal,
    double? distanceKm,
    int? caloriesKcal,
    int? activeMinutes,
    String? currentMovementState,
    DateTime? timestamp,
    List<ChartDataPoint>? hourlyBars,
    List<ChartDataPoint>? weeklyBars,
    List<ChartDataPoint>? monthlyBars,
  }) {
    return ActivityData(
      steps: steps ?? this.steps,
      stepGoal: stepGoal ?? this.stepGoal,
      distanceKm: distanceKm ?? this.distanceKm,
      caloriesKcal: caloriesKcal ?? this.caloriesKcal,
      activeMinutes: activeMinutes ?? this.activeMinutes,
      currentMovementState: currentMovementState ?? this.currentMovementState,
      timestamp: timestamp ?? this.timestamp,
      hourlyBars: hourlyBars ?? this.hourlyBars,
      weeklyBars: weeklyBars ?? this.weeklyBars,
      monthlyBars: monthlyBars ?? this.monthlyBars,
    );
  }
}

/// Hardware & firmware information for HealthDevice.
class DeviceInfo {
  final String name;
  final String model;
  final String hardwareRevision;
  final String firmwareVersion;
  final String macAddress;
  final bool isCalibrated;
  final DateTime? pairedAt;

  const DeviceInfo({
    required this.name,
    required this.model,
    required this.hardwareRevision,
    required this.firmwareVersion,
    required this.macAddress,
    required this.isCalibrated,
    this.pairedAt,
  });

  DeviceInfo copyWith({
    String? name,
    String? model,
    String? hardwareRevision,
    String? firmwareVersion,
    String? macAddress,
    bool? isCalibrated,
    DateTime? pairedAt,
  }) {
    return DeviceInfo(
      name: name ?? this.name,
      model: model ?? this.model,
      hardwareRevision: hardwareRevision ?? this.hardwareRevision,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      macAddress: macAddress ?? this.macAddress,
      isCalibrated: isCalibrated ?? this.isCalibrated,
      pairedAt: pairedAt ?? this.pairedAt,
    );
  }
}

/// History log entry for timeline and events feed.
class HistoryEntry {
  final String id;
  final DateTime timestamp;
  final String title;
  final String category; // 'Heart Rate', 'SpO2', 'Posture', 'Activity'
  final String valueDisplay;
  final String unit;
  final String status;
  final String detail;
  final String section; // 'Today' or 'Yesterday' or date label

  const HistoryEntry({
    required this.id,
    required this.timestamp,
    required this.title,
    required this.category,
    required this.valueDisplay,
    required this.unit,
    required this.status,
    required this.detail,
    this.section = 'Today',
  });
}

/// Represents physical 4-pin RGB LED PWM values (0–255).
/// Normal RGB values are used; hardware layer handles any pin inversion.
class RgbColor {
  final int red;
  final int green;
  final int blue;

  int get r => red;
  int get g => green;
  int get b => blue;

  const RgbColor({required this.red, required this.green, required this.blue});

  const RgbColor.cyan() : red = 0, green = 229, blue = 255;
  const RgbColor.blue() : red = 13, green = 110, blue = 253;
  const RgbColor.green() : red = 16, green = 185, blue = 129;
  const RgbColor.orange() : red = 255, green = 145, blue = 0;
  const RgbColor.purple() : red = 168, green = 85, blue = 247;
  const RgbColor.redColor() : red = 239, green = 68, blue = 68;

  factory RgbColor.fromColor(Color color) {
    final argb = color.toARGB32();
    return RgbColor(
      red: (argb >> 16) & 0xFF,
      green: (argb >> 8) & 0xFF,
      blue: argb & 0xFF,
    );
  }

  Color toColor() {
    return Color.fromARGB(
      255,
      red.clamp(0, 255),
      green.clamp(0, 255),
      blue.clamp(0, 255),
    );
  }

  String toHexString({bool includeHash = true}) {
    final r = red.clamp(0, 255).toRadixString(16).padLeft(2, '0').toUpperCase();
    final g = green
        .clamp(0, 255)
        .toRadixString(16)
        .padLeft(2, '0')
        .toUpperCase();
    final b = blue
        .clamp(0, 255)
        .toRadixString(16)
        .padLeft(2, '0')
        .toUpperCase();
    return includeHash ? '#$r$g$b' : '$r$g$b';
  }

  RgbColor copyWith({int? red, int? green, int? blue}) {
    return RgbColor(
      red: red ?? this.red,
      green: green ?? this.green,
      blue: blue ?? this.blue,
    );
  }

  Map<String, dynamic> toJson() => {'red': red, 'green': green, 'blue': blue};

  factory RgbColor.fromJson(Map<String, dynamic> json) => RgbColor(
    red: (json['red'] as num?)?.toInt() ?? 0,
    green: (json['green'] as num?)?.toInt() ?? 0,
    blue: (json['blue'] as num?)?.toInt() ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RgbColor &&
          runtimeType == other.runtimeType &&
          red == other.red &&
          green == other.green &&
          blue == other.blue;

  @override
  int get hashCode => red.hashCode ^ green.hashCode ^ blue.hashCode;
}

/// An individual LED event configuration item for general LED settings.
/// (Alarms and Reminders are configured exclusively in their respective screens)
class LedEventConfig {
  final String id;
  final String eventName;
  final RgbColor rgbColor;
  final String description;

  const LedEventConfig({
    required this.id,
    required this.eventName,
    required this.rgbColor,
    this.description = '',
  });

  Color get color => rgbColor.toColor();

  LedEventConfig copyWith({
    String? id,
    String? eventName,
    RgbColor? rgbColor,
    Color? color,
    String? description,
  }) {
    return LedEventConfig(
      id: id ?? this.id,
      eventName: eventName ?? this.eventName,
      rgbColor:
          rgbColor ??
          (color != null ? RgbColor.fromColor(color) : this.rgbColor),
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'eventName': eventName,
    'rgbColor': rgbColor.toJson(),
    'description': description,
  };

  factory LedEventConfig.fromJson(Map<String, dynamic> json) => LedEventConfig(
    id: json['id'] as String,
    eventName: json['eventName'] as String,
    rgbColor: RgbColor.fromJson(json['rgbColor'] as Map<String, dynamic>),
    description: (json['description'] as String?) ?? '',
  );
}

/// Overall LED Settings configuration.
class LedSettingsState {
  final bool isEnabled;
  final List<LedEventConfig> eventConfigs;

  const LedSettingsState({required this.isEnabled, required this.eventConfigs});

  LedSettingsState copyWith({
    bool? isEnabled,
    List<LedEventConfig>? eventConfigs,
  }) {
    return LedSettingsState(
      isEnabled: isEnabled ?? this.isEnabled,
      eventConfigs: eventConfigs ?? this.eventConfigs,
    );
  }

  Map<String, dynamic> toJson() => {
    'isEnabled': isEnabled,
    'eventConfigs': eventConfigs.map((e) => e.toJson()).toList(),
  };

  factory LedSettingsState.fromJson(Map<String, dynamic> json) =>
      LedSettingsState(
        isEnabled: (json['isEnabled'] as bool?) ?? true,
        eventConfigs:
            (json['eventConfigs'] as List<dynamic>?)
                ?.map((e) => LedEventConfig.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// Alarm data model with custom RGB LED color, repeat days, and sound control.
class AlarmItem {
  final String id;
  final String name;
  final String time; // e.g. "07:30 AM"
  final bool enabled;
  final List<String> repeatDays; // ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']
  final bool soundEnabled;
  final RgbColor ledColor;

  const AlarmItem({
    required this.id,
    required this.name,
    required this.time,
    this.enabled = true,
    this.repeatDays = const [],
    this.soundEnabled = true,
    required this.ledColor,
  });

  AlarmItem copyWith({
    String? id,
    String? name,
    String? time,
    bool? enabled,
    List<String>? repeatDays,
    bool? soundEnabled,
    RgbColor? ledColor,
  }) {
    return AlarmItem(
      id: id ?? this.id,
      name: name ?? this.name,
      time: time ?? this.time,
      enabled: enabled ?? this.enabled,
      repeatDays: repeatDays ?? this.repeatDays,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      ledColor: ledColor ?? this.ledColor,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'time': time,
    'enabled': enabled,
    'repeatDays': repeatDays,
    'soundEnabled': soundEnabled,
    'ledColor': ledColor.toJson(),
  };

  factory AlarmItem.fromJson(Map<String, dynamic> json) => AlarmItem(
    id: json['id'] as String,
    name: json['name'] as String,
    time: json['time'] as String,
    enabled: (json['enabled'] as bool?) ?? true,
    repeatDays:
        (json['repeatDays'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    soundEnabled: (json['soundEnabled'] as bool?) ?? true,
    ledColor: RgbColor.fromJson(json['ledColor'] as Map<String, dynamic>),
  );
}

/// Reminder data model with custom RGB LED color, schedule, and sound control.
class ReminderItem {
  final String id;
  final String name;
  final String time; // e.g. "02:00 PM"
  final bool enabled;
  final String repeatSchedule; // "Daily", "Hourly", "Weekdays", etc.
  final bool soundEnabled;
  final RgbColor ledColor;

  const ReminderItem({
    required this.id,
    required this.name,
    required this.time,
    this.enabled = true,
    this.repeatSchedule = 'Daily',
    this.soundEnabled = true,
    required this.ledColor,
  });

  ReminderItem copyWith({
    String? id,
    String? name,
    String? time,
    bool? enabled,
    String? repeatSchedule,
    bool? soundEnabled,
    RgbColor? ledColor,
  }) {
    return ReminderItem(
      id: id ?? this.id,
      name: name ?? this.name,
      time: time ?? this.time,
      enabled: enabled ?? this.enabled,
      repeatSchedule: repeatSchedule ?? this.repeatSchedule,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      ledColor: ledColor ?? this.ledColor,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'time': time,
    'enabled': enabled,
    'repeatSchedule': repeatSchedule,
    'soundEnabled': soundEnabled,
    'ledColor': ledColor.toJson(),
  };

  factory ReminderItem.fromJson(Map<String, dynamic> json) => ReminderItem(
    id: json['id'] as String,
    name: json['name'] as String,
    time: json['time'] as String,
    enabled: (json['enabled'] as bool?) ?? true,
    repeatSchedule: (json['repeatSchedule'] as String?) ?? 'Daily',
    soundEnabled: (json['soundEnabled'] as bool?) ?? true,
    ledColor: RgbColor.fromJson(json['ledColor'] as Map<String, dynamic>),
  );
}

/// Notification Settings Configuration with individual toggles.
class NotificationConfig {
  final bool alarm;
  final bool reminder;
  final bool heartRateAlert;
  final bool spo2Alert;
  final bool badPosture;
  final bool fallDetection;
  final bool lowBattery;
  final bool timer;
  final bool connection;

  const NotificationConfig({
    this.alarm = true,
    this.reminder = true,
    this.heartRateAlert = true,
    this.spo2Alert = true,
    this.badPosture = true,
    this.fallDetection = true,
    this.lowBattery = true,
    this.timer = true,
    this.connection = true,
  });

  NotificationConfig copyWith({
    bool? alarm,
    bool? reminder,
    bool? heartRateAlert,
    bool? spo2Alert,
    bool? badPosture,
    bool? fallDetection,
    bool? lowBattery,
    bool? timer,
    bool? connection,
  }) {
    return NotificationConfig(
      alarm: alarm ?? this.alarm,
      reminder: reminder ?? this.reminder,
      heartRateAlert: heartRateAlert ?? this.heartRateAlert,
      spo2Alert: spo2Alert ?? this.spo2Alert,
      badPosture: badPosture ?? this.badPosture,
      fallDetection: fallDetection ?? this.fallDetection,
      lowBattery: lowBattery ?? this.lowBattery,
      timer: timer ?? this.timer,
      connection: connection ?? this.connection,
    );
  }

  Map<String, dynamic> toJson() => {
    'alarm': alarm,
    'reminder': reminder,
    'heartRateAlert': heartRateAlert,
    'spo2Alert': spo2Alert,
    'badPosture': badPosture,
    'fallDetection': fallDetection,
    'lowBattery': lowBattery,
    'timer': timer,
    'connection': connection,
  };

  factory NotificationConfig.fromJson(Map<String, dynamic> json) =>
      NotificationConfig(
        alarm: (json['alarm'] as bool?) ?? true,
        reminder: (json['reminder'] as bool?) ?? true,
        heartRateAlert: (json['heartRateAlert'] as bool?) ?? true,
        spo2Alert: (json['spo2Alert'] as bool?) ?? true,
        badPosture: (json['badPosture'] as bool?) ?? true,
        fallDetection: (json['fallDetection'] as bool?) ?? true,
        lowBattery: (json['lowBattery'] as bool?) ?? true,
        timer: (json['timer'] as bool?) ?? true,
        connection: (json['connection'] as bool?) ?? true,
      );
}

/// Wi-Fi Network representation for ESP32 multi-network priority management
/// and nearby Wi-Fi scanning (supporting 2.4 GHz and WPA2-Personal).
class WiFiNetworkItem {
  final String id;
  final String ssid;
  final String password;
  final int priority; // 1 = highest, 2 = second, etc.
  final bool enabled;
  final String
  securityType; // "WPA2-Personal", "WPA/WPA2-Personal", "Open", "Unknown"
  final String frequency; // e.g. "2.4 GHz", "5 GHz"
  final int? rssi; // e.g. -32, -58 dBm

  const WiFiNetworkItem({
    required this.id,
    required this.ssid,
    required this.password,
    required this.priority,
    this.enabled = true,
    this.securityType = 'WPA2-Personal',
    this.frequency = '2.4 GHz',
    this.rssi,
  });

  /// Signal bars from 0 to 4 based on RSSI ranges:
  /// -30 to -50 dBm = 4 bars (Very Strong)
  /// -50 to -65 dBm = 3 bars (Strong)
  /// -65 to -75 dBm = 2 bars (Medium)
  /// -75 to -85 dBm = 1 bar (Weak)
  /// -85 to -100 dBm = 0 bars (Very Weak)
  int get signalBars {
    final val = rssi;
    if (val == null) return 3;
    if (val >= -50) return 4;
    if (val >= -65) return 3;
    if (val >= -75) return 2;
    if (val >= -85) return 1;
    return 0;
  }

  String get signalLabel {
    switch (signalBars) {
      case 4:
        return 'Very Strong';
      case 3:
        return 'Strong';
      case 2:
        return 'Medium';
      case 1:
        return 'Weak';
      case 0:
      default:
        return 'Very Weak';
    }
  }

  bool get is24GHz => frequency.contains('2.4');

  bool get isCompatible =>
      is24GHz &&
      (securityType.contains('WPA2') ||
          securityType.contains('WPA') ||
          securityType == 'Open');

  WiFiNetworkItem copyWith({
    String? id,
    String? ssid,
    String? password,
    int? priority,
    bool? enabled,
    String? securityType,
    String? frequency,
    int? rssi,
  }) {
    return WiFiNetworkItem(
      id: id ?? this.id,
      ssid: ssid ?? this.ssid,
      password: password ?? this.password,
      priority: priority ?? this.priority,
      enabled: enabled ?? this.enabled,
      securityType: securityType ?? this.securityType,
      frequency: frequency ?? this.frequency,
      rssi: rssi ?? this.rssi,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ssid': ssid,
    'name': ssid,
    'password': password,
    'priority': priority,
    'enabled': enabled,
    'securityType': securityType,
    'frequency': frequency,
    'rssi': rssi,
  };

  factory WiFiNetworkItem.fromJson(Map<String, dynamic> json) {
    final rawSsid = json['ssid'] ?? json['name'] ?? json['networkName'];
    final cleanSsid = rawSsid != null ? rawSsid.toString().trim() : '';

    return WiFiNetworkItem(
      id:
          (json['id'] as String?) ??
          'wifi_${DateTime.now().millisecondsSinceEpoch}',
      ssid: cleanSsid,
      password: (json['password'] as String?) ?? '',
      priority: (json['priority'] as num?)?.toInt() ?? 1,
      enabled: (json['enabled'] as bool?) ?? true,
      securityType: (json['securityType'] as String?) ?? 'WPA2-Personal',
      frequency: (json['frequency'] as String?) ?? '2.4 GHz',
      rssi: (json['rssi'] as num?)?.toInt(),
    );
  }
}

typedef WiFiNetwork = WiFiNetworkItem;

/// Wi-Fi state of the device.
class WiFiState {
  final String? connectedSsid;
  final bool isConnected;
  final String? ipAddress;
  final List<WiFiNetworkItem> savedNetworks;
  final List<WiFiNetworkItem> scannedNetworks;
  final bool isScanning;
  final String? scanError;

  const WiFiState({
    this.connectedSsid,
    required this.isConnected,
    this.ipAddress,
    this.savedNetworks = const [],
    this.scannedNetworks = const [],
    this.isScanning = false,
    this.scanError,
  });

  WiFiState copyWith({
    String? connectedSsid,
    bool? isConnected,
    String? ipAddress,
    List<WiFiNetworkItem>? savedNetworks,
    List<WiFiNetworkItem>? scannedNetworks,
    bool? isScanning,
    String? scanError,
  }) {
    return WiFiState(
      connectedSsid: connectedSsid ?? this.connectedSsid,
      isConnected: isConnected ?? this.isConnected,
      ipAddress: ipAddress ?? this.ipAddress,
      savedNetworks: savedNetworks ?? this.savedNetworks,
      scannedNetworks: scannedNetworks ?? this.scannedNetworks,
      isScanning: isScanning ?? this.isScanning,
      scanError: scanError,
    );
  }
}

/// Sound & Haptics settings mirroring ESP32 settings.h
class SoundSettings {
  final bool soundEnabled;
  final int volumePct; // 0 to 100
  final bool dndEnabled;
  final bool clickSoundEnabled;
  final bool measurementSoundEnabled;

  const SoundSettings({
    this.soundEnabled = true,
    this.volumePct = 80,
    this.dndEnabled = false,
    this.clickSoundEnabled = true,
    this.measurementSoundEnabled = true,
  });

  SoundSettings copyWith({
    bool? soundEnabled,
    int? volumePct,
    bool? dndEnabled,
    bool? clickSoundEnabled,
    bool? measurementSoundEnabled,
  }) {
    return SoundSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      volumePct: volumePct ?? this.volumePct,
      dndEnabled: dndEnabled ?? this.dndEnabled,
      clickSoundEnabled: clickSoundEnabled ?? this.clickSoundEnabled,
      measurementSoundEnabled:
          measurementSoundEnabled ?? this.measurementSoundEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'soundEnabled': soundEnabled,
    'volumePct': volumePct,
    'dndEnabled': dndEnabled,
    'clickSoundEnabled': clickSoundEnabled,
    'measurementSoundEnabled': measurementSoundEnabled,
  };

  factory SoundSettings.fromJson(Map<String, dynamic> json) {
    return SoundSettings(
      soundEnabled: (json['soundEnabled'] as bool?) ?? true,
      volumePct: (json['volumePct'] as num?)?.toInt() ?? 80,
      dndEnabled: (json['dndEnabled'] as bool?) ?? false,
      clickSoundEnabled: (json['clickSoundEnabled'] as bool?) ?? true,
      measurementSoundEnabled:
          (json['measurementSoundEnabled'] as bool?) ?? true,
    );
  }
}

/// Display settings mirroring ESP32 OLED display settings.h
class DisplaySettings {
  final int brightnessPct; // 10 to 100
  final int screenTimeoutSec; // 10, 15, 30, 60, 0 = never
  final bool orientationFlipped; // true = 180° rotated (Left Wrist)
  final bool use24HourTime;

  const DisplaySettings({
    this.brightnessPct = 85,
    this.screenTimeoutSec = 30,
    this.orientationFlipped = false,
    this.use24HourTime = true,
  });

  DisplaySettings copyWith({
    int? brightnessPct,
    int? screenTimeoutSec,
    bool? orientationFlipped,
    bool? use24HourTime,
  }) {
    return DisplaySettings(
      brightnessPct: brightnessPct ?? this.brightnessPct,
      screenTimeoutSec: screenTimeoutSec ?? this.screenTimeoutSec,
      orientationFlipped: orientationFlipped ?? this.orientationFlipped,
      use24HourTime: use24HourTime ?? this.use24HourTime,
    );
  }

  Map<String, dynamic> toJson() => {
    'brightnessPct': brightnessPct,
    'screenTimeoutSec': screenTimeoutSec,
    'orientationFlipped': orientationFlipped,
    'use24HourTime': use24HourTime,
  };

  factory DisplaySettings.fromJson(Map<String, dynamic> json) {
    return DisplaySettings(
      brightnessPct: (json['brightnessPct'] as num?)?.toInt() ?? 85,
      screenTimeoutSec: (json['screenTimeoutSec'] as num?)?.toInt() ?? 30,
      orientationFlipped: (json['orientationFlipped'] as bool?) ?? false,
      use24HourTime: (json['use24HourTime'] as bool?) ?? true,
    );
  }
}

/// Authenticated account data model.
class AuthUser {
  final String id;
  final String email;
  final String name;
  final DateTime createdAt;

  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] as String?) ?? 'user_default',
      email: (json['email'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'User',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Biological sex profile options.
enum BiologicalSex { male, female, other, preferNotToSay }

/// User Health Profile required for personalizing vitals, calorie calculations,
/// and AI health insights.
class UserHealthProfile {
  final String name;
  final DateTime? dateOfBirth;
  final double? heightCm;
  final double? weightKg;
  final String biologicalSex; // 'Male', 'Female', 'Other', 'Prefer not to say'
  final String units; // 'Metric (cm, kg)' or 'Imperial (ft, lbs)'
  final String primaryGoal; // 'General wellness', 'Fitness', 'Activity', 'Weight management', 'Posture', 'Other'
  final String avatarId; // Custom application avatar preset id

  const UserHealthProfile({
    required this.name,
    this.dateOfBirth,
    this.heightCm,
    this.weightKg,
    this.biologicalSex = 'Prefer not to say',
    this.units = 'Metric (cm, kg)',
    this.primaryGoal = 'General wellness',
    this.avatarId = 'avatar_pulse_cyan',
  });

  bool get isCompleted =>
      name.trim().isNotEmpty &&
      dateOfBirth != null &&
      heightCm != null &&
      heightCm! > 0 &&
      weightKg != null &&
      weightKg! > 0;

  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age >= 0 ? age : 0;
  }

  double? get bmi {
    if (heightCm == null || weightKg == null || heightCm! <= 0) return null;
    final heightMeters = heightCm! / 100.0;
    return weightKg! / (heightMeters * heightMeters);
  }

  String get bmiCategory {
    final value = bmi;
    if (value == null) return 'N/A';
    if (value < 18.5) return 'Underweight';
    if (value < 25.0) return 'Normal weight';
    if (value < 30.0) return 'Overweight';
    return 'Obese';
  }

  UserHealthProfile copyWith({
    String? name,
    DateTime? dateOfBirth,
    double? heightCm,
    double? weightKg,
    String? biologicalSex,
    String? units,
    String? primaryGoal,
    String? avatarId,
  }) {
    return UserHealthProfile(
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      biologicalSex: biologicalSex ?? this.biologicalSex,
      units: units ?? this.units,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      avatarId: avatarId ?? this.avatarId,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'dateOfBirth': dateOfBirth?.toIso8601String(),
    'heightCm': heightCm,
    'weightKg': weightKg,
    'biologicalSex': biologicalSex,
    'units': units,
    'primaryGoal': primaryGoal,
    'avatarId': avatarId,
  };

  factory UserHealthProfile.fromJson(Map<String, dynamic> json) {
    return UserHealthProfile(
      name: (json['name'] as String?) ?? '',
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'] as String)
          : null,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      biologicalSex: (json['biologicalSex'] as String?) ?? 'Prefer not to say',
      units: (json['units'] as String?) ?? 'Metric (cm, kg)',
      primaryGoal: (json['primaryGoal'] as String?) ?? 'General wellness',
      avatarId: (json['avatarId'] as String?) ?? 'avatar_pulse_cyan',
    );
  }
}

/// AI assistant message data model.
class AiChatMessage {
  final String id;
  final bool isUser;
  final String text;
  final DateTime timestamp;
  final bool isError;
  final List<String> quickPrompts;

  const AiChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.isError = false,
    this.quickPrompts = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'isUser': isUser,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'isError': isError,
        'quickPrompts': quickPrompts,
      };

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    return AiChatMessage(
      id: (json['id'] as String?) ??
          'msg_${DateTime.now().millisecondsSinceEpoch}',
      isUser: (json['isUser'] as bool?) ?? false,
      text: (json['text'] as String?) ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isError: (json['isError'] as bool?) ?? false,
      quickPrompts: (json['quickPrompts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

/// Historical record of a user question and AI answer for history assessment.
class AiChatQuestionHistoryItem {
  final String questionId;
  final String answerId;
  final String question;
  final String answer;
  final DateTime timestamp;

  const AiChatQuestionHistoryItem({
    required this.questionId,
    required this.answerId,
    required this.question,
    required this.answer,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'answerId': answerId,
        'question': question,
        'answer': answer,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AiChatQuestionHistoryItem.fromJson(Map<String, dynamic> json) =>
      AiChatQuestionHistoryItem(
        questionId: json['questionId'] as String? ?? '',
        answerId: json['answerId'] as String? ?? '',
        question: json['question'] as String? ?? '',
        answer: json['answer'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
}

