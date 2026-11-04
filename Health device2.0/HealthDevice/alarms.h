#ifndef ALARMS_H
#define ALARMS_H

#include <Arduino.h>

// ============================================================
// ALARMS
// ============================================================

// Final device specification: 5 alarms.
#define MAX_ALARMS 5

// Final snooze duration.
#define ALARM_SNOOZE_MINUTES 5

struct Alarm {

  bool used;

  // Internal time is ALWAYS stored as 24-hour time.
  //
  // 0  = 12:00 AM
  // 1  = 01:00 AM
  // ...
  // 11 = 11:00 AM
  // 12 = 12:00 PM
  // ...
  // 23 = 11:00 PM
  //
  // The display/setup UI will show this as 12-hour + AM/PM.
  int hour;

  int minute;

  // Kept for easy UI access.
  // The authoritative value is still "hour".
  bool isPM;

  // 0 = Sunday
  // 1 = Monday
  // 2 = Tuesday
  // 3 = Wednesday
  // 4 = Thursday
  // 5 = Friday
  // 6 = Saturday
  bool days[7];

  bool enabled;

  // Custom RGB LED indicator color (0-255)
  uint8_t r;
  uint8_t g;
  uint8_t b;
};


namespace alarms {

  // ----------------------------------------------------------
  // INITIALIZATION / UPDATE
  // ----------------------------------------------------------

  void begin();

  void update();


  // ----------------------------------------------------------
  // ALARM LIST
  // ----------------------------------------------------------

  int count();

  const Alarm& get(
      int index
  );


  // ----------------------------------------------------------
  // CREATE
  // ----------------------------------------------------------

  // Add using 24-hour time.
  bool add(
      int hour24,
      int minute,
      const bool daysMask[7],
      uint8_t r = 255,
      uint8_t g = 0,
      uint8_t b = 0
  );

  // Add using 12-hour time + AM/PM.
  bool add12Hour(
      int hour12,
      int minute,
      bool pm,
      const bool daysMask[7]
  );


  // ----------------------------------------------------------
  // MODIFY
  // ----------------------------------------------------------

  void remove(
      int index
  );

  void setEnabled(
      int index,
      bool enabled
  );

  void setTime24(
      int index,
      int hour24,
      int minute
  );

  void setTime12(
      int index,
      int hour12,
      int minute,
      bool pm
  );

  void setDays(
      int index,
      const bool daysMask[7]
  );

  void setColor(
      int index,
      uint8_t r,
      uint8_t g,
      uint8_t b
  );


  // ----------------------------------------------------------
  // DAY PRESETS
  // ----------------------------------------------------------

  void setEveryday(
      int index
  );

  void setWeekdays(
      int index
  );

  void setWeekend(
      int index
  );


  // ----------------------------------------------------------
  // ACTIVE ALARM
  // ----------------------------------------------------------

  bool isRinging();

  const Alarm& getRinging();

  void dismiss();

  void snooze();

  bool isSnoozed();


  // ----------------------------------------------------------
  // TIME CONVERSION HELPERS
  // ----------------------------------------------------------

  int to12Hour(
      int hour24
  );

  bool isPM(
      int hour24
  );

  int to24Hour(
      int hour12,
      bool pm
  );

}

#endif