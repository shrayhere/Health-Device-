#include "time_manager.h"
#include "wifi_manager.h"


// ============================================================
// DISPLAY NAMES
// ============================================================

static const char* WEEKDAY_NAMES[7] = {
  "SUN",
  "MON",
  "TUE",
  "WED",
  "THU",
  "FRI",
  "SAT"
};

static const char* MONTH_NAMES[13] = {
  "",
  "JAN",
  "FEB",
  "MAR",
  "APR",
  "MAY",
  "JUN",
  "JUL",
  "AUG",
  "SEP",
  "OCT",
  "NOV",
  "DEC"
};


// ============================================================
// DATE HELPERS
// ============================================================

static int daysInMonth(
    int month,
    int year
) {

  static const int dim[] = {
    31,
    28,
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31
  };

  if (
      month == 2 &&
      (
        (year % 4 == 0 && year % 100 != 0) ||
        (year % 400 == 0)
      )
  ) {
    return 29;
  }

  return dim[month - 1];
}


// ============================================================
// INTERNAL CLOCK
// ============================================================

static DateTime baseTime;

static unsigned long baseMillis = 0;

static bool timeSet = false;

static bool ntpSynced = false;


// ============================================================
// ADD SECONDS
// ============================================================

static DateTime addSeconds(
    DateTime dt,
    unsigned long secondsToAdd
) {

  dt.second += secondsToAdd;

  while (
      dt.second >= 60
  ) {

    dt.second -= 60;
    dt.minute++;
  }


  while (
      dt.minute >= 60
  ) {

    dt.minute -= 60;
    dt.hour++;
  }


  while (
      dt.hour >= 24
  ) {

    dt.hour -= 24;

    dt.day++;

    dt.weekday =
        (dt.weekday + 1) % 7;


    if (
        dt.day >
        daysInMonth(
            dt.month,
            dt.year
        )
    ) {

      dt.day = 1;

      dt.month++;


      if (
          dt.month > 12
      ) {

        dt.month = 1;
        dt.year++;
      }
    }
  }


  return dt;
}


// ============================================================
// CALCULATE WEEKDAY
// ============================================================

static int calculateWeekday(
    int year,
    int month,
    int day
) {

  int m = month;
  int y = year;


  if (
      m < 3
  ) {

    m += 12;
    y -= 1;
  }


  int k =
      y % 100;

  int j =
      y / 100;


  int h =
      (
        day +
        (13 * (m + 1)) / 5 +
        k +
        k / 4 +
        j / 4 +
        5 * j
      ) % 7;


  // Zeller:
  // 0 = Saturday
  //
  // Convert:
  // 0 = Sunday
  // ...
  // 6 = Saturday

  return (
      h + 6
  ) % 7;
}


// ============================================================
// TIME MANAGER
// ============================================================

namespace timeManager {


// ============================================================
// BEGIN
// ============================================================

void begin() {

  // Safe fallback time.
  //
  // This is used until NTP provides
  // a real time.

  baseTime = {
    2026,
    1,
    1,
    0,
    0,
    0,
    4
  };


  baseMillis =
      millis();


  timeSet =
      false;


  ntpSynced =
      false;
}


// ============================================================
// UPDATE
// ============================================================

void update() {

  // ----------------------------------------------------------
  // Check whether wifi_manager has obtained NTP time.
  //
  // This is intentionally non-blocking.
  // ----------------------------------------------------------

  if (
      !ntpSynced &&
      wifiManager::isTimeSynced()
  ) {

    int year;
    int month;
    int day;
    int hour;
    int minute;
    int second;
    int weekday;


    if (
        wifiManager::getNetworkTime(
            year,
            month,
            day,
            hour,
            minute,
            second,
            weekday
        )
    ) {

      // ------------------------------------------------------
      // Apply network time to our local clock.
      // ------------------------------------------------------

      baseTime.year =
          year;

      baseTime.month =
          month;

      baseTime.day =
          day;

      baseTime.hour =
          hour;

      baseTime.minute =
          minute;

      baseTime.second =
          second;

      baseTime.weekday =
          weekday;


      // Restart our local millis-based clock
      // from this exact synchronized point.

      baseMillis =
          millis();


      timeSet =
          true;


      ntpSynced =
          true;


      Serial.println(
          "TIME MANAGER: NTP time applied."
      );

      Serial.printf(
          "TIME: %04d-%02d-%02d %02d:%02d:%02d\n",
          year,
          month,
          day,
          hour,
          minute,
          second
      );
    }
  }
}


// ============================================================
// MANUAL SET TIME
// ============================================================

void setTime(
    int year,
    int month,
    int day,
    int hour,
    int minute,
    int second
) {

  baseTime.year =
      year;

  baseTime.month =
      month;

  baseTime.day =
      day;

  baseTime.hour =
      hour;

  baseTime.minute =
      minute;

  baseTime.second =
      second;


  baseTime.weekday =
      calculateWeekday(
          year,
          month,
          day
      );


  baseMillis =
      millis();


  timeSet =
      true;


  // Manual setting does not mean
  // NTP has synchronized.

  ntpSynced =
      false;
}


// ============================================================
// CURRENT TIME
// ============================================================

DateTime now() {

  unsigned long elapsedSec =
      (
        millis() -
        baseMillis
      ) / 1000;


  return addSeconds(
      baseTime,
      elapsedSec
  );
}


// ============================================================
// TIME SET STATUS
// ============================================================

bool isTimeSet() {

  return timeSet;
}


// ============================================================
// NTP STATUS
// ============================================================

bool isNtpSynced() {

  return ntpSynced;
}


// ============================================================
// TIME FORMAT
// ============================================================

String formatTimeHHMM(
    bool use24h
) {

  DateTime dt =
      now();


  int h =
      dt.hour;


  char buf[12];


  if (
      use24h
  ) {

    snprintf(
        buf,
        sizeof(buf),
        "%02d:%02d",
        h,
        dt.minute
    );
  }

  else {

    int h12 =
        h % 12;


    if (
        h12 == 0
    ) {

      h12 = 12;
    }


    const char* ampm =
        (h >= 12)
        ? "PM"
        : "AM";


    snprintf(
        buf,
        sizeof(buf),
        "%02d:%02d %s",
        h12,
        dt.minute,
        ampm
    );
  }


  return String(buf);
}


// ============================================================
// DATE FORMAT
// ============================================================

String formatDateShort() {

  DateTime dt =
      now();


  char buf[20];


  snprintf(
      buf,
      sizeof(buf),
      "%s %d %s",
      WEEKDAY_NAMES[dt.weekday],
      dt.day,
      MONTH_NAMES[dt.month]
  );


  return String(buf);
}


// ============================================================
// EPOCH
// ============================================================

uint32_t nowEpoch() {

  DateTime dt =
      now();


  uint32_t days =
      0;


  for (
      int y = 2000;
      y < dt.year;
      y++
  ) {

    days +=
        (
          (y % 4 == 0 && y % 100 != 0) ||
          (y % 400 == 0)
        )
        ? 366
        : 365;
  }


  for (
      int m = 1;
      m < dt.month;
      m++
  ) {

    days +=
        daysInMonth(
            m,
            dt.year
        );
  }


  days +=
      dt.day - 1;


  return
      days * 86400UL +
      dt.hour * 3600UL +
      dt.minute * 60UL +
      dt.second;
}


} // namespace timeManager