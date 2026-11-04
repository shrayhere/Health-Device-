import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Supabase configuration and service wrapper for HealthDevice.
class SupabaseService {
  SupabaseService._();

  static const String supabaseUrl =
      'https://ssupmhqrfspmezcvmgbv.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_xtCDXtgVEAlwtAgjnKnPcA_Ke0WhUyG';

  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  /// Initializes the Supabase client safely.
  /// Bypasses in unit test environments where native channels are not mocked.
  static Future<void> init() async {
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) return;

    if (_isInitialized) return;

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      _isInitialized = true;
      debugPrint('✅ Supabase initialized successfully for Health Device');
    } catch (e) {
      debugPrint('⚠️ Supabase initialization warning: $e');
    }
  }

  /// Returns the active SupabaseClient if initialized, null otherwise.
  static SupabaseClient? get client {
    if (!_isInitialized) return null;
    return Supabase.instance.client;
  }
}
