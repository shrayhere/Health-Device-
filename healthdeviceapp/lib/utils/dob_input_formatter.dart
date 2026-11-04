import 'package:flutter/services.dart';

/// Intelligent manual Date of Birth text input formatter.
///
/// Output format: DD/MM/YYYY (e.g. 16/03/2005)
///
/// Rules:
/// - DAY (01–31):
///   - If first digit is 4–9, automatically prefixes '0' and appends '/' -> '0D/'
///   - If first digit is 1–3, waits for second digit.
///   - When 2nd day digit entered: verifies 01–31. If valid, appends '/' -> 'DD/'
/// - MONTH (01–12):
///   - If first month digit is 2–9, automatically prefixes '0' and appends '/' -> 'DD/0M/'
///   - If first month digit is 0 or 1, waits for second digit.
///   - When 2nd month digit entered: verifies 01–12. If valid, appends '/' -> 'DD/MM/'
/// - YEAR (4 digits):
///   - Maximum allowed year: DateTime.now().year (dynamically).
///   - Minimum year: 1900.
///   - Rejects future dates.
///   - Validates leap year and days in month (e.g. 29/02 in non-leap year rejected).
/// - BACKSPACE:
///   - Smooth backspacing across DD -> MM -> YYYY without getting trapped at separators.
class DobInputFormatter extends TextInputFormatter {
  final int maxYear;
  final int minYear;

  DobInputFormatter({int? maxYear, this.minYear = 1900})
    : maxYear = maxYear ?? DateTime.now().year;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Handling backspace / deletion
    if (newValue.text.length < oldValue.text.length) {
      // If the deleted character was a '/', delete the preceding digit as well
      // to prevent getting stuck in a format loop.
      if (oldValue.text.endsWith('/') &&
          newValue.text.length == oldValue.text.length - 1) {
        final stripped = newValue.text.substring(0, newValue.text.length - 1);
        return TextEditingValue(
          text: stripped,
          selection: TextSelection.collapsed(offset: stripped.length),
        );
      }
      return newValue;
    }

    // Extract only digits from new text
    final rawDigits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (rawDigits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final buffer = StringBuffer();
    int digitIdx = 0;

    // --- 1. DAY FORMATTING ---
    if (digitIdx < rawDigits.length) {
      final firstDayChar = rawDigits[digitIdx];
      final firstDayDigit = int.tryParse(firstDayChar) ?? 0;

      if (firstDayDigit >= 4) {
        // Auto-prefix 0 and append / (e.g. '4' -> '04/')
        buffer.write('0$firstDayChar/');
        digitIdx++;
      } else {
        buffer.write(firstDayChar);
        digitIdx++;
        if (digitIdx < rawDigits.length) {
          final secondDayChar = rawDigits[digitIdx];
          final dayNum = int.tryParse('$firstDayChar$secondDayChar') ?? 0;
          if (dayNum >= 1 && dayNum <= 31) {
            buffer.write('$secondDayChar/');
            digitIdx++;
          } else {
            // Invalid day (e.g. 00 or 32..39), discard second digit
            digitIdx++;
          }
        }
      }
    }

    // --- 2. MONTH FORMATTING ---
    if (digitIdx < rawDigits.length && buffer.toString().endsWith('/')) {
      final firstMonthChar = rawDigits[digitIdx];
      final firstMonthDigit = int.tryParse(firstMonthChar) ?? 0;

      if (firstMonthDigit >= 2) {
        // Auto-prefix 0 and append / (e.g. '3' -> '03/')
        buffer.write('0$firstMonthChar/');
        digitIdx++;
      } else {
        buffer.write(firstMonthChar);
        digitIdx++;
        if (digitIdx < rawDigits.length) {
          final secondMonthChar = rawDigits[digitIdx];
          final monthNum = int.tryParse('$firstMonthChar$secondMonthChar') ?? 0;
          if (monthNum >= 1 && monthNum <= 12) {
            buffer.write('$secondMonthChar/');
            digitIdx++;
          } else {
            // Invalid month (e.g. 13..19 or 00), discard second digit
            digitIdx++;
          }
        }
      }
    }

    // --- 3. YEAR FORMATTING ---
    if (digitIdx < rawDigits.length &&
        buffer.toString().split('/').length == 3) {
      final yearDigits = rawDigits.substring(digitIdx);
      final clampedYear = yearDigits.length > 4
          ? yearDigits.substring(0, 4)
          : yearDigits;
      buffer.write(clampedYear);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Parses a DD/MM/YYYY string into a validated DateTime.
  /// Returns null if format is incomplete, day/month invalid,
  /// year outside [minYear, maxYear], or date is in the future.
  static DateTime? parseAndValidate(String text) {
    final parts = text.split('/');
    if (parts.length != 3) return null;
    if (parts[0].length != 2 || parts[1].length != 2 || parts[2].length != 4) {
      return null;
    }

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) return null;

    final now = DateTime.now();
    if (year < 1900 || year > now.year) return null;
    if (month < 1 || month > 12) return null;

    final daysInMonth = _getDaysInMonth(year, month);
    if (day < 1 || day > daysInMonth) return null;

    final date = DateTime(year, month, day);
    if (date.isAfter(now)) return null;

    return date;
  }

  /// Formats a DateTime to DD/MM/YYYY.
  static String format(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString().padLeft(4, '0');
    return '$d/$m/$y';
  }

  static int _getDaysInMonth(int year, int month) {
    if (month == 2) {
      final isLeap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeap ? 29 : 28;
    }
    const days30 = [4, 6, 9, 11];
    if (days30.contains(month)) {
      return 30;
    }
    return 31;
  }
}
