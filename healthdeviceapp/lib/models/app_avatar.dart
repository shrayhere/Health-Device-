import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Preset app avatar definition.
class AppAvatarPreset {
  final String id;
  final String label;
  final IconData icon;
  final Color primaryColor;
  final Color backgroundColor;

  const AppAvatarPreset({
    required this.id,
    required this.label,
    required this.icon,
    required this.primaryColor,
    required this.backgroundColor,
  });
}

/// Catalog of customizable health app avatars.
class AppAvatarCatalog {
  AppAvatarCatalog._();

  static const List<AppAvatarPreset> presets = [
    AppAvatarPreset(
      id: 'avatar_pulse_cyan',
      label: 'Cyan Pulse',
      icon: Icons.monitor_heart_rounded,
      primaryColor: AppTheme.cyan,
      backgroundColor: Color(0xFF0C243B),
    ),
    AppAvatarPreset(
      id: 'avatar_heart_red',
      label: 'Vital Heart',
      icon: Icons.favorite_rounded,
      primaryColor: AppTheme.heartRateRed,
      backgroundColor: Color(0xFF3B1218),
    ),
    AppAvatarPreset(
      id: 'avatar_runner_blue',
      label: 'Active Runner',
      icon: Icons.directions_run_rounded,
      primaryColor: AppTheme.primaryBlueLight,
      backgroundColor: Color(0xFF102347),
    ),
    AppAvatarPreset(
      id: 'avatar_zen_green',
      label: 'Zen Balance',
      icon: Icons.spa_rounded,
      primaryColor: AppTheme.goodPostureGreen,
      backgroundColor: Color(0xFF0F2E22),
    ),
    AppAvatarPreset(
      id: 'avatar_energy_orange',
      label: 'High Energy',
      icon: Icons.bolt_rounded,
      primaryColor: AppTheme.badPostureOrange,
      backgroundColor: Color(0xFF38200B),
    ),
    AppAvatarPreset(
      id: 'avatar_shield_purple',
      label: 'Guardian Shield',
      icon: Icons.shield_rounded,
      primaryColor: AppTheme.reminderPurple,
      backgroundColor: Color(0xFF28133E),
    ),
    AppAvatarPreset(
      id: 'avatar_fitness_teal',
      label: 'Power Fitness',
      icon: Icons.fitness_center_rounded,
      primaryColor: Color(0xFF14B8A6),
      backgroundColor: Color(0xFF0D2D29),
    ),
    AppAvatarPreset(
      id: 'avatar_lotus_pink',
      label: 'Mindful Lotus',
      icon: Icons.self_improvement_rounded,
      primaryColor: Color(0xFFEC4899),
      backgroundColor: Color(0xFF381026),
    ),
  ];

  static AppAvatarPreset getPreset(String? id) {
    if (id == null) return presets.first;
    return presets.firstWhere((p) => p.id == id, orElse: () => presets.first);
  }
}
