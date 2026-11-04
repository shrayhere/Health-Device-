import 'dart:convert';
import 'dart:io';

/// Local persistence service managing device configuration, alarms, reminders,
/// notifications, Wi-Fi networks, and LED preferences using pure Dart JSON file storage.
/// This requires zero native plugins, eliminates symlink requirements,
/// and works uniformly across Android, Windows, and unit tests.
class SettingsStorageService {
  static final SettingsStorageService _instance =
      SettingsStorageService._internal();
  factory SettingsStorageService() => _instance;
  SettingsStorageService._internal();

  static const String _keyDeviceName = 'hd_device_name';
  static const String _keyLedSettings = 'hd_led_settings';
  static const String _keyAlarms = 'hd_alarms';
  static const String _keyReminders = 'hd_reminders';
  static const String _keyNotifications = 'hd_notifications';
  static const String _keyWiFiNetworks = 'hd_wifi_networks';
  static const String _keySoundSettings = 'hd_sound_settings';
  static const String _keyDisplaySettings = 'hd_display_settings';
  static const String _keyAuthUser = 'hd_auth_user';
  static const String _keyHealthProfile = 'hd_health_profile';
  static const String _keyAiChatHistory = 'hd_ai_chat_history';
  static const String _keyRegisteredUsers = 'hd_registered_users';

  File? _file;
  Map<String, dynamic> _cache = {};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      _file = _resolveStorageFile();
      if (_file != null && await _file!.exists()) {
        final content = await _file!.readAsString();
        if (content.trim().isNotEmpty) {
          _cache = Map<String, dynamic>.from(jsonDecode(content) as Map);
        }
      }
      _initialized = true;
    } catch (_) {
      // In tests or restricted sandboxes, gracefully retain in-memory cache
      _cache = {};
      _initialized = true;
    }
  }

  File? _resolveStorageFile() {
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        return null;
      }
      if (Platform.isAndroid) {
        final candidatePaths = [
          '/data/data/com.example.healthdeviceapp/files',
          '/data/user/0/com.example.healthdeviceapp/files',
        ];
        for (final p in candidatePaths) {
          try {
            final dir = Directory(p);
            if (!dir.existsSync()) {
              dir.createSync(recursive: true);
            }
            return File('$p/settings_store.json');
          } catch (_) {}
        }
        final temp = Directory.systemTemp;
        return File('${temp.path}/settings_store.json');
      } else if (Platform.isWindows) {
        final localAppData =
            Platform.environment['LOCALAPPDATA'] ??
            Platform.environment['APPDATA'] ??
            '.';
        final dirPath = '$localAppData/HealthDeviceApp';
        final dir = Directory(dirPath);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        return File('$dirPath/settings_store.json');
      } else {
        final temp = Directory.systemTemp;
        return File('${temp.path}/hd_settings.json');
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> _flush() async {
    try {
      if (_file != null) {
        await _file!
            .writeAsString(jsonEncode(_cache), flush: true)
            .timeout(const Duration(milliseconds: 500));
      }
    } catch (_) {
      // Retain in-memory
    }
  }

  // --- Device Name ---
  String? getDeviceName() {
    return _cache[_keyDeviceName] as String?;
  }

  Future<void> saveDeviceName(String name) async {
    _cache[_keyDeviceName] = name;
    await _flush();
  }

  // --- LED Settings ---
  Map<String, dynamic>? getLedSettings() {
    final raw = _cache[_keyLedSettings];
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(raw as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLedSettings(Map<String, dynamic> data) async {
    _cache[_keyLedSettings] = data;
    await _flush();
  }

  // --- Alarms ---
  List<Map<String, dynamic>>? getAlarms() {
    final raw = _cache[_keyAlarms];
    if (raw == null) return null;
    try {
      final list = raw as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAlarms(List<Map<String, dynamic>> data) async {
    _cache[_keyAlarms] = data;
    await _flush();
  }

  // --- Reminders ---
  List<Map<String, dynamic>>? getReminders() {
    final raw = _cache[_keyReminders];
    if (raw == null) return null;
    try {
      final list = raw as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveReminders(List<Map<String, dynamic>> data) async {
    _cache[_keyReminders] = data;
    await _flush();
  }

  // --- Notifications ---
  Map<String, dynamic>? getNotifications() {
    final raw = _cache[_keyNotifications];
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(raw as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveNotifications(Map<String, dynamic> data) async {
    _cache[_keyNotifications] = data;
    await _flush();
  }

  // --- Wi-Fi Networks ---
  List<Map<String, dynamic>>? getWiFiNetworks() {
    final raw = _cache[_keyWiFiNetworks];
    if (raw == null) return null;
    try {
      final list = raw as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveWiFiNetworks(List<Map<String, dynamic>> data) async {
    _cache[_keyWiFiNetworks] = data;
    await _flush();
  }

  // --- Sound Settings ---
  Map<String, dynamic>? getSoundSettings() {
    final raw = _cache[_keySoundSettings];
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(raw as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSoundSettings(Map<String, dynamic> data) async {
    _cache[_keySoundSettings] = data;
    await _flush();
  }

  // --- Display Settings ---
  Map<String, dynamic>? getDisplaySettings() {
    final raw = _cache[_keyDisplaySettings];
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(raw as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDisplaySettings(Map<String, dynamic> data) async {
    _cache[_keyDisplaySettings] = data;
    await _flush();
  }

  // --- Auth User Session ---
  Map<String, dynamic>? getAuthUser() {
    final raw = _cache[_keyAuthUser];
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(raw as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveAuthUser(Map<String, dynamic>? data) async {
    if (data == null) {
      _cache.remove(_keyAuthUser);
    } else {
      _cache[_keyAuthUser] = data;
    }
    await _flush();
  }

  // --- Health Profile ---
  Map<String, dynamic>? getHealthProfile() {
    final raw = _cache[_keyHealthProfile];
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(raw as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveHealthProfile(Map<String, dynamic>? data) async {
    if (data == null) {
      _cache.remove(_keyHealthProfile);
    } else {
      _cache[_keyHealthProfile] = data;
    }
    await _flush();
  }

  // --- Groq / AI API Key ---
  static const String _keyGroqApiKey = 'hd_groq_api_key';

  String? getGroqApiKey() {
    return _cache[_keyGroqApiKey] as String?;
  }

  Future<void> saveGroqApiKey(String? key) async {
    if (key == null || key.trim().isEmpty) {
      _cache.remove(_keyGroqApiKey);
    } else {
      _cache[_keyGroqApiKey] = key.trim();
    }
    await _flush();
  }

  // --- AI Chat & Question History ---
  static const String _keyAiQuestionHistory = 'hd_ai_question_history';

  List<Map<String, dynamic>> getAiChatHistory() {
    final raw = _cache[_keyAiChatHistory];
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<void> saveAiChatHistory(List<Map<String, dynamic>> messages) async {
    _cache[_keyAiChatHistory] = messages;
    await _flush();
  }

  List<Map<String, dynamic>> getAiQuestionHistory() {
    final raw = _cache[_keyAiQuestionHistory];
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<void> saveAiQuestionHistory(List<Map<String, dynamic>> items) async {
    _cache[_keyAiQuestionHistory] = items;
    await _flush();
  }

  Future<void> clearAiChatHistory() async {
    _cache.remove(_keyAiChatHistory);
    _cache.remove(_keyAiQuestionHistory);
    await _flush();
  }

  // --- Registered Users Persistence ---
  Map<String, dynamic> getRegisteredUsers() {
    final raw = _cache[_keyRegisteredUsers];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return {};
  }

  Future<void> saveRegisteredUsers(Map<String, dynamic> users) async {
    _cache[_keyRegisteredUsers] = users;
    await _flush();
  }

  // --- Owner Google Sheets Webhook ---
  static const String _keyOwnerWebhookUrl = 'owner_google_sheets_webhook_url';
  static const String _keyOwnerLoggingEnabled = 'owner_query_logging_enabled';

  String? getOwnerWebhookUrl() {
    return _cache[_keyOwnerWebhookUrl] as String?;
  }

  Future<void> saveOwnerWebhookUrl(String? url) async {
    if (url == null || url.trim().isEmpty) {
      _cache.remove(_keyOwnerWebhookUrl);
    } else {
      _cache[_keyOwnerWebhookUrl] = url.trim();
    }
    await _flush();
  }

  bool isOwnerLoggingEnabled() {
    return _cache[_keyOwnerLoggingEnabled] as bool? ?? true;
  }

  Future<void> setOwnerLoggingEnabled(bool enabled) async {
    _cache[_keyOwnerLoggingEnabled] = enabled;
    await _flush();
  }
}
