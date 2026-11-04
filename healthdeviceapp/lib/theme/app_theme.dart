import 'package:flutter/material.dart';

/// Design tokens extracted directly from the attached UI reference image.
/// Deep black/navy backgrounds, dark blue-gray surfaces, clean blue primary,
/// vibrant cyan secondary, and muted borders.
class AppTheme {
  AppTheme._();

  // Backgrounds & Surfaces
  static const Color background = Color(0xFF070B12); // Deep black/navy base
  static const Color surface = Color(0xFF0C1322); // Dark blue-gray surface
  static const Color card = Color(0xFF10192D); // Modular card background
  static const Color cardLight = Color(
    0xFF15213B,
  ); // Elevated card / selected chip
  static const Color border = Color(0xFF18243C); // Subtle dark-blue border
  static const Color borderSubtle = Color(0xFF121B2F);

  // Accents
  static const Color primaryBlue = Color(0xFF0D6EFD); // Clean primary blue
  static const Color primaryBlueLight = Color(
    0xFF2979FF,
  ); // Active button/tab blue
  static const Color cyan = Color(0xFF00E5FF); // Secondary vibrant cyan
  static const Color cyanLight = Color(0xFF38BDF8);

  // Status & Measurement Colors from Reference
  static const Color heartRateRed = Color(0xFFFF453A); // Heart rate red
  static const Color spo2Cyan = Color(0xFF00E5FF); // SpO2 cyan
  static const Color goodPostureGreen = Color(0xFF10B981); // Good posture green
  static const Color badPostureOrange = Color(0xFFFF9100); // Bad posture orange
  static const Color reminderPurple = Color(0xFFA855F7); // Reminder purple
  static const Color alarmRed = Color(0xFFEF4444); // Alarm red
  static const Color caloriesOrange = Color(0xFFFF7A00); // Flame orange
  static const Color neonGreen = Color(0xFF00E676); // High-visibility neon green

  // Aliases for compatibility
  static const Color statusGreen = goodPostureGreen;
  static const Color statusOrange = badPostureOrange;
  static const Color warningOrange = badPostureOrange;
  static const Color orange = badPostureOrange;
  static const Color surfaceLight = cardLight;
  static const Color statusRed = alarmRed;
  static const Color cardHover = cardLight;

  // Typography Colors
  static const Color textPrimary = Color(0xFFFFFFFF); // Pure white
  static const Color textSecondary = Color(0xFF94A3B8); // Crisp slate
  static const Color textMuted = Color(0xFF64748B); // Subtle label gray
  static const Color textDim = Color(0xFF475569);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: cyan,
        surface: surface,
        onSurface: textPrimary,
        outline: border,
        outlineVariant: borderSubtle,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderSubtle,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        indicatorColor: primaryBlue.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cyan,
            );
          }
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: cyan, size: 22);
          }
          return const IconThemeData(color: textMuted, size: 22);
        }),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: surface,
        elevation: 0,
        indicatorColor: Color(0x330D6EFD),
        selectedIconTheme: IconThemeData(color: cyan, size: 22),
        unselectedIconTheme: IconThemeData(color: textMuted, size: 22),
        selectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: cyan,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textMuted,
        ),
      ),
    );
  }
}
