import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../models/health_metrics.dart';
import '../repositories/auth_repository.dart';
import '../repositories/health_repository.dart';
import '../services/ai_chat_cloud_sync_service.dart';
import '../services/ai_service.dart';
import '../services/owner_query_logger_service.dart';
import '../services/settings_storage_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Screen: AI Health Assistant with conversational interface, quick prompts,
/// persistent chat history, previous questions assessment tab, and medical disclaimers.
class AiAssistantScreen extends StatefulWidget {
  final HealthRepository healthRepository;
  final AuthRepository? authRepository;
  final String? initialPrompt;

  const AiAssistantScreen({
    super.key,
    required this.healthRepository,
    this.authRepository,
    this.initialPrompt,
  });

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _aiService = HealthDeviceAiService();
  final _storage = SettingsStorageService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _historySearchController = TextEditingController();

  final List<AiChatMessage> _messages = [];
  final List<AiChatQuestionHistoryItem> _questionHistory = [];
  final Map<String, GlobalKey> _messageKeys = {};

  bool _isLoading = false;
  bool _isSyncing = false;
  int _selectedTabIndex = 0; // 0: Chat, 1: History
  String _historySearchQuery = '';
  String? _highlightedMessageId;
  Timer? _highlightTimer;
  Timer? _cloudPollTimer;
  late final AuthRepository _auth;

  final List<String> _quickPrompts = [
    '📊 Daily Summary',
    '❤️ Explain My Heart Rate',
    '🧍 Posture Guidance',
    '🏃 Goal Progress',
    '⌚ How Do Hardware Buttons Work?',
  ];

  @override
  void initState() {
    super.initState();
    _auth = widget.authRepository ?? LocalAuthRepository();
    _loadPersistedChatAndHistory();

    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(widget.initialPrompt!);
      });
    }

    // Periodically poll for new messages sent from the other device
    _cloudPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _syncCloudChat();
      }
    });
  }

  void _loadPersistedChatAndHistory() {
    // 1. Load active chat messages from persistent storage
    final savedMessages = _storage.getAiChatHistory();
    if (savedMessages.isNotEmpty) {
      _messages.addAll(
        savedMessages.map((e) => AiChatMessage.fromJson(e)),
      );
    } else {
      _initWelcomeMessage();
    }

    // 2. Load question history
    final savedHistory = _storage.getAiQuestionHistory();
    if (savedHistory.isNotEmpty) {
      _questionHistory.addAll(
        savedHistory.map((e) => AiChatQuestionHistoryItem.fromJson(e)),
      );
    } else {
      _syncHistoryFromMessages();
    }

    // 3. Seamlessly sync chat & questions with Supabase cloud
    _syncCloudChat();
  }

  String _getUserEmail() {
    final user = _auth.currentUser.value;
    if (user != null && user.email.isNotEmpty) return user.email;
    final savedUser = _storage.getAuthUser();
    if (savedUser != null && savedUser['email'] != null) {
      return (savedUser['email'] as String).trim().toLowerCase();
    }
    return 'guptashaurya020@gmail.com';
  }

  Future<void> _syncCloudChat() async {
    final email = _getUserEmail();
    if (email.isEmpty) return;

    try {
      final snapshot =
          await AiChatCloudSyncService.instance.fetchSnapshot(email);
      if (snapshot == null) {
        // If cloud snapshot doesn't exist yet, seed cloud from local
        if (_messages.isNotEmpty || _questionHistory.isNotEmpty) {
          await AiChatCloudSyncService.instance.pushSnapshot(
            email: email,
            messages: _messages,
            questions: _questionHistory,
          );
        }
        return;
      }

      bool localChanged = false;
      bool cloudMissingLocal = false;

      final Set<String> cloudMsgIds = {};
      final cloudMsgsRaw = snapshot['messages'] as List<dynamic>?;
      if (cloudMsgsRaw != null && cloudMsgsRaw.isNotEmpty) {
        final cloudMsgs = cloudMsgsRaw
            .whereType<Map>()
            .map((m) => AiChatMessage.fromJson(Map<String, dynamic>.from(m)))
            .toList();

        final existingIds = _messages.map((m) => m.id).toSet();
        for (final msg in cloudMsgs) {
          cloudMsgIds.add(msg.id);
          if (!existingIds.contains(msg.id)) {
            _messages.add(msg);
            existingIds.add(msg.id);
            localChanged = true;
          }
        }
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      }

      final Set<String> cloudQIds = {};
      final cloudQuestionsRaw = snapshot['questions'] as List<dynamic>?;
      if (cloudQuestionsRaw != null && cloudQuestionsRaw.isNotEmpty) {
        final cloudQList = cloudQuestionsRaw
            .whereType<Map>()
            .map((m) => AiChatQuestionHistoryItem.fromJson(
                Map<String, dynamic>.from(m)))
            .toList();

        final existingQIds =
            _questionHistory.map((q) => q.questionId).toSet();
        for (final q in cloudQList) {
          cloudQIds.add(q.questionId);
          if (!existingQIds.contains(q.questionId)) {
            _questionHistory.add(q);
            existingQIds.add(q.questionId);
            localChanged = true;
          }
        }
        _questionHistory.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }

      // Check if local has any messages or questions not yet in cloud snapshot
      for (final m in _messages) {
        if (!cloudMsgIds.contains(m.id)) {
          cloudMissingLocal = true;
          break;
        }
      }
      if (!cloudMissingLocal) {
        for (final q in _questionHistory) {
          if (!cloudQIds.contains(q.questionId)) {
            cloudMissingLocal = true;
            break;
          }
        }
      }

      if (localChanged) {
        await _storage
            .saveAiChatHistory(_messages.map((m) => m.toJson()).toList());
        await _storage.saveAiQuestionHistory(
            _questionHistory.map((m) => m.toJson()).toList());
        if (mounted) setState(() {});
      }

      if (cloudMissingLocal) {
        // Local has items that cloud was missing: push unified snapshot
        await AiChatCloudSyncService.instance.pushSnapshot(
          email: email,
          messages: _messages,
          questions: _questionHistory,
        );
      }
    } catch (e) {
      debugPrint('[AI] Cloud sync note: $e');
    }
  }

  void _initWelcomeMessage() {
    final profile = _auth.currentProfile.value;
    final name = profile?.name.isNotEmpty == true ? profile!.name : 'Friend';
    _messages.add(
      AiChatMessage(
        id: 'msg_welcome',
        isUser: false,
        text: '''👋 Hi $name! I am your **HealthDevice AI Assistant**.

I analyze your synchronized optical heart rate, SpO₂, 3-axis posture angles, and activity history to provide personalized wellness insights.

Tap any quick prompt below or ask me anything about your device metrics!''',
        timestamp: DateTime.now(),
      ),
    );
  }

  void _syncHistoryFromMessages() {
    for (int i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      if (msg.isUser) {
        String answerText = '';
        String answerId = '';
        if (i + 1 < _messages.length && !_messages[i + 1].isUser) {
          answerText = _messages[i + 1].text;
          answerId = _messages[i + 1].id;
        }
        _questionHistory.insert(
          0,
          AiChatQuestionHistoryItem(
            questionId: msg.id,
            answerId: answerId,
            question: msg.text,
            answer: answerText,
            timestamp: msg.timestamp,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _cloudPollTimer?.cancel();
    _highlightTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _historySearchController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;

    _controller.clear();
    final userMsg = AiChatMessage(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      isUser: true,
      text: query,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });

    _scrollToBottom();
    await _persistState();

    final context = _aiService.buildContext(
      repository: widget.healthRepository,
      profile: _auth.currentProfile.value,
    );

    final chatHistory = _messages
        .where((m) => m.id != 'msg_welcome')
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();

    final reply = await _aiService.queryAssistant(
      userPrompt: query,
      context: context,
      chatHistory: chatHistory,
    );

    if (!mounted) return;

    final sanitizedReply = FormattedMarkdownText.sanitizeAiResponse(reply);
    final aiMsg = AiChatMessage(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      isUser: false,
      text: sanitizedReply,
      timestamp: DateTime.now(),
    );

    setState(() {
      _isLoading = false;
      _messages.add(aiMsg);

      // Add/update question in persistent history at the top
      _questionHistory.removeWhere((item) => item.questionId == userMsg.id);
      _questionHistory.insert(
        0,
        AiChatQuestionHistoryItem(
          questionId: userMsg.id,
          answerId: aiMsg.id,
          question: userMsg.text,
          answer: aiMsg.text,
          timestamp: userMsg.timestamp,
        ),
      );
    });

    _scrollToBottom();
    await _persistState();

    // Log query and response to owner Google Spreadsheet
    OwnerQueryLoggerService.instance.logQuery(
      query: userMsg.text,
      response: sanitizedReply,
      context: context,
      activeEngine: 'Groq Cloud',
    );
  }

  Future<void> _persistState() async {
    final chatJson = _messages.map((m) => m.toJson()).toList();
    final questionJson = _questionHistory.map((m) => m.toJson()).toList();
    await _storage.saveAiChatHistory(chatJson);
    await _storage.saveAiQuestionHistory(questionJson);

    // Sync to Supabase cloud snapshot
    final email = _getUserEmail();
    await AiChatCloudSyncService.instance.pushSnapshot(
      email: email,
      messages: _messages,
      questions: _questionHistory,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _assessQuestion(AiChatQuestionHistoryItem item) {
    // If message is not in current active chat (e.g., after starting a new chat), restore it
    final exists = _messages.any((m) => m.id == item.questionId);
    if (!exists) {
      _messages.add(
        AiChatMessage(
          id: item.questionId,
          isUser: true,
          text: item.question,
          timestamp: item.timestamp,
        ),
      );
      if (item.answer.isNotEmpty) {
        _messages.add(
          AiChatMessage(
            id: item.answerId.isNotEmpty
                ? item.answerId
                : 'ai_${DateTime.now().millisecondsSinceEpoch}',
            isUser: false,
            text: item.answer,
            timestamp: item.timestamp.add(const Duration(seconds: 1)),
          ),
        );
      }
      _persistState();
    }

    // Switch to Chat tab and highlight target question
    setState(() {
      _selectedTabIndex = 0;
      _highlightedMessageId = item.questionId;
    });

    // Scroll to the selected question
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _messageKeys[item.questionId];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.12,
        );
      } else {
        _scrollToBottom();
      }
    });

    // Automatically fade out the accent highlight after 2.5 seconds
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });
  }

  void _deleteQuestionFromHistory(AiChatQuestionHistoryItem item) async {
    setState(() {
      _questionHistory.removeWhere((q) => q.questionId == item.questionId);
    });
    await _persistState();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Question removed from history.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _startNewChat() {
    if (_messages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Already on a fresh chat session.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_comment_outlined, color: AppTheme.cyan, size: 22),
            SizedBox(width: 8),
            Text(
              'Start New Chat?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'Start a clean conversation thread? Your past questions will remain saved in the History tab so you can assess them anytime.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryBlueLight,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              _messages.clear();
              _messageKeys.clear();
              _highlightedMessageId = null;
              _initWelcomeMessage();
              await _persistState();
              if (mounted) {
                setState(() {
                  _selectedTabIndex = 0;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'New chat session started. Previous questions saved in History.',
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Start New'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppTheme.alarmRed, size: 22),
            SizedBox(width: 8),
            Text(
              'Clear All Chat History?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'This will permanently delete all questions, answers, and saved history. This action cannot be undone.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.alarmRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storage.clearAiChatHistory();
      final email = _getUserEmail();
      await AiChatCloudSyncService.instance.clearSnapshot(email);
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _questionHistory.clear();
        _messageKeys.clear();
        _highlightedMessageId = null;
        _initWelcomeMessage();
        _selectedTabIndex = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All chat and question history cleared.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final isYesterday = dt.year == now.year && dt.month == now.month && dt.day == (now.day - 1);
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $ampm';

    if (isToday) return 'Today at $timeStr';
    if (isYesterday) return 'Yesterday at $timeStr';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, $timeStr';
  }

  String _formatTimeOnly(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  String _formatAnswerSnippet(String raw) {
    if (raw.trim().isEmpty) return 'No response generated yet.';
    final cleaned = raw
        .replaceAll(RegExp(r'#+\s*'), '')
        .replaceAll(RegExp(r'\*\*'), '')
        .replaceAll(RegExp(r'__'), '')
        .replaceAll(RegExp(r'[*•-]\s+'), '')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppTheme.cyan.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, size: 16, color: AppTheme.cyan),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'HealthDevice AI',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sync Cloud & History',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: _isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.cyan,
                    ),
                  )
                : const Icon(
                    Icons.sync_rounded,
                    size: 21,
                    color: AppTheme.cyan,
                  ),
            onPressed: _isSyncing
                ? null
                : () async {
                    setState(() => _isSyncing = true);
                    await _syncCloudChat();
                    if (mounted) {
                      setState(() => _isSyncing = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('AI Chat & History synchronized with cloud.'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
          ),
          IconButton(
            tooltip: 'New Chat Session',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(
              Icons.edit_note_rounded,
              size: 23,
              color: AppTheme.textPrimary,
            ),
            onPressed: _startNewChat,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            padding: const EdgeInsets.only(left: 2, right: 8),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 36),
            color: AppTheme.card,
            onSelected: (val) async {
              if (val == 'new') _startNewChat();
              if (val == 'clear') _confirmClearHistory();
              if (val == 'sync') {
                setState(() => _isSyncing = true);
                await _syncCloudChat();
                if (mounted) {
                  setState(() => _isSyncing = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('AI Chat & History synchronized with cloud.'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'new',
                child: Row(
                  children: [
                    Icon(Icons.add_comment_outlined, size: 18, color: AppTheme.cyan),
                    SizedBox(width: 10),
                    Text(
                      'New Chat Session',
                      style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sync',
                child: Row(
                  children: [
                    Icon(Icons.sync_rounded, size: 18, color: AppTheme.cyan),
                    SizedBox(width: 10),
                    Text(
                      'Sync with Cloud',
                      style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.alarmRed),
                    SizedBox(width: 10),
                    Text(
                      'Clear All History',
                      style: TextStyle(fontSize: 13, color: AppTheme.alarmRed),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              children: [
                // Medical Non-Diagnostic Disclaimer Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    color: AppTheme.card,
                    border: Border(
                      bottom: BorderSide(color: AppTheme.borderSubtle),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 16,
                        color: AppTheme.cyan,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Informational wellness guide only. Not intended for clinical or medical diagnosis.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Sleek Tab Switcher: [ Chat ] & [ History (N) ]
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              setState(() => _selectedTabIndex = 0);
                              _syncCloudChat();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedTabIndex == 0
                                    ? AppTheme.primaryBlueLight
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 15,
                                    color: _selectedTabIndex == 0
                                        ? Colors.white
                                        : AppTheme.textMuted,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'Chat',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedTabIndex == 0
                                          ? Colors.white
                                          : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              setState(() => _selectedTabIndex = 1);
                              _syncCloudChat();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedTabIndex == 1
                                    ? AppTheme.primaryBlueLight
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.history_rounded,
                                    size: 16,
                                    color: _selectedTabIndex == 1
                                        ? Colors.white
                                        : AppTheme.textMuted,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    'History (${_questionHistory.length})',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedTabIndex == 1
                                          ? Colors.white
                                          : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Main Content View (Chat vs History Tab)
                Expanded(
                  child: _selectedTabIndex == 0
                      ? _buildChatView(isDesktop)
                      : _buildHistoryView(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatView(bool isDesktop) {
    return Column(
      children: [
        // Quick Prompt Pills
        SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            scrollDirection: Axis.horizontal,
            itemCount: _quickPrompts.length,
            separatorBuilder: (ctx, i) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final prompt = _quickPrompts[index];
              return ActionChip(
                label: Text(
                  prompt,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                backgroundColor: AppTheme.card,
                side: const BorderSide(color: AppTheme.borderSubtle),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onPressed: _isLoading ? null : () => _sendMessage(prompt),
              );
            },
          ),
        ),

        // Chat Messages
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 32 : 16,
              vertical: 12,
            ),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              return _buildMessageBubble(msg);
            },
          ),
        ),

        // Loading Indicator
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.cyan,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Analyzing HealthDevice telemetry...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),

        // Input Bar
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(
              top: BorderSide(color: AppTheme.borderSubtle),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask about vitals, posture, or steps...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                    ),
                    filled: true,
                    fillColor: AppTheme.card,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: AppTheme.border,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: AppTheme.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryBlueLight,
                      ),
                    ),
                  ),
                  onSubmitted: (val) {
                    if (!_isLoading) _sendMessage(val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(
                  Icons.arrow_upward_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlueLight,
                  padding: const EdgeInsets.all(12),
                ),
                onPressed: _isLoading
                    ? null
                    : () => _sendMessage(_controller.text),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryView() {
    final filtered = _questionHistory.where((item) {
      if (_historySearchQuery.isEmpty) return true;
      final q = _historySearchQuery.toLowerCase();
      return item.question.toLowerCase().contains(q) ||
          item.answer.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        // History Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _historySearchController,
            style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search previous questions & answers...',
              hintStyle: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.textMuted),
              suffixIcon: _historySearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textMuted),
                      onPressed: () {
                        _historySearchController.clear();
                        setState(() => _historySearchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.cyan),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _historySearchQuery = val.trim().toLowerCase();
              });
            },
          ),
        ),

        // Header summary row
        if (_questionHistory.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saved Questions (${filtered.length})',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                InkWell(
                  onTap: _confirmClearHistory,
                  child: const Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 14, color: AppTheme.alarmRed),
                      SizedBox(width: 4),
                      Text(
                        'Clear History',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.alarmRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // List of previous questions
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _questionHistory.isEmpty
                              ? Icons.history_toggle_off_rounded
                              : Icons.search_off_rounded,
                          size: 48,
                          color: AppTheme.textMuted.withOpacity(0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _questionHistory.isEmpty
                              ? 'No question history yet'
                              : 'No matching questions found',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _questionHistory.isEmpty
                              ? 'Ask the AI Assistant about your vitals, heart rate, posture, or steps to build your history.'
                              : 'Try searching with different keywords like heart, posture, or steps.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        if (_questionHistory.isEmpty) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlueLight,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Ask a Question',
                              style: TextStyle(fontSize: 13),
                            ),
                            onPressed: () => setState(() => _selectedTabIndex = 0),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildHistoryCard(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(AiChatQuestionHistoryItem item) {
    final snippet = _formatAnswerSnippet(item.answer);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _assessQuestion(item),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: timestamp and "Click to assess" badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 13, color: AppTheme.cyan),
                      const SizedBox(width: 5),
                      Text(
                        _formatDate(item.timestamp),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.cyan,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.cyan.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Text(
                              'Click to assess',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.cyan,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 11,
                              color: AppTheme.cyan,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: AppTheme.textMuted,
                        ),
                        tooltip: 'Remove from history',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        onPressed: () => _deleteQuestionFromHistory(item),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Question prompt
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.help_outline_rounded,
                      size: 15,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.question,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Answer snippet
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                    left: BorderSide(color: AppTheme.cyan, width: 2.5),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.auto_awesome, size: 12, color: AppTheme.cyan),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(AiChatMessage msg) {
    final isHighlighted = _highlightedMessageId == msg.id;
    final key = _messageKeys.putIfAbsent(msg.id, () => GlobalKey());

    if (msg.isUser) {
      return Container(
        key: key,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: isHighlighted
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.cyan, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.cyan.withOpacity(0.35),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              )
            : null,
        padding: isHighlighted ? const EdgeInsets.all(4) : EdgeInsets.zero,
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlueLight,
              borderRadius: BorderRadius.circular(16)
                  .copyWith(bottomRight: const Radius.circular(4)),
            ),
            child: Text(
              msg.text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: isHighlighted
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.cyan, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.cyan.withOpacity(0.35),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            )
          : null,
      padding: isHighlighted ? const EdgeInsets.all(4) : EdgeInsets.zero,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16)
                .copyWith(topLeft: const Radius.circular(4)),
            border: Border.all(
              color: isHighlighted ? AppTheme.cyan : AppTheme.border,
              width: isHighlighted ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, size: 14, color: AppTheme.cyan),
                  const SizedBox(width: 6),
                  const Text(
                    'HealthDevice AI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.cyan,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTimeOnly(msg.timestamp),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FormattedMarkdownText(text: msg.text),
            ],
          ),
        ),
      ),
    );
  }
}

/// Formatted Markdown Text renderer for AI assistant messages.
/// Automatically parses and styles markdown headings (#, ##, ###, ####),
/// Formatted Markdown Text renderer for AI assistant messages.
/// Automatically parses:
/// - Markdown headings (#, ##, ###, ####)
/// - Markdown tables (| col1 | col2 |) into clean, readable structured plan cards
/// - Strips and converts HTML tags like `<br>`, `<br/>`, `&nbsp;`
/// - Bullet points (•, -, *)
/// - Numbered lists (1., 2.)
/// - Bold (**text**), Italic (*italic*), and inline Code (`code`)
class FormattedMarkdownText extends StatelessWidget {
  final String text;
  final TextStyle? baseStyle;

  const FormattedMarkdownText({
    super.key,
    required this.text,
    this.baseStyle,
  });

  /// Pre-sanitizes raw AI response text: decodes HTML entities and normalizes line breaks.
  static String sanitizeAiResponse(String raw) {
    if (raw.isEmpty) return raw;
    var text = raw;
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Decode HTML entities first
    text = text
        .replaceAll('&amp;lt;', '<')
        .replaceAll('&amp;gt;', '>')
        .replaceAll('&amp;amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ');

    final lines = text.split('\n');
    final out = <String>[];
    for (final l in lines) {
      if (_isTableRow(l.trim())) {
        out.add(l);
      } else {
        // Outside table rows, expand all <br> variants into genuine newlines
        out.add(
          l
              .replaceAll(
                  RegExp(r'<\s*/?\s*br\s*/?\s*>', caseSensitive: false), '\n')
              .replaceAll(RegExp(r'\\<br\\>', caseSensitive: false), '\n')
              .replaceAll(RegExp(r'\[br\]', caseSensitive: false), '\n'),
        );
      }
    }
    return out.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = baseStyle ??
        const TextStyle(
          fontSize: 14,
          color: AppTheme.textPrimary,
          height: 1.48,
        );

    final sanitizedText = sanitizeAiResponse(text);
    final initialLines = sanitizedText.split('\n');
    final rawLines = <String>[];

    for (final line in initialLines) {
      if (_isTableRow(line.trim())) {
        rawLines.add(line);
      } else {
        // Expand <br>, <p>, and <div> tags outside tables into genuine newlines
        final expanded = line
            .replaceAll(
                RegExp(r'<\s*/?\s*br\s*/?\s*>', caseSensitive: false), '\n')
            .replaceAll(
                RegExp(r'<\s*/?\s*p\b[^>]*>', caseSensitive: false), '\n')
            .replaceAll(
                RegExp(r'<\s*/?\s*div\b[^>]*>', caseSensitive: false), '\n');
        for (final sub in expanded.split('\n')) {
          rawLines.add(sub);
        }
      }
    }

    final children = <Widget>[];

    int i = 0;
    while (i < rawLines.length) {
      final line = rawLines[i];
      final trimmed = line.trim();

      // Check if this line is part of a markdown table (starts or contains |)
      if (_isTableRow(trimmed)) {
        final tableLines = <String>[];
        while (i < rawLines.length && _isTableRow(rawLines[i])) {
          tableLines.add(rawLines[i]);
          i++;
        }
        final tableWidget = _buildTableWidget(tableLines, defaultStyle);
        if (tableWidget != null) {
          children.add(tableWidget);
          continue;
        } else {
          for (final tbl in tableLines) {
            final cleaned = _cleanHtmlTags(tbl.trim());
            _processSingleLine(cleaned, defaultStyle, children);
          }
          continue;
        }
      }

      // Preprocess non-table lines: clean all HTML tags like <br>, <br/>, &nbsp;, <p>, etc.
      final cleanedLine = _cleanHtmlTags(trimmed);

      if (cleanedLine.contains('\n')) {
        for (final sub in cleanedLine.split('\n')) {
          _processSingleLine(sub, defaultStyle, children);
        }
      } else {
        _processSingleLine(cleanedLine, defaultStyle, children);
      }
      i++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// Clean all unrendered HTML tags, entity codes, and raw line breaks.
  static String _cleanHtmlTags(String input) {
    if (input.isEmpty) return input;

    var s = input.replaceAll(r'\n', '\n').replaceAll(r'\r', '');

    // 1. Decode entities first so any &lt;br&gt; becomes <br> before regex matching
    s = s
        .replaceAll('&amp;lt;', '<')
        .replaceAll('&amp;gt;', '>')
        .replaceAll('&amp;amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ');

    // 2. Convert all variations of <br> tags into \n
    s = s.replaceAll(
        RegExp(r'<\s*/?\s*br\s*/?\s*>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'\\<br\\>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'\[br\]', caseSensitive: false), '\n');

    // 3. Other block elements
    s = s.replaceAll(
        RegExp(r'<\s*/?\s*p\b[^>]*>', caseSensitive: false), '\n');
    s = s.replaceAll(
        RegExp(r'<\s*/?\s*div\b[^>]*>', caseSensitive: false), '\n');
    s = s.replaceAll(
        RegExp(r'<\s*/?\s*span\b[^>]*>', caseSensitive: false), '');

    // 4. Bold and italic tags
    s = s.replaceAllMapped(
        RegExp(r'<\s*strong\b[^>]*>(.*?)<\s*/\s*strong\s*>',
            caseSensitive: false),
        (m) => '**${m[1]}**');
    s = s.replaceAllMapped(
        RegExp(r'<\s*b\b[^>]*>(.*?)<\s*/\s*b\s*>', caseSensitive: false),
        (m) => '**${m[1]}**');
    s = s.replaceAllMapped(
        RegExp(r'<\s*em\b[^>]*>(.*?)<\s*/\s*em\s*>', caseSensitive: false),
        (m) => '*${m[1]}*');
    s = s.replaceAllMapped(
        RegExp(r'<\s*i\b[^>]*>(.*?)<\s*/\s*i\s*>', caseSensitive: false),
        (m) => '*${m[1]}*');

    // 5. List items
    s = s.replaceAll(RegExp(r'<\s*/\s*li\s*>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<\s*li\b[^>]*>', caseSensitive: false), '• ');

    // 6. Strip any residual HTML tags
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');

    return s;
  }

  static bool _isTableRow(String line) {
    final t = line.trim();
    if (t.startsWith('|') && t.endsWith('|') && t.length > 2) return true;
    if (t.contains('|') && t.split('|').length >= 3) return true;
    return false;
  }

  static bool _isTableDivider(String line) {
    final t = line.trim();
    if (!t.contains('|') || !t.contains('-')) return false;
    final inner = t.replaceAll(RegExp(r'[\s\-:|]'), '');
    return inner.isEmpty;
  }

  static List<String> _extractCells(String row) {
    var trimmed = row.trim();
    if (trimmed.startsWith('|')) trimmed = trimmed.substring(1);
    if (trimmed.endsWith('|')) trimmed = trimmed.substring(0, trimmed.length - 1);
    return trimmed.split('|').map((c) => c.trim()).toList();
  }

  static bool _isDayOrStep(String text) {
    final lower = text.toLowerCase().replaceAll(RegExp(r'[\*\#\_\:\-]'), '').trim();
    final days = [
      'mon', 'monday', 'tue', 'tuesday', 'wed', 'wednesday',
      'thu', 'thursday', 'fri', 'friday', 'sat', 'saturday',
      'sun', 'sunday', 'day 1', 'day 2', 'day 3', 'day 4',
      'day 5', 'day 6', 'day 7', 'week 1', 'week 2', 'routine'
    ];
    return days.any((d) => lower.startsWith(d));
  }

  static bool _isHeaderRow(List<String> cells) {
    if (cells.isEmpty) return false;
    final first = cells.first.toLowerCase().replaceAll(RegExp(r'[\*\#\_\:\-]'), '').trim();
    if (_isDayOrStep(first)) return false;
    if (first.contains('day') ||
        first.contains('focus') ||
        first.contains('routine') ||
        first.contains('exercise') ||
        first.contains('date')) {
      return true;
    }
    return true;
  }

  static Widget? _buildTableWidget(List<String> tableLines, TextStyle defaultStyle) {
    final contentRows = tableLines
        .where((l) => !_isTableDivider(l) && l.trim().isNotEmpty)
        .toList();
    if (contentRows.isEmpty) return null;

    final firstCells = _extractCells(contentRows[0]);
    if (firstCells.isEmpty) return null;

    final isFirstRowHeader = _isHeaderRow(firstCells);
    final List<String> headers;
    final List<List<String>> dataRows = [];

    int startIndex;
    if (isFirstRowHeader) {
      headers = firstCells;
      startIndex = 1;
    } else {
      headers = ['Day', 'Focus', 'Warm-up', 'Workout', 'Notes'];
      startIndex = 0;
    }

    for (int idx = startIndex; idx < contentRows.length; idx++) {
      final rawCells = _extractCells(contentRows[idx]);
      final cleanedCells = rawCells
          .map((c) => _cleanHtmlTags(c).trim())
          .toList();
      if (cleanedCells.any((c) => c.isNotEmpty)) {
        dataRows.add(cleanedCells);
      }
    }

    if (dataRows.isEmpty) return null;

    final isSchedulePlan = headers.any((h) =>
        h.toLowerCase().contains('day') ||
        h.toLowerCase().contains('routine') ||
        h.toLowerCase().contains('exercise') ||
        h.toLowerCase().contains('workout') ||
        h.toLowerCase().contains('circuit') ||
        h.toLowerCase().contains('meal') ||
        h.toLowerCase().contains('step') ||
        h.toLowerCase().contains('focus') ||
        h.toLowerCase().contains('plan')) ||
        dataRows.any((row) => row.isNotEmpty && _isDayOrStep(row[0]));

    if (isSchedulePlan || headers.length >= 3) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: dataRows.map((cells) {
            return _buildPlanCard(headers, cells, defaultStyle);
          }).toList(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(AppTheme.surface),
            columns: headers.map((h) => DataColumn(
              label: Text(
                h.replaceAll('*', ''),
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.cyan),
              ),
            )).toList(),
            rows: dataRows.map((cells) {
              return DataRow(
                cells: List.generate(headers.length, (idx) {
                  final val = idx < cells.length ? cells[idx] : '';
                  return DataCell(
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text.rich(
                        TextSpan(children: _parseInlineSpans(val, defaultStyle)),
                      ),
                    ),
                  );
                }),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  static Widget _buildPlanCard(
    List<String> headers,
    List<String> cells,
    TextStyle defaultStyle,
  ) {
    final String title;
    final String subtitle;
    final String warmup;
    final String content;
    final String notes;

    if (cells.isEmpty) {
      return const SizedBox.shrink();
    } else if (cells.length == 1) {
      title = cells[0];
      subtitle = '';
      warmup = '';
      content = '';
      notes = '';
    } else if (cells.length == 2) {
      title = cells[0];
      subtitle = cells[1];
      warmup = '';
      content = '';
      notes = '';
    } else if (cells.length == 3) {
      title = cells[0];
      subtitle = cells[1];
      warmup = '';
      content = cells[2];
      notes = '';
    } else if (cells.length == 4) {
      title = cells[0];
      subtitle = cells[1];
      warmup = '';
      content = cells[2];
      notes = cells[3];
    } else {
      title = cells[0];
      subtitle = cells[1];
      warmup = cells[2];
      content = cells[3];
      notes = cells.sublist(4).join(' • ');
    }

    final cleanTitle = title.replaceAll(RegExp(r'[\*\#]'), '').trim();
    final cleanSubtitle = subtitle.replaceAll(RegExp(r'[\*\#]'), '').trim();
    final cleanWarmup = warmup.replaceAll(RegExp(r'[\#]'), '').trim();
    final cleanNotes = notes.replaceAll(RegExp(r'[\#]'), '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.cyan.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cyan.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fitness_center_rounded, size: 14, color: AppTheme.cyan),
                    const SizedBox(width: 5),
                    Text.rich(
                      TextSpan(
                        children: _parseInlineSpans(
                          cleanTitle,
                          const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.cyan,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (cleanSubtitle.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _parseInlineSpans(
                        cleanSubtitle,
                        const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          if (cleanWarmup.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.directions_run_rounded, size: 14, color: AppTheme.cyan),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Warm-up: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.cyan,
                              fontSize: 12.5,
                            ),
                          ),
                          ..._parseInlineSpans(
                            cleanWarmup,
                            defaultStyle.copyWith(
                              fontSize: 12.5,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (content.isNotEmpty) ...[
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content
                  .split('\n')
                  .where((l) => l.trim().isNotEmpty)
                  .map((line) {
                final trimmedLine = line.trim();
                final isBullet = trimmedLine.startsWith('•') ||
                    trimmedLine.startsWith('-') ||
                    trimmedLine.startsWith('*');
                var textPart = isBullet
                    ? trimmedLine.replaceFirst(RegExp(r'^[•\-\*]\s*'), '')
                    : trimmedLine;
                textPart = textPart
                    .replaceAll(RegExp(r'(?<=\*{1,2}|^|\s)#{1,6}\s*'), '')
                    .trim();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 5, left: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6, right: 8),
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: AppTheme.cyan,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: _parseInlineSpans(
                              textPart,
                              defaultStyle.copyWith(height: 1.4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          if (cleanNotes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      size: 15, color: Color(0xFFFFD166)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: _parseInlineSpans(
                          cleanNotes,
                          defaultStyle.copyWith(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static void _processSingleLine(
    String line,
    TextStyle defaultStyle,
    List<Widget> children,
  ) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      children.add(const SizedBox(height: 6));
      return;
    }

    // Markdown horizontal divider rule: ---, ***, ___
    if (trimmed == '---' ||
        trimmed == '***' ||
        trimmed == '___' ||
        RegExp(r'^-{3,}$').hasMatch(trimmed) ||
        RegExp(r'^\*{3,}$').hasMatch(trimmed)) {
      children.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(
            color: AppTheme.borderSubtle,
            height: 1,
            thickness: 1,
          ),
        ),
      );
      return;
    }

    // Normalize headings wrapped in bold/italics, e.g. **### Heading** or *### Heading*
    var normalized = trimmed;
    if (RegExp(r'^\*{1,2}\s*#{1,6}').hasMatch(normalized)) {
      normalized = normalized.replaceFirst(RegExp(r'^\*{1,2}\s*'), '');
      normalized = normalized.replaceAll(RegExp(r'\*{1,2}\s*:?$'), ':').trim();
    } else if (RegExp(r'^_{1,2}\s*#{1,6}').hasMatch(normalized)) {
      normalized = normalized.replaceFirst(RegExp(r'^_{1,2}\s*'), '');
      normalized = normalized.replaceAll(RegExp(r'_{1,2}\s*:?$'), ':').trim();
    }

    // Comprehensive Markdown Headings: 1 to 6 '#' symbols (#, ##, ###, ####, #####, ######)
    final headingMatch = RegExp(r'^(#{1,6})\s*(.*)$').firstMatch(normalized);
    if (headingMatch != null) {
      final level = headingMatch.group(1)!.length;
      var heading = headingMatch.group(2)!.trim();

      // Strip any trailing '#' characters e.g. "### Title ###"
      heading = heading.replaceAll(RegExp(r'\s*#+$'), '').trim();
      // Strip any duplicate leading '#' characters e.g. "##### ##### Title"
      heading = heading.replaceAll(RegExp(r'^#+\s*'), '').trim();
      // Strip any stray inner hash sequences
      heading = heading.replaceAll(RegExp(r'#{1,6}\s*'), '').trim();
      // Strip any residual <br>
      heading = heading
          .replaceAll(
              RegExp(r'<\s*/?\s*br\s*/?\s*>', caseSensitive: false), ' ')
          .trim();

      if (heading.isEmpty) {
        children.add(const SizedBox(height: 6));
        return;
      }

      if (level == 1) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 6),
            child: Text.rich(
              TextSpan(
                children: _parseInlineSpans(
                  heading,
                  const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      } else if (level == 2) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text.rich(
              TextSpan(
                children: _parseInlineSpans(
                  heading,
                  const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      } else if (level == 3) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text.rich(
              TextSpan(
                children: _parseInlineSpans(
                  heading,
                  const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      } else if (level == 4) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 3.5,
                  height: 14,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.cyan,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _parseInlineSpans(
                        heading,
                        const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.cyan,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // level 5 or 6 (##### or ######)
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 3,
                  height: 12,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.cyan.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _parseInlineSpans(
                        heading,
                        const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.cyan,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    if (trimmed.startsWith('• ') ||
        trimmed.startsWith('- ') ||
        trimmed.startsWith('* ')) {
      var bulletContent =
          trimmed.replaceFirst(RegExp(r'^[•\-\*]\s*'), '').trim();
      // Strip any stray heading hashes inside bullets, e.g. "- ##### Warm-up" or "- **### Warm-up**"
      bulletContent = bulletContent
          .replaceAll(RegExp(r'(?<=\*{1,2}|^|\s)#{1,6}\s*'), '');
      bulletContent = bulletContent
          .replaceAll(
              RegExp(r'<\s*/?\s*br\s*/?\s*>', caseSensitive: false), ' ')
          .trim();

      children.add(
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 7, right: 10),
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AppTheme.cyan,
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: _parseInlineSpans(bulletContent, defaultStyle),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (RegExp(r'^\d+[\.\)]\s').hasMatch(trimmed)) {
      final match = RegExp(r'^(\d+[\.\)])\s*(.*)$').firstMatch(trimmed);
      if (match != null) {
        final numberPart = match.group(1)!;
        var contentPart = match.group(2)!.trim();
        // Strip any stray heading hashes inside numbered items, e.g. "1. ##### Exercise" or "1. **### Exercise**"
        contentPart = contentPart
            .replaceAll(RegExp(r'(?<=\*{1,2}|^|\s)#{1,6}\s*'), '');
        contentPart = contentPart
            .replaceAll(
                RegExp(r'<\s*/?\s*br\s*/?\s*>', caseSensitive: false), ' ')
            .trim();

        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    numberPart,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.cyan,
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: _parseInlineSpans(contentPart, defaultStyle),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        var cleanLine = trimmed
            .replaceAll(RegExp(r'(?<=\*{1,2}|^|\s)#{1,6}\s*'), '')
            .replaceAll(
                RegExp(r'<\s*/?\s*br\s*/?\s*>', caseSensitive: false), ' ')
            .trim();
        if (cleanLine.isNotEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text.rich(
                TextSpan(
                  children: _parseInlineSpans(cleanLine, defaultStyle),
                ),
              ),
            ),
          );
        }
      }
    } else {
      var cleanLine = trimmed;
      // If line is just hashes, skip it or render spacer
      if (RegExp(r'^#+\s*$').hasMatch(cleanLine)) {
        children.add(const SizedBox(height: 6));
        return;
      }
      // Strip leading hashes
      cleanLine = cleanLine.replaceAll(RegExp(r'^#{1,6}\s*'), '');
      // Strip hashes after bold/italic markers e.g. **### text**
      cleanLine = cleanLine
          .replaceAll(RegExp(r'(?<=\*{1,2}|^|\s)#{1,6}\s*'), '');
      // Strip trailing hashes
      cleanLine = cleanLine.replaceAll(RegExp(r'\s*#+$'), '');
      // Strip any stray <br>
      cleanLine = cleanLine
          .replaceAll(
              RegExp(r'<\s*/?\s*br\s*/?\s*>', caseSensitive: false), ' ')
          .trim();

      if (cleanLine.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(
              TextSpan(
                children: _parseInlineSpans(cleanLine, defaultStyle),
              ),
            ),
          ),
        );
      }
    }
  }

  static List<InlineSpan> _parseInlineSpans(String text, TextStyle base) {
    var cleaned = _cleanHtmlTags(text);
    // Remove any leftover heading hashes embedded in inline text (e.g. "**### Title**" or "### Title")
    cleaned = cleaned.replaceAll(RegExp(r'#{1,6}\s*'), '');
    // Clean any remaining raw <br> variants
    cleaned = cleaned.replaceAll(
        RegExp(r'<\s*/?\s*br\s*/?\s*>', caseSensitive: false), ' ');

    final spans = <InlineSpan>[];
    final regex = RegExp(r'(\*\*(.*?)\*\*|\*(.*?)\*|`(.*?)`)');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(cleaned)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: cleaned.substring(lastMatchEnd, match.start),
          style: base,
        ));
      }

      final fullMatch = match.group(0)!;
      if (fullMatch.startsWith('**') && fullMatch.endsWith('**')) {
        spans.add(TextSpan(
          text: match.group(2) ?? '',
          style: base.copyWith(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ));
      } else if (fullMatch.startsWith('*') && fullMatch.endsWith('*')) {
        spans.add(TextSpan(
          text: match.group(3) ?? '',
          style: base.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (fullMatch.startsWith('`') && fullMatch.endsWith('`')) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Text(
              match.group(4) ?? '',
              style: base.copyWith(
                fontFamily: 'monospace',
                fontSize: (base.fontSize ?? 14) * 0.9,
                color: AppTheme.cyan,
              ),
            ),
          ),
        ));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < cleaned.length) {
      spans.add(TextSpan(
        text: cleaned.substring(lastMatchEnd),
        style: base,
      ));
    }

    return spans;
  }
}
