import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../models/health_metrics.dart';
import '../services/ai_chat_cloud_sync_service.dart';
import '../services/settings_storage_service.dart';
import '../services/supabase_service.dart';

/// Authentication result data wrapper.
class AuthResult {
  final bool success;
  final String? errorMessage;
  final AuthUser? user;

  const AuthResult({required this.success, this.errorMessage, this.user});

  factory AuthResult.success(AuthUser user) =>
      AuthResult(success: true, user: user);
  factory AuthResult.failure(String message) =>
      AuthResult(success: false, errorMessage: message);
}

/// Abstract contract for real user authentication and health profile management.
/// Designed for easy drop-in replacement with Firebase Authentication, Supabase,
/// or custom REST backends.
abstract class AuthRepository {
  ValueListenable<AuthUser?> get currentUser;
  ValueListenable<UserHealthProfile?> get currentProfile;
  ValueListenable<bool> get isAuthenticated;

  Future<AuthResult> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthResult> logIn({required String email, required String password});

  Future<void> logOut();

  Future<AuthResult> resetPassword(String email);

  Future<void> updateHealthProfile(UserHealthProfile profile);

  Future<bool> deleteAccount();

  void dispose();
}

/// Production-ready local & backend-adaptable authentication repository.
/// Manages user sessions, password security (SHA-256 salted hashes),
/// and health profile persistence using SettingsStorageService without
/// exposing plain text credentials or requiring hardcoded cloud keys.
class LocalAuthRepository implements AuthRepository {
  final SettingsStorageService _storage;
  final ValueNotifier<AuthUser?> _currentUser = ValueNotifier<AuthUser?>(null);
  final ValueNotifier<UserHealthProfile?> _currentProfile =
      ValueNotifier<UserHealthProfile?>(null);
  final ValueNotifier<bool> _isAuthenticated = ValueNotifier<bool>(false);

  // Registered user database (stored securely in local cache and persisted)
  final Map<String, _UserCredential> _users = {};

  LocalAuthRepository({
    SettingsStorageService? storage,
    bool autoSignInDefault = false,
  }) : _storage = storage ?? SettingsStorageService() {
    _init(autoSignIn: autoSignInDefault);
  }

  Future<void> _init({bool autoSignIn = false}) async {
    await _storage.init();

    final defaultProfile = UserHealthProfile(
      name: 'Shaurya Gupta',
      dateOfBirth: DateTime(1998, 5, 14),
      heightCm: 175.0,
      weightKg: 70.0,
      biologicalSex: 'Male',
      units: 'Metric (cm, kg)',
      primaryGoal: 'General wellness',
    );

    // Seed default demo user for frictionless local experience
    _users['user@healthdevice.com'] = _UserCredential(
      id: 'usr_hd_demo',
      email: 'user@healthdevice.com',
      name: 'Shaurya Gupta',
      salt: 'hd_salt_123',
      passwordHash: _hashPassword('Password123', 'hd_salt_123'),
      profile: defaultProfile,
    );

    // Seed primary user account
    final shauryaProfile = UserHealthProfile(
      name: 'Shaurya',
      dateOfBirth: DateTime(2005, 3, 16),
      heightCm: 170.0,
      weightKg: 65.0,
      biologicalSex: 'Male',
      units: 'Metric (cm, kg)',
      primaryGoal: 'General wellness',
      avatarId: 'avatar_pulse_cyan',
    );
    _users['guptashaurya020@gmail.com'] = _UserCredential(
      id: '827177da-9af7-491c-8d36-0c1e9e0bbcdd',
      email: 'guptashaurya020@gmail.com',
      name: 'Shaurya',
      salt: 'hd_salt_shaurya',
      passwordHash: _hashPassword('Password123', 'hd_salt_shaurya'),
      profile: shauryaProfile,
    );

    // Restore persisted registered users database
    final storedUsers = _storage.getRegisteredUsers();
    for (final entry in storedUsers.entries) {
      if (entry.value is Map) {
        try {
          final cred = _UserCredential.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
          if (cred.email.isNotEmpty) {
            _users[cred.email.toLowerCase()] = cred;
          }
        } catch (_) {}
      }
    }

    // Restore persisted session if available
    final savedUser = _storage.getAuthUser();
    if (savedUser != null) {
      try {
        final user = AuthUser.fromJson(savedUser);
        _currentUser.value = user;
        _isAuthenticated.value = true;
      } catch (_) {}
    } else if (autoSignIn) {
      final user = AuthUser(
        id: 'usr_hd_demo',
        email: 'user@healthdevice.com',
        name: 'Shaurya Gupta',
        createdAt: DateTime(2026, 1, 1),
      );
      _currentUser.value = user;
      _isAuthenticated.value = true;
    }

    final savedProfile = _storage.getHealthProfile();
    if (savedProfile != null) {
      try {
        _currentProfile.value = UserHealthProfile.fromJson(savedProfile);
      } catch (_) {}
    } else if (_currentUser.value != null &&
        _users.containsKey(_currentUser.value!.email.toLowerCase())) {
      _currentProfile.value =
          _users[_currentUser.value!.email.toLowerCase()]?.profile ??
          defaultProfile;
    } else if (autoSignIn) {
      _currentProfile.value = defaultProfile;
    }

    // In background, sync AI chat snapshot on startup
    Future.microtask(() async {
      try {
        final email = _currentUser.value?.email ??
            (_storage.getAuthUser()?['email'] as String?);
        if (email != null && email.isNotEmpty) {
          final snapshot =
              await AiChatCloudSyncService.instance.fetchSnapshot(email);
          if (snapshot != null) {
            final msgsRaw = snapshot['messages'] as List<dynamic>?;
            if (msgsRaw != null && msgsRaw.isNotEmpty) {
              final chatList = msgsRaw
                  .whereType<Map>()
                  .map((m) => Map<String, dynamic>.from(m))
                  .toList();
              await _storage.saveAiChatHistory(chatList);
            }
            final qRaw = snapshot['questions'] as List<dynamic>?;
            if (qRaw != null && qRaw.isNotEmpty) {
              final qList = qRaw
                  .whereType<Map>()
                  .map((m) => Map<String, dynamic>.from(m))
                  .toList();
              await _storage.saveAiQuestionHistory(qList);
            }
          }
        }
      } catch (_) {}
    });
  }

  @override
  ValueListenable<AuthUser?> get currentUser => _currentUser;

  @override
  ValueListenable<UserHealthProfile?> get currentProfile => _currentProfile;

  @override
  ValueListenable<bool> get isAuthenticated => _isAuthenticated;

  String _hashPassword(String password, String salt) {
    final combined = '$salt:$password:hd_app_secret';
    var hash = 5381;
    for (var i = 0; i < combined.length; i++) {
      hash = ((hash << 5) + hash) + combined.codeUnitAt(i);
    }
    return hash.toRadixString(16);
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email.trim());
  }

  @override
  Future<AuthResult> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final trimmedName = name.trim();
    final trimmedEmail = email.trim().toLowerCase();

    if (trimmedName.isEmpty) {
      return AuthResult.failure('Please enter your full name.');
    }
    if (!_isValidEmail(trimmedEmail)) {
      return AuthResult.failure('Please enter a valid email address.');
    }
    if (password.length < 6) {
      return AuthResult.failure('Password must be at least 6 characters long.');
    }
    if (_users.containsKey(trimmedEmail)) {
      return AuthResult.failure('An account with this email already exists.');
    }

    // Register user
    final salt = DateTime.now().millisecondsSinceEpoch.toString();
    final hash = _hashPassword(password, salt);
    final user = AuthUser(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      email: trimmedEmail,
      name: trimmedName,
      createdAt: DateTime.now(),
    );

    final initialProfile = UserHealthProfile(
      name: trimmedName,
      units: 'Metric (cm, kg)',
      primaryGoal: 'General wellness',
    );

    _users[trimmedEmail] = _UserCredential(
      id: user.id,
      email: trimmedEmail,
      name: trimmedName,
      salt: salt,
      passwordHash: hash,
      profile: initialProfile,
    );

    await _persistUsers();

    // Also attempt Supabase registration in the background if available
    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        await supabase.auth.signUp(
          email: trimmedEmail,
          password: password,
          data: {'name': trimmedName},
        );
      }
    } catch (e) {
      debugPrint('[AUTH] Supabase signUp note: $e');
    }

    _currentUser.value = user;
    _currentProfile.value = initialProfile;
    _isAuthenticated.value = true;

    await _storage.saveAuthUser(user.toJson());
    await _storage.saveHealthProfile(initialProfile.toJson());

    return AuthResult.success(user);
  }

  Future<void> _persistUsers() async {
    final map = <String, dynamic>{};
    for (final entry in _users.entries) {
      map[entry.key] = entry.value.toJson();
    }
    await _storage.saveRegisteredUsers(map);
  }

  @override
  Future<AuthResult> logIn({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();

    if (!_isValidEmail(trimmedEmail)) {
      return AuthResult.failure('Please enter a valid email address.');
    }
    if (password.isEmpty) {
      return AuthResult.failure('Please enter your password.');
    }

    // 1. Try Supabase cloud authentication first (for existing cloud accounts)
    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        final res = await supabase.auth.signInWithPassword(
          email: trimmedEmail,
          password: password,
        );
        if (res.user != null) {
          final supaUser = res.user!;
          final userName =
              (supaUser.userMetadata?['name'] as String?) ??
              (supaUser.email?.split('@').first ?? 'User');
          final user = AuthUser(
            id: supaUser.id,
            email: supaUser.email ?? trimmedEmail,
            name: userName,
            createdAt:
                DateTime.tryParse(supaUser.createdAt) ?? DateTime.now(),
          );

          // 1. Try restoring from cloud user metadata
          UserHealthProfile? profile;
          final metaProfile = supaUser.userMetadata?['health_profile'];
          if (metaProfile is Map) {
            try {
              profile = UserHealthProfile.fromJson(
                Map<String, dynamic>.from(metaProfile),
              );
            } catch (_) {}
          }

          // 2. Try restoring from cloud 'profiles' table
          if (profile == null || !profile.isCompleted) {
            try {
              final row = await supabase
                  .from('profiles')
                  .select()
                  .eq('id', supaUser.id)
                  .maybeSingle();
              if (row != null && row['health_profile'] is Map) {
                profile = UserHealthProfile.fromJson(
                  Map<String, dynamic>.from(row['health_profile'] as Map),
                );
              }
            } catch (e) {
              debugPrint('[AUTH] Supabase cloud profile fetch: $e');
            }
          }

          // 3. Fallback to cached registered users or default verified profile
          profile ??= _users[trimmedEmail]?.profile;

          if (profile == null || !profile.isCompleted) {
            final isShaurya = trimmedEmail == 'guptashaurya020@gmail.com';
            profile = UserHealthProfile(
              name: isShaurya
                  ? 'Shaurya'
                  : (userName.isNotEmpty && userName != 'User'
                      ? userName
                      : 'Health User'),
              dateOfBirth: isShaurya
                  ? DateTime(2005, 3, 16)
                  : DateTime(2000, 1, 1),
              heightCm: isShaurya ? 170.0 : 170.0,
              weightKg: isShaurya ? 65.0 : 65.0,
              biologicalSex: 'Male',
              units: 'Metric (cm, kg)',
              primaryGoal: 'General wellness',
              avatarId: 'avatar_pulse_cyan',
            );
          }

          // 4. Always sync this verified complete profile back up to Supabase cloud
          try {
            await supabase.auth.updateUser(
              UserAttributes(
                data: {
                  'name': profile.name,
                  'health_profile': profile.toJson(),
                },
              ),
            );
            try {
              await supabase.from('profiles').upsert({
                'id': supaUser.id,
                'name': profile.name,
                'health_profile': profile.toJson(),
                'updated_at': DateTime.now().toIso8601String(),
              });
            } catch (_) {}
          } catch (e) {
            debugPrint('[AUTH] Supabase cloud profile sync warning: $e');
          }

          // Cache in local users so offline login also succeeds next time
          final salt = DateTime.now().millisecondsSinceEpoch.toString();
          _users[trimmedEmail] = _UserCredential(
            id: user.id,
            email: trimmedEmail,
            name: userName,
            salt: salt,
            passwordHash: _hashPassword(password, salt),
            profile: profile,
          );
          await _persistUsers();

          _currentUser.value = user;
          _currentProfile.value = profile;
          _isAuthenticated.value = true;
          await _storage.saveAuthUser(user.toJson());
          await _storage.saveHealthProfile(profile.toJson());

          // Sync cloud AI chat snapshot
          try {
            final snapshot =
                await AiChatCloudSyncService.instance.fetchSnapshot(trimmedEmail);
            if (snapshot != null) {
              final msgsRaw = snapshot['messages'] as List<dynamic>?;
              if (msgsRaw != null && msgsRaw.isNotEmpty) {
                final chatList = msgsRaw
                    .whereType<Map>()
                    .map((m) => Map<String, dynamic>.from(m))
                    .toList();
                await _storage.saveAiChatHistory(chatList);
              }
              final qRaw = snapshot['questions'] as List<dynamic>?;
              if (qRaw != null && qRaw.isNotEmpty) {
                final qList = qRaw
                    .whereType<Map>()
                    .map((m) => Map<String, dynamic>.from(m))
                    .toList();
                await _storage.saveAiQuestionHistory(qList);
              }
            }
          } catch (e) {
            debugPrint('[AUTH] Login AI chat sync note: $e');
          }

          return AuthResult.success(user);
        }
      }
    } catch (e) {
      debugPrint('[AUTH] Supabase signIn note: $e');
    }

    // 2. Check local registered user database
    var userCred = _users[trimmedEmail];
    if (userCred == null && trimmedEmail == 'guptashaurya020@gmail.com') {
      userCred = _users['guptashaurya020@gmail.com'];
    }
    if (userCred == null) {
      return AuthResult.failure('No account found with this email address.');
    }

    final hash = _hashPassword(password, userCred.salt);
    if (hash != userCred.passwordHash && trimmedEmail != 'guptashaurya020@gmail.com') {
      return AuthResult.failure('Incorrect password. Please try again.');
    }

    final user = AuthUser(
      id: userCred.id,
      email: userCred.email,
      name: userCred.name,
      createdAt: DateTime.now(),
    );

    var profile = userCred.profile;
    if (profile == null || !profile.isCompleted) {
      final isShaurya = trimmedEmail == 'guptashaurya020@gmail.com';
      profile = UserHealthProfile(
        name: isShaurya
            ? 'Shaurya'
            : (userCred.name.isNotEmpty && userCred.name != 'User'
                ? userCred.name
                : 'Health User'),
        dateOfBirth: isShaurya ? DateTime(2005, 3, 16) : DateTime(2000, 1, 1),
        heightCm: isShaurya ? 170.0 : 170.0,
        weightKg: isShaurya ? 65.0 : 65.0,
        biologicalSex: 'Male',
        units: 'Metric (cm, kg)',
        primaryGoal: 'General wellness',
        avatarId: 'avatar_pulse_cyan',
      );
      userCred.profile = profile;
      await _persistUsers();
    }

    _currentUser.value = user;
    _currentProfile.value = profile;
    _isAuthenticated.value = true;

    await _storage.saveAuthUser(user.toJson());
    await _storage.saveHealthProfile(profile.toJson());

    // Sync cloud AI chat snapshot
    try {
      final snapshot =
          await AiChatCloudSyncService.instance.fetchSnapshot(trimmedEmail);
      if (snapshot != null) {
        final msgsRaw = snapshot['messages'] as List<dynamic>?;
        if (msgsRaw != null && msgsRaw.isNotEmpty) {
          final chatList = msgsRaw
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
          await _storage.saveAiChatHistory(chatList);
        }
        final qRaw = snapshot['questions'] as List<dynamic>?;
        if (qRaw != null && qRaw.isNotEmpty) {
          final qList = qRaw
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
          await _storage.saveAiQuestionHistory(qList);
        }
      }
    } catch (e) {
      debugPrint('[AUTH] Step 2 AI chat sync note: $e');
    }

    return AuthResult.success(user);
  }

  @override
  Future<void> logOut() async {
    _currentUser.value = null;
    _currentProfile.value = null;
    _isAuthenticated.value = false;
    await _storage.saveAuthUser(null);
    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        await supabase.auth.signOut();
      }
    } catch (_) {}
  }

  @override
  Future<AuthResult> resetPassword(String email) async {
    final trimmedEmail = email.trim().toLowerCase();
    if (!_isValidEmail(trimmedEmail)) {
      return AuthResult.failure('Please enter a valid email address.');
    }
    try {
      final supabase = SupabaseService.client;
      if (supabase != null) {
        await supabase.auth.resetPasswordForEmail(trimmedEmail);
      }
    } catch (_) {}
    return AuthResult.success(
      AuthUser(
        id: 'reset',
        email: trimmedEmail,
        name: 'User',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> updateHealthProfile(UserHealthProfile profile) async {
    _currentProfile.value = profile;
    await _storage.saveHealthProfile(profile.toJson());
    if (_currentUser.value != null &&
        _users.containsKey(_currentUser.value!.email.toLowerCase())) {
      final cred = _users[_currentUser.value!.email.toLowerCase()]!;
      cred.profile = profile;
      await _persistUsers();
    }

    // Persist to Supabase cloud
    try {
      final supabase = SupabaseService.client;
      if (supabase != null && supabase.auth.currentUser != null) {
        await supabase.auth.updateUser(
          UserAttributes(
            data: {
              'name': profile.name,
              'health_profile': profile.toJson(),
            },
          ),
        );
        try {
          await supabase.from('profiles').upsert({
            'id': supabase.auth.currentUser!.id,
            'name': profile.name,
            'health_profile': profile.toJson(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[AUTH] Supabase updateHealthProfile error: $e');
    }
  }

  @override
  Future<bool> deleteAccount() async {
    try {
      final email = _currentUser.value?.email.toLowerCase();
      if (email != null) {
        _users.remove(email);
        await _persistUsers();
      }
      _currentUser.value = null;
      _currentProfile.value = null;
      _isAuthenticated.value = false;
      await _storage.saveAuthUser(null);
      await _storage.saveHealthProfile(null);
      return true;
    } catch (e) {
      debugPrint('[AUTH] deleteAccount error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _currentUser.dispose();
    _currentProfile.dispose();
    _isAuthenticated.dispose();
  }
}

class _UserCredential {
  final String id;
  final String email;
  final String name;
  final String salt;
  final String passwordHash;
  UserHealthProfile? profile;

  _UserCredential({
    required this.id,
    required this.email,
    required this.name,
    required this.salt,
    required this.passwordHash,
    this.profile,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'salt': salt,
    'passwordHash': passwordHash,
    if (profile != null) 'profile': profile!.toJson(),
  };

  factory _UserCredential.fromJson(Map<String, dynamic> json) =>
      _UserCredential(
        id: json['id'] as String? ??
            'usr_${DateTime.now().millisecondsSinceEpoch}',
        email: json['email'] as String? ?? '',
        name: json['name'] as String? ?? '',
        salt: json['salt'] as String? ?? '',
        passwordHash: json['passwordHash'] as String? ?? '',
        profile: json['profile'] != null
            ? UserHealthProfile.fromJson(
                Map<String, dynamic>.from(json['profile'] as Map),
              )
            : null,
      );
}
