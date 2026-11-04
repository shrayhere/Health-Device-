import 'package:flutter/material.dart';

import '../repositories/auth_repository.dart';
import '../repositories/health_repository.dart';
import '../theme/app_theme.dart';
import 'welcome_screen.dart';

/// Screen: Account & Application Settings (accessed exclusively from Profile top-right).
///
/// Contains account-level and application-level actions:
/// - Account Management & Session Status
/// - Privacy & Data Controls
/// - App Preferences (Theme, Units, Haptics)
/// - About Application
/// - Sign Out
/// - Multi-step Delete Account Flow
///
/// (Strictly NO hardware/device settings here. Hardware settings live under Device -> Device Settings).
class SettingsScreen extends StatefulWidget {
  final HealthRepository repository;
  final AuthRepository? authRepository;

  const SettingsScreen({
    super.key,
    required this.repository,
    this.authRepository,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AuthRepository _auth;

  @override
  void initState() {
    super.initState();
    _auth = widget.authRepository ?? LocalAuthRepository();
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Text(
          'Log Out',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out of your HealthDevice account? Your saved health telemetry and device preferences will remain safe.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              widget.repository.resetForUser(null);
              await _auth.logOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (c) => WelcomeScreen(
                      authRepository: _auth,
                      healthRepository: widget.repository,
                    ),
                  ),
                  (route) => false,
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.heartRateRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  /// Multi-step permanent account deletion flow:
  /// Profile -> Settings -> Delete Account -> Confirmation Dialog 1 -> Final Confirmation Dialog 2 -> Delete
  void _startDeleteAccountFlow() {
    // Step 1: Initial Warning & Information Dialog
    showDialog(
      context: context,
      builder: (ctx1) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.heartRateRed,
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'Delete Account',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deleting your account will permanently erase:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '• Your cloud account profile and credentials',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            SizedBox(height: 4),
            Text(
              '• Historical health telemetry (Heart rate, SpO₂, Posture, Activity)',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            SizedBox(height: 4),
            Text(
              '• Custom app avatars, personal biometrics, and health goals',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            SizedBox(height: 4),
            Text(
              '• Locally cached cloud sync data',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            SizedBox(height: 12),
            Text(
              'This action is irreversible. You cannot recover this data once deleted.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.heartRateRed,
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx1).pop(),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx1).pop();
              _showFinalDeleteConfirmation();
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.heartRateRed,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Continue to Final Step'),
          ),
        ],
      ),
    );
  }

  /// Step 2: Final explicit confirmation step
  void _showFinalDeleteConfirmation() {
    final deleteTextController = TextEditingController();
    bool canConfirm = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx2) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppTheme.heartRateRed, width: 1.5),
          ),
          title: const Text(
            'Final Confirmation Required',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.heartRateRed,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To permanently delete your HealthDevice account and revoke all data, type "DELETE" below to confirm.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: deleteTextController,
                autofocus: true,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Type DELETE',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.heartRateRed),
                  ),
                ),
                onChanged: (val) {
                  setDialogState(() {
                    canConfirm = val.trim().toUpperCase() == 'DELETE';
                  });
                },
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx2).pop(),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: canConfirm
                  ? () async {
                      Navigator.of(ctx2).pop();
                      widget.repository.resetForUser(null);
                      final success = await _auth.deleteAccount();
                      if (!mounted) return;
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Account and cloud data permanently deleted.',
                            ),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppTheme.cardLight,
                          ),
                        );
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (c) => WelcomeScreen(
                              authRepository: _auth,
                              healthRepository: widget.repository,
                            ),
                          ),
                          (route) => false,
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Failed to delete account. Please verify network connectivity.',
                            ),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppTheme.heartRateRed,
                          ),
                        );
                      }
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.heartRateRed,
                disabledBackgroundColor: AppTheme.heartRateRed.withValues(
                  alpha: 0.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Permanently Delete'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;
    final user = _auth.currentUser.value;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 20,
            vertical: 16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Account Section
                  _buildSectionHeader('ACCOUNT & SESSION'),
                  Material(
                    color: AppTheme.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.person_rounded,
                            size: 20,
                            color: AppTheme.cyan,
                          ),
                          title: Text(
                            user?.name ?? 'User Account',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            user?.email ?? 'Offline session',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.cloud_sync_rounded,
                            size: 20,
                            color: AppTheme.goodPostureGreen,
                          ),
                          title: const Text(
                            'Account Sync Status',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: const Text(
                            'Local profile active • Cloud sync ready',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.goodPostureGreen.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.goodPostureGreen,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Privacy & Data Section
                  _buildSectionHeader('PRIVACY & CLOUD DATA'),
                  Material(
                    color: AppTheme.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.lock_outline_rounded,
                            size: 20,
                            color: AppTheme.textSecondary,
                          ),
                          title: const Text(
                            'Health Data Privacy',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: const Text(
                            'Biometrics remain client-side and encrypted locally',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.wifi_password_rounded,
                            size: 20,
                            color: AppTheme.textSecondary,
                          ),
                          title: const Text(
                            'Wi-Fi Credentials Protection',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: const Text(
                            'Wi-Fi passwords are stored locally and never synced to AI',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. App Preferences
                  _buildSectionHeader('APPLICATION PREFERENCES'),
                  Material(
                    color: AppTheme.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.dark_mode_rounded,
                            size: 20,
                            color: AppTheme.cyan,
                          ),
                          title: const Text(
                            'Theme Appearance',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: const Text(
                            'Dark Navy (AMOLED high-contrast)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.cyan,
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.vibration_rounded,
                            size: 20,
                            color: AppTheme.textSecondary,
                          ),
                          title: const Text(
                            'Haptic Feedback',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          trailing: Switch(
                            value: true,
                            onChanged: (val) {},
                            activeThumbColor: AppTheme.cyan,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. Session & Account Actions
                  _buildSectionHeader('ACCOUNT ACTIONS'),
                  Material(
                    color: AppTheme.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Log Out
                        ListTile(
                          leading: const Icon(
                            Icons.logout_rounded,
                            size: 20,
                            color: AppTheme.textSecondary,
                          ),
                          title: const Text(
                            'Log Out',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: const Text(
                            'Sign out of this session. Saved device preferences remain.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: AppTheme.textMuted,
                          ),
                          onTap: _confirmLogout,
                        ),
                        const Divider(height: 1),

                        // Delete Account (Multi-step confirmation)
                        ListTile(
                          leading: const Icon(
                            Icons.delete_forever_rounded,
                            size: 20,
                            color: AppTheme.heartRateRed,
                          ),
                          title: const Text(
                            'Delete Account',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.heartRateRed,
                            ),
                          ),
                          subtitle: const Text(
                            'Permanently remove cloud account and all associated telemetry.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: AppTheme.heartRateRed,
                          ),
                          onTap: _startDeleteAccountFlow,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // App Version Notice
                  const Center(
                    child: Text(
                      'HealthDevice Companion App v1.0.0+1\nConnected to ESP32-C3 Firmware Ecosystem',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
