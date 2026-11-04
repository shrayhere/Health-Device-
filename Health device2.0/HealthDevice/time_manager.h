#ifndef TIME_MANAGER_H
#define TIME_MANAGER_H

#include <Arduino.h>

// ============================================================
// DATE / TIME STRUCTURE
// ============================================================

struct DateTime {
  int year;
  int month;    // 1-12
  int day;      // 1-31
  int hour;     // 0-23
  int minute;
  int second;
  int weekday;  // 0=Sunday .. 6=Saturday
};


// ============================================================
// TIME MANAGER
// ============================================================

namespace timeManager {

  void begin();

  // Call every loop().
  // Handles background time synchronization.
  void update();

  // Manual time setting.
  void setTime(
      int year,
      int month,
      int day,
      int hour,
      int minute,
      int second
  );

  // Returns current device time.
  DateTime now();

  // Returns whether the clock has received a valid time.
  bool isTimeSet();

  // Returns whether the current time came from NTP.
  bool isNtpSynced();

  // 12/24-hour display formatting.
  String formatTimeHHMM(bool use24h);

  // Example:
  // SUN 27 SEP
  String formatDateShort();

  // Device timestamp.
  uint32_t nowEpoch();

}

#endif // TIME_MANAGER_H