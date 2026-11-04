import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/health_metrics.dart';
import '../services/ai_service.dart';
import '../services/supabase_service.dart';

/// Cloud synchronization service for AI chat conversations and question history.
/// Uses Supabase REST API with anonymous key authentication so that conversations
/// synchronize across Windows and Android devices without requiring persistent
/// user auth tokens or manual sign-ins.
class AiChatCloudSyncService {
  AiChatCloudSyncService._();
  static final AiChatCloudSyncService instance = AiChatCloudSyncService._();

  String _formatDeviceId(String email) => 'ai_chat:${email.trim().toLowerCase()}';

  /// Fetches the latest chat and question history snapshot from Supabase Cloud.
  Future<Map<String, dynamic>?> fetchSnapshot(String email) async {
    if (email.trim().isEmpty) return null;
    final deviceId = _formatDeviceId(email);

    try {
      final client = HttpClient();
      final uri = Uri.parse(
        '${SupabaseService.supabaseUrl}/rest/v1/health_readings?device_id=eq.$deviceId&type=eq.ai_chat_snapshot&order=id.desc&limit=1',
      );
      final req = await client.getUrl(uri);
      req.headers.set('apikey', SupabaseService.supabaseAnonKey);
      req.headers.set(
        'Authorization',
        'Bearer ${SupabaseService.supabaseAnonKey}',
      );

      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        client.close();
        final list = jsonDecode(body) as List<dynamic>;
        if (list.isNotEmpty && list[0]['synced_from'] != null) {
          final payloadStr = list[0]['synced_from'] as String;
          final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
          return payload;
        }
      } else {
        client.close();
      }
    } catch (e) {
      debugPrint('[AiChatCloudSync] fetchSnapshot error: $e');
    }
    return null;
  }

  /// Pushes the current conversation and question history snapshot to Supabase Cloud.
  Future<bool> pushSnapshot({
    required String email,
    required List<AiChatMessage> messages,
    required List<AiChatQuestionHistoryItem> questions,
  }) async {
    if (email.trim().isEmpty) return false;
    final deviceId = _formatDeviceId(email);

    try {
      final payloadData = {
        'messages': messages.map((m) => m.toJson()).toList(),
        'questions': questions.map((q) => q.toJson()).toList(),
      };
      final payloadJson = jsonEncode(payloadData);

      final client = HttpClient();

      // 1. Delete previous snapshot for this user
      final delUri = Uri.parse(
        '${SupabaseService.supabaseUrl}/rest/v1/health_readings?device_id=eq.$deviceId',
      );
      final delReq = await client.deleteUrl(delUri);
      delReq.headers.set('apikey', SupabaseService.supabaseAnonKey);
      delReq.headers.set(
        'Authorization',
        'Bearer ${SupabaseService.supabaseAnonKey}',
      );
      await delReq.close();

      // 2. Insert fresh snapshot
      final postUri = Uri.parse(
        '${SupabaseService.supabaseUrl}/rest/v1/health_readings',
      );
      final postReq = await client.postUrl(postUri);
      postReq.headers.set('apikey', SupabaseService.supabaseAnonKey);
      postReq.headers.set(
        'Authorization',
        'Bearer ${SupabaseService.supabaseAnonKey}',
      );
      postReq.headers.set('Content-Type', 'application/json');

      final body = jsonEncode({
        'device_id': deviceId,
        'type': 'ai_chat_snapshot',
        'value': messages.length,
        'synced_from': payloadJson,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
      });
      final utf8Bytes = utf8.encode(body);
      postReq.contentLength = utf8Bytes.length;
      postReq.add(utf8Bytes);

      final postResp = await postReq.close();
      client.close();
      return postResp.statusCode == 200 || postResp.statusCode == 201;
    } catch (e) {
      debugPrint('[AiChatCloudSync] pushSnapshot error: $e');
      return false;
    }
  }

  /// Clears the cloud AI chat snapshot for the account.
  Future<void> clearSnapshot(String email) async {
    if (email.trim().isEmpty) return;
    final deviceId = _formatDeviceId(email);

    try {
      final client = HttpClient();
      final uri = Uri.parse(
        '${SupabaseService.supabaseUrl}/rest/v1/health_readings?device_id=eq.$deviceId',
      );
      final req = await client.deleteUrl(uri);
      req.headers.set('apikey', SupabaseService.supabaseAnonKey);
      req.headers.set(
        'Authorization',
        'Bearer ${SupabaseService.supabaseAnonKey}',
      );
      await req.close();
      client.close();
    } catch (e) {
      debugPrint('[AiChatCloudSync] clearSnapshot error: $e');
    }
  }
}
