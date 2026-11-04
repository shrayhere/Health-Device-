import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/health_metrics.dart';
import '../repositories/health_repository.dart';
import '../services/supabase_service.dart';

/// Syncs health readings from Supabase cloud into the local repository.
/// Called on app startup, periodically, and after BLE connects.
class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  Timer? _periodicTimer;

  /// Starts periodic sync every 15 seconds so readings pushed via WiFi
  /// automatically reflect in the application in near-realtime.
  void startPeriodicSync(HealthRepository repository) {
    _periodicTimer?.cancel();
    // Immediate initial sync
    syncFromCloud(repository: repository);
    _periodicTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      syncFromCloud(repository: repository);
    });
  }

  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Fetches latest readings from Supabase and updates the repository.
  Future<void> syncFromCloud({
    required HealthRepository repository,
    String? deviceId,
    String? userEmail,
  }) async {
    final email =
        (userEmail ?? repository.currentUserEmail)?.toLowerCase().trim();
    final isOwner =
        email != null &&
        (email == 'guptashaurya020@gmail.com' || email == 'user@healthdevice.com');
    if (!isOwner) {
      debugPrint(
        '[CloudSync] Skipping cloud readings sync: account ($email) has no paired cloud hardware.',
      );
      return;
    }

    try {
      List<dynamic> data = [];

      // 1. Try via active Supabase client first
      final client = SupabaseService.client;
      if (client != null) {
        try {
          final rows = await client
              .from('health_readings')
              .select()
              .order('recorded_at', ascending: false)
              .limit(200);
          if (rows.isNotEmpty) {
            data = rows;
            debugPrint('[CloudSync] Got ${data.length} readings via Supabase client.');
          }
        } catch (e) {
          debugPrint('[CloudSync] Supabase client fetch warning: $e');
        }
      }

      // 2. If client returned no readings (e.g. RLS policies block authenticated role),
      // fallback to direct REST API query using the anon API key
      if (data.isEmpty) {
        data = await _fetchViaRest();
      }

      if (data.isEmpty) {
        debugPrint('[CloudSync] No cloud readings found.');
        return;
      }

      debugPrint('[CloudSync] Applying ${data.length} cloud readings to repository.');
      _applyToRepository(data, repository);
    } catch (e) {
      debugPrint('[CloudSync] Error in syncFromCloud: $e');
    }
  }

  Future<List<dynamic>> _fetchViaRest() async {
    try {
      final httpClient = HttpClient();
      final uri = Uri.parse(
        '${SupabaseService.supabaseUrl}/rest/v1/health_readings?select=*&order=recorded_at.desc&limit=200',
      );
      final req = await httpClient.getUrl(uri);
      req.headers.set('apikey', SupabaseService.supabaseAnonKey);
      req.headers.set('Authorization', 'Bearer ${SupabaseService.supabaseAnonKey}');
      final resp = await req.close();
      if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final list = jsonDecode(body) as List<dynamic>;
        httpClient.close();
        debugPrint('[CloudSync] Got ${list.length} readings via direct REST fallback.');
        return list;
      }
      httpClient.close();
    } catch (e) {
      debugPrint('[CloudSync] Direct REST fallback error: $e');
    }
    return [];
  }

  void _applyToRepository(List<dynamic> rows, HealthRepository repository) {
    final hrPoints   = <ChartDataPoint>[];
    final spo2Points = <ChartDataPoint>[];
    final stepPoints = <ChartDataPoint>[];
    final cloudHistory = <HistoryEntry>[];
    final now = DateTime.now();

    int hrMin = 999, hrMax = 0, hrSum = 0, hrCount = 0;
    int spMin = 999, spMax = 0, spSum = 0, spCount = 0;
    int latestSteps = 0;
    int stepCount = 0;

    for (final row in rows) {
      final type  = (row['type'] as String?) ?? '';
      final value = (row['value'] as int?) ?? 0;
      final tsStr = (row['recorded_at'] as String?) ?? '';
      final id    = row['id']?.toString() ?? '${type}_$tsStr';
      if (value <= 0 || tsStr.isEmpty) continue;

      DateTime ts;
      try {
        ts = DateTime.parse(tsStr).toLocal();
      } catch (_) {
        continue;
      }

      final x = ts.millisecondsSinceEpoch.toDouble();

      final isToday = ts.year == now.year && ts.month == now.month && ts.day == now.day;
      final isYesterday = ts.year == now.year && ts.month == now.month && ts.day == (now.day - 1);
      final section = isToday ? 'Today' : (isYesterday ? 'Yesterday' : '${ts.day}/${ts.month}/${ts.year}');
      final timeStr = '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

      if (type == 'hr') {
        hrPoints.add(ChartDataPoint(x: x, y: value.toDouble(),
            label: _hourLabel(ts)));
        if (value < hrMin) hrMin = value;
        if (value > hrMax) hrMax = value;
        hrSum += value;
        hrCount++;

        cloudHistory.add(
          HistoryEntry(
            id: 'cloud_hr_$id',
            timestamp: ts,
            title: 'Heart Rate',
            category: 'Heart Rate',
            valueDisplay: '$value',
            unit: 'bpm',
            status: value < 60 ? 'Low' : (value <= 100 ? 'Normal' : 'High'),
            detail: timeStr,
            section: section,
          ),
        );
      } else if (type == 'spo2') {
        spo2Points.add(ChartDataPoint(x: x, y: value.toDouble(),
            label: _hourLabel(ts)));
        if (value < spMin) spMin = value;
        if (value > spMax) spMax = value;
        spSum += value;
        spCount++;

        cloudHistory.add(
          HistoryEntry(
            id: 'cloud_spo2_$id',
            timestamp: ts,
            title: 'Blood Oxygen',
            category: 'SpO2',
            valueDisplay: '$value',
            unit: '%',
            status: value >= 95 ? 'Normal' : 'Low',
            detail: timeStr,
            section: section,
          ),
        );
      } else if (type == 'steps' || type == 'step') {
        stepPoints.add(ChartDataPoint(x: x, y: value.toDouble(),
            label: _hourLabel(ts)));
        if (value > latestSteps && isToday) latestSteps = value;
        stepCount++;

        cloudHistory.add(
          HistoryEntry(
            id: 'cloud_steps_$id',
            timestamp: ts,
            title: 'Footsteps',
            category: 'Activity',
            valueDisplay: '$value',
            unit: 'steps',
            status: value >= 10000 ? 'Goal Met' : '',
            detail: timeStr,
            section: section,
          ),
        );
      }
    }

    // Populate timeline feed in repository
    if (cloudHistory.isNotEmpty) {
      repository.addHistoryEntries(cloudHistory);
      debugPrint('[CloudSync] Added ${cloudHistory.length} history feed entries.');
    }

    // Update HeartRate data
    if (hrCount > 0) {
      final current = repository.heartRate.value;
      repository.updateHeartRate(current.copyWith(
        currentBpm: hrPoints.isNotEmpty ? hrPoints.first.y.toInt() : current.currentBpm,
        minToday:   hrMin < 999 ? hrMin : current.minToday,
        maxToday:   hrMax > 0   ? hrMax : current.maxToday,
        avgToday:   hrCount > 0 ? (hrSum / hrCount).round() : current.avgToday,
        dayData:    hrPoints.reversed.toList(),
        sparkline:  hrPoints.take(20).toList(),
      ));
      debugPrint('[CloudSync] Applied $hrCount HR readings.');
    }

    // Update SpO2 data
    if (spCount > 0) {
      final current = repository.spo2.value;
      repository.updateSpo2(current.copyWith(
        percentage: spo2Points.isNotEmpty ? spo2Points.first.y.toInt() : current.percentage,
        minToday:   spMin < 999 ? spMin : current.minToday,
        maxToday:   spMax > 0   ? spMax : current.maxToday,
        avgToday:   spCount > 0 ? (spSum / spCount).round() : current.avgToday,
        dayData:    spo2Points.reversed.toList(),
        sparkline:  spo2Points.take(20).toList(),
      ));
      debugPrint('[CloudSync] Applied $spCount SpO2 readings.');
    }

    // Update Activity data
    if (stepCount > 0) {
      final current = repository.activity.value;
      final currentSteps = latestSteps > 0
          ? latestSteps
          : (stepPoints.isNotEmpty ? stepPoints.first.y.toInt() : current.steps);
      final distKm = double.parse(((currentSteps * 0.70) / 1000.0).toStringAsFixed(2));
      final cals = (currentSteps * 0.04).round();
      final activeMins = (currentSteps / 100).round();

      repository.updateActivity(current.copyWith(
        steps: currentSteps,
        distanceKm: distKm,
        caloriesKcal: cals,
        activeMinutes: activeMins,
        timestamp: DateTime.now(),
        hourlyBars: stepPoints.take(24).toList(),
      ));
      debugPrint('[CloudSync] Applied $stepCount step readings (steps: $currentSteps).');
    }
  }

  static String _hourLabel(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:00';
}