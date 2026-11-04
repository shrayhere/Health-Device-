import 'package:flutter/material.dart';

import '../models/health_metrics.dart';
import '../repositories/health_repository.dart';
import '../theme/app_theme.dart';

/// Screen E1: LED Settings.
/// Provides a clean hardware ON/OFF toggle for the physical 4-pin RGB LED indicator.
class LedSettingsScreen extends StatelessWidget {
  final HealthRepository repository;

  const LedSettingsScreen({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;

    return ValueListenableBuilder<LedSettingsState>(
      valueListenable: repository.ledSettings,
      builder: (context, ledState, _) {
        final isEnabled = ledState.isEnabled;

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'LED Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 20,
                vertical: 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Enable / Disable LED Toggle Card
                      Material(
                        color: AppTheme.card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: AppTheme.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isEnabled
                                          ? AppTheme.cyan.withValues(alpha: 0.15)
                                          : AppTheme.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isEnabled
                                            ? AppTheme.cyan.withValues(alpha: 0.4)
                                            : AppTheme.border,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.lightbulb_rounded,
                                      color: isEnabled
                                          ? AppTheme.cyan
                                          : AppTheme.textMuted,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Enable LED',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          isEnabled ? 'Status: ON (Active)' : 'Status: OFF (Disabled)',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isEnabled
                                                ? AppTheme.cyan
                                                : AppTheme.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: isEnabled,
                                    onChanged: (val) {
                                      repository.toggleLedEnabled(val);
                                    },
                                    activeThumbColor: AppTheme.primaryBlueLight,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              const Text(
                                'Hardware 4-pin RGB status diode indicator on your HealthDevice. When turned off, the physical diode remains completely off to conserve battery and eliminate light emissions.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.45,
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
              ),
            ),
          ),
        );
      },
    );
  }
}
