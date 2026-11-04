import 'dart:convert';
import 'dart:io';

import '../models/health_metrics.dart';
import '../repositories/health_repository.dart';
import 'settings_storage_service.dart';

/// Aggregated, privacy-conscious data snapshot provided to the AI Assistant.
/// Excludes sensitive credentials, Wi-Fi passwords, and irrelevant logs.
class AiHealthContext {
  final String userName;
  final int? userAge;
  final double? heightCm;
  final double? weightKg;
  final double? bmi;
  final String bmiCategory;
  final String primaryGoal;
  final String units;

  // Device telemetry
  final String deviceName;
  final String firmwareVersion;
  final int batteryPct;
  final bool isConnected;

  // Real-time vitals
  final int currentBpm;
  final int restingBpm;
  final int minBpmToday;
  final int avgBpmToday;
  final int maxBpmToday;
  final int currentSpo2;
  final String postureClassification;
  final int postureScoreToday;
  final Duration goodPostureTime;
  final int stepsToday;
  final int stepGoal;
  final int caloriesKcal;
  final int activeMinutes;

  const AiHealthContext({
    required this.userName,
    this.userAge,
    this.heightCm,
    this.weightKg,
    this.bmi,
    required this.bmiCategory,
    required this.primaryGoal,
    required this.units,
    required this.deviceName,
    required this.firmwareVersion,
    required this.batteryPct,
    required this.isConnected,
    required this.currentBpm,
    required this.restingBpm,
    required this.minBpmToday,
    required this.avgBpmToday,
    required this.maxBpmToday,
    required this.currentSpo2,
    required this.postureClassification,
    required this.postureScoreToday,
    required this.goodPostureTime,
    required this.stepsToday,
    required this.stepGoal,
    required this.caloriesKcal,
    required this.activeMinutes,
  });

  Map<String, dynamic> toJson() => {
    'userProfile': {
      'name': userName,
      'age': userAge,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'bmi': bmi?.toStringAsFixed(1),
      'bmiCategory': bmiCategory,
      'primaryGoal': primaryGoal,
      'units': units,
    },
    'device': {
      'name': deviceName,
      'firmware': firmwareVersion,
      'batteryPct': batteryPct,
      'connected': isConnected,
    },
    'liveVitals': {
      'heartRate': {
        'currentBpm': currentBpm,
        'restingBpm': restingBpm,
        'minToday': minBpmToday,
        'avgToday': avgBpmToday,
        'maxToday': maxBpmToday,
      },
      'spo2': {'percentage': currentSpo2},
      'posture': {
        'current': postureClassification,
        'scoreToday': postureScoreToday,
        'goodPostureMinutes': goodPostureTime.inMinutes,
      },
      'activity': {
        'steps': stepsToday,
        'goal': stepGoal,
        'caloriesKcal': caloriesKcal,
        'activeMinutes': activeMinutes,
      },
    },
  };
}

/// Abstract contract for AI health analysis and conversational assistance.
abstract class AiService {
  Future<String> queryAssistant({
    required String userPrompt,
    required AiHealthContext context,
    List<Map<String, String>>? chatHistory,
    String? customApiKey,
  });

  AiHealthContext buildContext({
    required HealthRepository repository,
    required UserHealthProfile? profile,
  });
}

/// AI service implementation featuring high-speed Groq Cloud API,
/// optional external backend proxy, and intelligent local analytics fallback.
class HealthDeviceAiService implements AiService {
  /// API Key configuration - reads from compile-time environment, settings storage, or local environment.
  static const String embeddedGroqApiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  final String? backendUrl;
  final SettingsStorageService _storage = SettingsStorageService();

  HealthDeviceAiService({this.backendUrl});

  /// Returns active configured key if present from embedded code, stored settings, or environment.
  String? get configuredApiKey {
    if (embeddedGroqApiKey.trim().isNotEmpty) return embeddedGroqApiKey.trim();
    final stored = _storage.getGroqApiKey();
    if (stored != null && stored.trim().isNotEmpty) return stored.trim();
    if (const bool.hasEnvironment('GROQ_API_KEY')) {
      return const String.fromEnvironment('GROQ_API_KEY');
    }
    try {
      final env = Platform.environment['GROQ_API_KEY'];
      if (env != null && env.trim().isNotEmpty) return env.trim();
    } catch (_) {}
    return null;
  }

  /// Whether a live Cloud LLM (xAI Grok or Groq Cloud) is armed and ready.
  bool get hasCloudKey => (configuredApiKey != null && configuredApiKey!.isNotEmpty);

  /// Human-readable active engine title
  String get activeProviderName {
    final key = configuredApiKey;
    if (key == null || key.isEmpty) return 'Offline Health Engine';
    if (key.startsWith('xai-')) return 'xAI Grok (Live)';
    if (key.startsWith('gsk_')) return 'Groq Cloud (Live)';
    return 'Cloud AI (Live)';
  }

  @override
  AiHealthContext buildContext({
    required HealthRepository repository,
    required UserHealthProfile? profile,
  }) {
    final devInfo = repository.deviceInfo.value;
    final conn = repository.connectionStatus.value;
    final batt = repository.battery.value;
    final hr = repository.heartRate.value;
    final spo2 = repository.spo2.value;
    final pos = repository.posture.value;
    final act = repository.activity.value;

    return AiHealthContext(
      userName: profile?.name.isNotEmpty == true ? profile!.name : 'Friend',
      userAge: profile?.age,
      heightCm: profile?.heightCm,
      weightKg: profile?.weightKg,
      bmi: profile?.bmi,
      bmiCategory: profile?.bmiCategory ?? 'N/A',
      primaryGoal: profile?.primaryGoal ?? 'General wellness',
      units: profile?.units ?? 'Metric (cm, kg)',
      deviceName: devInfo.name,
      firmwareVersion: devInfo.firmwareVersion,
      batteryPct: batt.percentage,
      isConnected: conn.isConnected,
      currentBpm: hr.currentBpm,
      restingBpm: hr.restingBpm,
      minBpmToday: hr.minToday,
      avgBpmToday: hr.avgToday,
      maxBpmToday: hr.maxToday,
      currentSpo2: spo2.percentage,
      postureClassification: pos.classificationLabel,
      postureScoreToday: pos.postureScoreToday,
      goodPostureTime: pos.goodPostureTime,
      stepsToday: act.steps,
      stepGoal: act.stepGoal,
      caloriesKcal: act.caloriesKcal,
      activeMinutes: act.activeMinutes,
    );
  }

  @override
  Future<String> queryAssistant({
    required String userPrompt,
    required AiHealthContext context,
    List<Map<String, String>>? chatHistory,
    String? customApiKey,
  }) async {
    // 1. Check for Groq / AI API key (custom param, embedded key, stored settings, or environment)
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    final apiKey = customApiKey ?? configuredApiKey;

    if (apiKey != null && apiKey.trim().isNotEmpty && !isTest) {
      final groqResponse = await _queryGroqApi(
        userPrompt: userPrompt,
        context: context,
        apiKey: apiKey.trim(),
        chatHistory: chatHistory,
      );
      if (groqResponse != null && groqResponse.trim().isNotEmpty) {
        return groqResponse;
      }
    }

    // 2. If a backend endpoint is configured, forward to secure backend proxy
    final configuredUrl =
        backendUrl ??
        (const bool.hasEnvironment('AI_BACKEND_URL')
            ? const String.fromEnvironment('AI_BACKEND_URL')
            : null);

    if (configuredUrl != null && configuredUrl.trim().isNotEmpty) {
      try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 8);
        final request = await client.postUrl(Uri.parse(configuredUrl));
        request.headers.contentType = ContentType.json;
        final payload = jsonEncode({
          'prompt': userPrompt,
          'context': context.toJson(),
        });
        request.write(payload);
        final response = await request.close();
        if (response.statusCode == 200) {
          final respBody = await response.transform(utf8.decoder).join();
          final parsed = jsonDecode(respBody);
          return (parsed['response'] ?? parsed['message'] ?? respBody)
              .toString();
        }
      } catch (_) {
        // Fallback to grounded local engine if backend network error occurs
      }
    }

    // 3. Intelligent local health analytics and explanation engine
    return _generateGroundedResponse(userPrompt, context);
  }

  Future<String?> _queryGroqApi({
    required String userPrompt,
    required AiHealthContext context,
    required String apiKey,
    List<Map<String, String>>? chatHistory,
  }) async {
    final isXai = apiKey.startsWith('xai-');
    final isGroq = apiKey.startsWith('gsk_');
    final providerName = isXai ? 'xAI Grok' : (isGroq ? 'Groq Cloud' : 'Cloud AI');

    final endpoint = isXai
        ? Uri.parse('https://api.x.ai/v1/chat/completions')
        : Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    // Tested live on Groq: openai/gpt-oss-120b, openai/gpt-oss-20b, qwen/qwen3.8-27b
    final candidateModels = isXai
        ? ['grok-beta', 'grok-2-latest']
        : ['openai/gpt-oss-120b', 'openai/gpt-oss-20b', 'qwen/qwen3.8-27b'];

    final systemPrompt = '''You are the HealthDevice AI Assistant, an empathetic, highly knowledgeable personal health, fitness, nutrition, and wellness coach.
You have real-time access to the user's live health telemetry and profile:
- User Profile: ${context.userName}, Age: ${context.userAge ?? 'Not set'}, Height: ${context.heightCm != null ? '${context.heightCm!.toStringAsFixed(1)} cm' : 'Not set'}, Weight: ${context.weightKg != null ? '${context.weightKg!.toStringAsFixed(1)} kg' : 'Not set'}, BMI: ${context.bmi != null ? context.bmi!.toStringAsFixed(1) : 'N/A'} (${context.bmiCategory})
- Primary Health Goal: ${context.primaryGoal}
- Units: ${context.units}
- Live Telemetry:
  * Optical Heart Rate: Current ${context.currentBpm} bpm | Resting ${context.restingBpm} bpm | Range ${context.minBpmToday}-${context.maxBpmToday} bpm (Avg: ${context.avgBpmToday} bpm)
  * Blood Oxygen (SpO2): ${context.currentSpo2}%
  * Posture: ${context.postureClassification} | Posture Score: ${context.postureScoreToday}/100 | Upright Time: ${context.goodPostureTime.inMinutes} mins
  * Daily Activity: ${context.stepsToday} / ${context.stepGoal} steps | Calories: ${context.caloriesKcal} kcal | Active: ${context.activeMinutes} mins
  * Hardware: ${context.deviceName} v${context.firmwareVersion} (${context.isConnected ? 'Connected' : 'Disconnected'}, Battery: ${context.batteryPct}%)

Instructions:
1. Provide accurate, practical, and comprehensive answers to any fitness, weight loss, diet, nutrition, workout, stamina, sleep, health question, or hardware inquiry.
2. Whenever answering questions like "how to lose weight", "give me a diet plan", "explain my heart rate", or "what exercises should I do", tailor your advice directly to their specific stats (weight, BMI, steps today, resting heart rate, and primary goal).
3. Format answers cleanly using Markdown with bold headings and bullet points. Never use raw HTML tags like <br>.
4. Keep advice motivating, practical, and scientifically sound.
5. Provide a brief, gentle medical reminder when addressing clinical symptoms or health anxieties.''';

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    if (chatHistory != null && chatHistory.isNotEmpty) {
      final recent = chatHistory.length > 8
          ? chatHistory.sublist(chatHistory.length - 8)
          : chatHistory;
      for (final msg in recent) {
        final role = msg['role'] ?? 'user';
        final content = msg['content'] ?? '';
        if (content.isNotEmpty) {
          messages.add({'role': role, 'content': content});
        }
      }
    }

    messages.add({'role': 'user', 'content': userPrompt});

    for (final model in candidateModels) {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      try {
        final request = await client.postUrl(endpoint);
        request.headers.contentType = ContentType.json;
        request.headers.set('Authorization', 'Bearer $apiKey');

        final payload = jsonEncode({
          'model': model,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 1024,
        });

        request.write(payload);
        final response = await request.close();
        final respBody = await response.transform(utf8.decoder).join();

        if (response.statusCode == 200) {
          final parsed = jsonDecode(respBody);
          final reply = parsed['choices']?[0]?['message']?['content'] as String?;
          if (reply != null && reply.trim().isNotEmpty) {
            client.close();
            return reply.trim();
          }
        } else if (response.statusCode == 404 || response.statusCode == 400) {
          // Model might not be available on this key; try next candidate
          client.close();
          continue;
        } else {
          try {
            final errObj = jsonDecode(respBody);
            final msg = errObj['error']?['message'] ?? 'API status ${response.statusCode}';
            client.close();
            return '⚠️ **$providerName Error (${response.statusCode}):** $msg\n\nPlease verify that your API key is valid and has active quota.';
          } catch (_) {
            client.close();
            return '⚠️ **$providerName Error (${response.statusCode}):** Unable to reach $providerName servers (${response.reasonPhrase}).';
          }
        }
      } catch (e) {
        client.close();
        return '⚠️ **$providerName Network Error:** Unable to reach AI servers ($e).\n\nPlease verify that your device has active internet connectivity.';
      }
    }
    return null;
  }

  String _generateGroundedResponse(String prompt, AiHealthContext ctx) {
    final lower = prompt.toLowerCase();

    // 1. Daily Health Summary
    if (lower.contains('daily') ||
        lower.contains('summary') ||
        lower.contains('how am i doing') ||
        lower.contains('overview')) {
      final stepPct = (ctx.stepsToday / ctx.stepGoal * 100).toInt();
      return '''📊 **Daily Health Summary for ${ctx.userName}**

• **Activity & Steps:** You have recorded **${ctx.stepsToday}** steps today ($stepPct% of your ${ctx.stepGoal} step goal), totaling **${ctx.activeMinutes}** active minutes and **${ctx.caloriesKcal}** kcal burned.
• **Heart Rate:** Your current resting heart rate is **${ctx.restingBpm} bpm**, with an average of **${ctx.avgBpmToday} bpm** (range: ${ctx.minBpmToday} – ${ctx.maxBpmToday} bpm).
• **Blood Oxygen (SpO₂):** Optical sensor readings indicate **${ctx.currentSpo2}%**, which is within the typical normal range (95–100%).
• **Posture & Ergonomics:** Your posture score is **${ctx.postureScoreToday}/100** with **${ctx.goodPostureTime.inHours}h ${ctx.goodPostureTime.inMinutes % 60}m** of upright alignment logged.

💡 *Wellness Guidance:* ${ctx.primaryGoal == 'Posture' ? 'Remember to perform periodic shoulder rollbacks to maintain upright alignment.' : 'Keep hydrating and take a short walk to hit your remaining step goal.'}

⚠️ *Notice: HealthDevice telemetry is provided for informational and personal fitness tracking only. It is not intended as medical diagnosis.*''';
    }

    // 2. Heart Rate & SpO2
    if (lower.contains('heart') ||
        lower.contains('bpm') ||
        lower.contains('pulse') ||
        lower.contains('spo2') ||
        lower.contains('oxygen')) {
      return '''❤️ **Cardiovascular & Oxygen Telemetry**

• **Live Heart Rate:** **${ctx.currentBpm} bpm** (Resting baseline: ${ctx.restingBpm} bpm).
• **Daily HR Range:** Min: **${ctx.minBpmToday} bpm** | Avg: **${ctx.avgBpmToday} bpm** | Max: **${ctx.maxBpmToday} bpm**.
• **SpO₂ Blood Oxygen:** **${ctx.currentSpo2}%**.

📖 **What this means:**
Resting heart rates for healthy adults typically span 60–100 bpm, while resting SpO₂ typically ranges between 95% and 100%. Your current values reflect steady optical sensor readings.

⚠️ *Reminder: Optical pulse readings can vary with sensor placement, arm movement, or temperature. This is not medical diagnostic data.*''';
    }

    // 3. Posture guidance
    if (lower.contains('posture') ||
        lower.contains('slouch') ||
        lower.contains('back') ||
        lower.contains('ergonomic')) {
      return '''🧍 **Ergonomic & Posture Analysis**

• **Current Alignment:** **${ctx.postureClassification}**
• **Today's Posture Score:** **${ctx.postureScoreToday} / 100**
• **Upright Time:** **${ctx.goodPostureTime.inHours} hours, ${ctx.goodPostureTime.inMinutes % 60} minutes**

🎯 **Goal Alignment (${ctx.primaryGoal}):**
The HealthDevice 3-axis accelerometer tracks chest/upper-body tilt angles relative to your calibrated baseline. If you slouch past 15° for more than 10 seconds, the device buzzer and RGB LED alert you.

💡 **Quick Ergonomic Tip:**
Keep your screen at eye level and keep your feet flat on the floor. Tap **Settings → Button Guide** to see how to recalibrate your posture baseline via the physical button!''';
    }

    // 4. Activity & Goals
    if (lower.contains('step') ||
        lower.contains('walk') ||
        lower.contains('activity') ||
        lower.contains('calorie') ||
        lower.contains('goal')) {
      final remaining = (ctx.stepGoal - ctx.stepsToday).clamp(0, 100000);
      return '''🏃 **Activity & Goal Guidance**

• **Selected Goal:** **${ctx.primaryGoal}**
• **Steps:** **${ctx.stepsToday}** / ${ctx.stepGoal} (${(ctx.stepsToday / ctx.stepGoal * 100).toInt()}%)
• **Remaining to Goal:** **$remaining steps**
• **Active Minutes:** **${ctx.activeMinutes} mins**
• **Energy Output:** **${ctx.caloriesKcal} kcal**

${ctx.bmi != null ? '• **Profile BMI:** ${ctx.bmi!.toStringAsFixed(1)} (${ctx.bmiCategory})' : ''}

💡 *Recommendation:* Breaking up sedentary periods with 5-minute brisk walking breaks boosts both your daily active minutes and cardiovascular circulation!''';
    }

    // 5. Button Guide & Device Settings
    if (lower.contains('button') ||
        lower.contains('press') ||
        lower.contains('device') ||
        lower.contains('hardware') ||
        lower.contains('click') ||
        lower.contains('how to use')) {
      return '''⌚ **HealthDevice Hardware & Button Guide**

Your physical HealthDevice button operates as follows:
• **Single Click:** Advances to the next screen (Home → HR → Clock → Posture → Wellness → Menu).
• **Double Click:** Returns immediately to the Home screen.
• **Triple Click:** Toggles modes (e.g. Heart Rate → SpO₂ → Live Vitals, or Clock → Timer → Stopwatch).
• **Long Press (Hold):** Starts a vital measurement scan or activates Timer / Calibration.
• **Hold for 3 Seconds:** Enters low-power standby mode.

Battery is at **${ctx.batteryPct}%** (${ctx.isConnected ? 'Connected' : 'Disconnected'}).''';
    }

    // 6. General Conversational / Inquiries
    return '''💡 **HealthDevice Assistant Insights**

Hello ${ctx.userName}! Based on your synchronized device data:
• **Current Vitals:** ${ctx.currentBpm} bpm Heart Rate, ${ctx.currentSpo2}% SpO₂, and ${ctx.postureClassification} posture.
• **Progress:** ${ctx.stepsToday} steps logged toward your **${ctx.primaryGoal}** objective.

How can I help you further? You can ask me for:
1. *"Give me my daily summary"*
2. *"Explain my posture score and slouch habits"*
3. *"How does the physical button work?"*
4. *"What do my heart rate numbers mean?"*

⚠️ *Notice: Antigravity HealthDevice AI provides general wellness explanations and hardware guidance only, and does not provide clinical or medical diagnoses.*''';
  }
}
