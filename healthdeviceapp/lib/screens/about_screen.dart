import 'package:flutter/material.dart';

import '../repositories/health_repository.dart';
import '../theme/app_theme.dart';

/// Screen: About section displaying App & Device information,
/// licenses, privacy guidelines, and technical specifications.
class AboutScreen extends StatelessWidget {
  final HealthRepository repository;

  const AboutScreen({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 800;
    final devInfo = repository.deviceInfo.value;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'About',
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
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  // App Capsule Branding Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 84,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppTheme.cyan.withValues(alpha: 0.8),
                              width: 2.0,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: AppTheme.cyan.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.circle,
                                  size: 6,
                                  color: AppTheme.cyan,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'HealthDevice Companion',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Version 1.0.0 (Build 1)',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Hardware & Firmware Specs
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('Device Model', devInfo.model),
                        const Divider(height: 1),
                        _buildInfoRow(
                          'Firmware Version',
                          devInfo.firmwareVersion.isNotEmpty
                              ? devInfo.firmwareVersion
                              : 'Awaiting BLE Sync',
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          'Hardware Revision',
                          devInfo.hardwareRevision,
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          'Microcontroller',
                          'ESP32-C3 (32-bit RISC-V @ 160 MHz, 2.4 GHz Wi-Fi + BLE 5.0)',
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          'Optical Sensor',
                          'PPG Photoplethysmography (HR + SpO₂)',
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          'Motion Sensor',
                          '3-Axis Accelerometer (Posture & Fall)',
                        ),
                        const Divider(height: 1),
                        _buildInfoRow(
                          'Display',
                          '0.96" Monochrome I2C OLED (128x64)',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Legal, Privacy & Licenses Card
                  Material(
                    color: AppTheme.card,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.description_outlined,
                              size: 20,
                              color: AppTheme.textSecondary,
                            ),
                            title: const Text(
                              'Open Source Licenses',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: AppTheme.textMuted,
                            ),
                            onTap: () {
                              showLicensePage(
                                context: context,
                                applicationName: 'HealthDevice',
                                applicationVersion: 'v1.0.0',
                                applicationIcon: const Icon(
                                  Icons.favorite_rounded,
                                  color: AppTheme.cyan,
                                ),
                              );
                            },
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(
                              Icons.privacy_tip_outlined,
                              size: 20,
                              color: AppTheme.textSecondary,
                            ),
                            title: const Text(
                              'Privacy & Health Data Policy',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: AppTheme.textMuted,
                            ),
                            onTap: () => _showPrivacyDialog(context),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(
                              Icons.health_and_safety_outlined,
                              size: 20,
                              color: AppTheme.textSecondary,
                            ),
                            title: const Text(
                              'Medical Disclaimer',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: AppTheme.textMuted,
                            ),
                            onTap: () => _showDisclaimerDialog(context),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Text(
          'Privacy & Data Policy',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Your biometric and health data (Heart rate, SpO₂, Posture, Steps) remains securely cached on your device. Passwords and credentials are never stored in plaintext or logged. When using AI assistance, only relevant health summaries and metrics are formatted for guidance.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.45,
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryBlueLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDisclaimerDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Text(
          'Medical Disclaimer',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'The HealthDevice wearable companion and integrated AI assistant provide personal fitness and general wellness guidance only. They are not medical devices and do not provide medical diagnosis, treatment, or clinical assessment. Always consult a certified healthcare professional for medical concerns.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.45,
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryBlueLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('I Understand'),
          ),
        ],
      ),
    );
  }
}
