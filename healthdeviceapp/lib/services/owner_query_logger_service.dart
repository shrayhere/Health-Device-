import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/health_metrics.dart';
import 'ai_service.dart';
import 'settings_storage_service.dart';

/// Service responsible for securely logging AI queries and answers for the
/// app owner to Google Sheets Webhook and persistent diagnostics.
class OwnerQueryLoggerService {
  static final OwnerQueryLoggerService instance = OwnerQueryLoggerService._internal();

  OwnerQueryLoggerService._internal();

  final SettingsStorageService _storage = SettingsStorageService();

  /// Pre-configured embedded webhook URL for the app owner's Google Spreadsheet
  static const String defaultWebhookUrl =
      'https://script.google.com/macros/s/AKfycbyQidsjCr7jxkBHThTGEwtgR_vOflfMCYf9bIuQ9SThrUkH_uWx1fgMTLD325WIcQT0/exec';

  // In-memory buffer of recent queries for preview / diagnostics
  final List<Map<String, dynamic>> _recentQueries = [];

  List<Map<String, dynamic>> get recentQueries => List.unmodifiable(_recentQueries);

  /// Default or configured Google Sheets Web App Webhook URL
  String? get webhookUrl {
    final stored = _storage.getOwnerWebhookUrl();
    if (stored != null && stored.trim().isNotEmpty) {
      return stored.trim();
    }
    return defaultWebhookUrl;
  }

  /// Whether owner query logging is active
  bool get isLoggingEnabled {
    return _storage.isOwnerLoggingEnabled();
  }

  Future<void> setWebhookUrl(String? url) async {
    await _storage.saveOwnerWebhookUrl(url);
  }

  Future<void> setLoggingEnabled(bool enabled) async {
    await _storage.setOwnerLoggingEnabled(enabled);
  }

  /// Dispatches the user query and metadata to Google Sheets.
  /// Non-blocking fire-and-forget: will not delay the user or AI response.
  void logQuery({
    required String query,
    required String response,
    required AiHealthContext context,
    required String activeEngine,
  }) {
    if (!isLoggingEnabled) return;

    // Do not run during automated flutter test runs
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) return;

    // Run asynchronously in background
    Future.microtask(() async {
      final now = DateTime.now();
      final platformName = kIsWeb
          ? 'Web'
          : Platform.isAndroid
              ? 'Android'
              : Platform.isWindows
                  ? 'Windows'
                  : Platform.isIOS
                      ? 'iOS'
                      : Platform.isMacOS
                          ? 'macOS'
                          : 'Desktop';

      final vitalsText = context.currentBpm > 0
          ? 'HR: ${context.currentBpm} bpm, SpO2: ${context.currentSpo2}%, Posture: ${context.postureClassification}, Steps: ${context.stepsToday}'
          : 'Sensor resting/off-wrist, Steps: ${context.stepsToday}';

      final singleLineReply = response
          .replaceAll(RegExp(r'\r?\n+'), ' ')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .replaceAll('*', '')
          .replaceAll('#', '')
          .trim();

      final cleanQuery = query
          .replaceAll(RegExp(r'\r?\n+'), ' ')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();

      final logEntry = {
        'timestamp': now.toIso8601String(),
        'timestampReadable':
            '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)} ${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}',
        'userName': context.userName,
        'userAge': context.userAge?.toString() ?? 'N/A',
        'goal': context.primaryGoal,
        'query': cleanQuery,
        'replySnippet': singleLineReply.length > 250
            ? '${singleLineReply.substring(0, 250)}...'
            : singleLineReply,
        'platform': platformName,
        'vitals': vitalsText,
        'engine': activeEngine,
      };

      // Add to local preview buffer (keep max 100)
      _recentQueries.insert(0, logEntry);
      if (_recentQueries.length > 100) {
        _recentQueries.removeLast();
      }

      // Post to Google Sheets Webhook
      final url = webhookUrl;
      if (url != null && url.isNotEmpty) {
        await _postToGoogleSheets(url, logEntry);
      }
    });
  }

  /// Sends a test ping to verify Google Sheets Webhook connectivity
  Future<bool> sendTestPing(String url) async {
    final now = DateTime.now();
    final testData = {
      'timestamp': now.toIso8601String(),
      'timestampReadable':
          '${now.year}-${_twoDigits(now.month)}-${_twoDigits(now.day)} ${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:${_twoDigits(now.second)}',
      'userName': 'Owner Test',
      'userAge': 'N/A',
      'goal': 'System Verification',
      'query': 'Ping from HealthDevice App Owner Panel',
      'replySnippet':
          'Connection verified successfully! Google Sheets logger is active.',
      'platform': kIsWeb ? 'Web' : Platform.operatingSystem,
      'vitals': 'All Systems Operational',
      'engine': 'Diagnostics',
    };

    return await _postToGoogleSheets(url, testData);
  }

  /// Posts data to Google Sheets Webhook, properly handling 301/302/307 redirects
  Future<bool> _postToGoogleSheets(String url, Map<String, dynamic> data) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      Uri currentUri = Uri.parse(url);
      int redirects = 0;

      final req = await client.postUrl(currentUri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(data));
      HttpClientResponse response = await req.close();

      while ((response.statusCode == 301 ||
              response.statusCode == 302 ||
              response.statusCode == 307) &&
          redirects < 5) {
        redirects++;
        final loc = response.headers.value(HttpHeaders.locationHeader);
        if (loc == null) break;
        currentUri = currentUri.resolve(loc);
        final getReq = await client.getUrl(currentUri);
        response = await getReq.close();
      }

      final success = response.statusCode == 200;
      client.close();
      return success;
    } catch (e) {
      debugPrint('[OwnerQueryLogger] Google Sheets webhook error: $e');
      return false;
    }
  }

  static String _twoDigits(int n) => n >= 10 ? '$n' : '0$n';
}
