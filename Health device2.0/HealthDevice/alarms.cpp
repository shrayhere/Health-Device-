#include "alarms.h"

#include "time_manager.h"
#include "alerts.h"
#include "storage.h"


// ============================================================
// INTERNAL STORAGE
// ============================================================

static Alarm list[MAX_ALARMS];


// Which alarm is currently ringing?
static int ringingIndex = -1;


// Prevent the same alarm from repeatedly triggering during
// the same minute.
static int lastFiredMinuteOfDay[MAX_ALARMS];


// Snooze state.
static uint32_t snoozeUntilEpoch = 0;

static int snoozeAlarmIndex = -1;

static bool anyDaySelected(const bool days[7]);


// ============================================================
// LOAD
// ============================================================

static void loadFromStorage() {

  for (
      int i = 0;
      i < MAX_ALARMS;
      i++
  ) {

    char k[20];


    // --------------------------------------------------------
    // USED
    // --------------------------------------------------------

    snprintf(
        k,
        sizeof(k),
        "alm_used%d",
        i
    );

    list[i].used =
        storage::loadBool(
            k,
            false
        );


    // --------------------------------------------------------
    // EMPTY ALARM
    // --------------------------------------------------------

    if (
        !list[i].used
    ) {

      list[i].hour =
          7;

      list[i].minute =
          0;

      list[i].isPM =
          false;

      list[i].enabled =
          false;

      for (
          int d = 0;
          d < 7;
          d++
      ) {

        list[i].days[d] =
            false;
      }

      continue;
    }


    // --------------------------------------------------------
    // HOUR
    // --------------------------------------------------------

    snprintf(
        k,
        sizeof(k),
        "alm_h%d",
        i
    );

    list[i].hour =
        constrain(
            storage::loadInt(
                k,
                7
            ),
            0,
            23
        );


    // --------------------------------------------------------
    // MINUTE
    // --------------------------------------------------------

    snprintf(
        k,
        sizeof(k),
        "alm_m%d",
        i
    );

    list[i].minute =
        constrain(
            storage::loadInt(
                k,
                0
            ),
            0,
            59
        );


    // --------------------------------------------------------
    // AM / PM
    // --------------------------------------------------------

    // Stored separately for UI convenience.
    // The 24-hour "hour" remains authoritative.
    snprintf(
        k,
        sizeof(k),
        "alm_pm%d",
        i
    );

    list[i].isPM =
        storage::loadBool(
            k,
            list[i].hour >= 12
        );


    // Make sure the flag agrees with the actual hour.
    list[i].isPM =
        list[i].hour >= 12;


    // --------------------------------------------------------
    // ENABLED
    // --------------------------------------------------------

    snprintf(
        k,
        sizeof(k),
        "alm_en%d",
        i
    );

    list[i].enabled =
        storage::loadBool(
            k,
            true
        );


    // --------------------------------------------------------
    // DAYS
    // --------------------------------------------------------

    for (
        int d = 0;
        d < 7;
        d++
    ) {

      snprintf(
          k,
          sizeof(k),
          "alm_d%d_%d",
          i,
          d
      );

      list[i].days[d] =
          storage::loadBool(
              k,
              true
          );
    }

    // If no days were selected, default to everyday
    if (!anyDaySelected(list[i].days)) {
      for (int d = 0; d < 7; d++) {
        list[i].days[d] = true;
      }
    }

    // RGB LED COLOR
    snprintf(k, sizeof(k), "alm_r%d", i);
    list[i].r = (uint8_t)storage::loadInt(k, 255);
    snprintf(k, sizeof(k), "alm_g%d", i);
    list[i].g = (uint8_t)storage::loadInt(k, 0);
    snprintf(k, sizeof(k), "alm_b%d", i);
    list[i].b = (uint8_t)storage::loadInt(k, 0);
  }
}


// ============================================================
// SAVE
// ============================================================

static void saveOne(
    int i
) {

  if (
      i < 0 ||
      i >= MAX_ALARMS
  ) {

    return;
  }


  char k[20];


  // USED

  snprintf(
      k,
      sizeof(k),
      "alm_used%d",
      i
  );

  storage::saveBool(
      k,
      list[i].used
  );


  // HOUR

  snprintf(
      k,
      sizeof(k),
      "alm_h%d",
      i
  );

  storage::saveInt(
      k,
      list[i].hour
  );


  // MINUTE

  snprintf(
      k,
      sizeof(k),
      "alm_m%d",
      i
  );

  storage::saveInt(
      k,
      list[i].minute
  );


  // AM / PM

  snprintf(
      k,
      sizeof(k),
      "alm_pm%d",
      i
  );

  storage::saveBool(
      k,
      list[i].hour >= 12
  );


  // ENABLED

  snprintf(
      k,
      sizeof(k),
      "alm_en%d",
      i
  );

  storage::saveBool(
      k,
      list[i].enabled
  );


  // DAYS

  for (
      int d = 0;
      d < 7;
      d++
  ) {

    snprintf(
        k,
        sizeof(k),
        "alm_d%d_%d",
        i,
        d
    );

    storage::saveBool(
        k,
        list[i].days[d]
    );
  }

  // RGB LED COLOR
  snprintf(k, sizeof(k), "alm_r%d", i);
  storage::saveInt(k, list[i].r);
  snprintf(k, sizeof(k), "alm_g%d", i);
  storage::saveInt(k, list[i].g);
  snprintf(k, sizeof(k), "alm_b%d", i);
  storage::saveInt(k, list[i].b);
}


// ============================================================
// DAY CHECK
// ============================================================

static bool anyDaySelected(
    const bool days[7]
) {

  for (
      int d = 0;
      d < 7;
      d++
  ) {

    if (
        days[d]
    ) {

      return true;
    }
  }

  return false;
}


// ============================================================
// NAMESPACE
// ============================================================

namespace alarms {


// ============================================================
// BEGIN
// ============================================================

void begin() {

  for (
      int i = 0;
      i < MAX_ALARMS;
      i++
  ) {

    list[i].used =
        false;

    list[i].hour =
        7;

    list[i].minute =
        0;

    list[i].isPM =
        false;

    list[i].enabled =
        false;

    list[i].r = 255;
    list[i].g = 0;
    list[i].b = 0;

    for (
        int d = 0;
        d < 7;
        d++
    ) {

      list[i].days[d] =
          false;
    }


    lastFiredMinuteOfDay[i] =
        -1;
  }


  ringingIndex =
      -1;

  snoozeUntilEpoch =
      0;

  snoozeAlarmIndex =
      -1;


  loadFromStorage();
}


// ============================================================
// UPDATE
// ============================================================

void update() {

  // Already ringing.
  if (
      ringingIndex >= 0
  ) {

    return;
  }


  DateTime dt =
      timeManager::now();

  uint32_t epoch =
      timeManager::nowEpoch();


  // ----------------------------------------------------------
  // SNOOZE
  // ----------------------------------------------------------

  if (
      snoozeAlarmIndex >= 0 &&
      snoozeUntilEpoch > 0
  ) {

    if (
        epoch >=
        snoozeUntilEpoch
    ) {

      ringingIndex =
          snoozeAlarmIndex;

      snoozeAlarmIndex =
          -1;

      snoozeUntilEpoch =
          0;


      alerts::raise(
          ALERT_ALARM
      );

      alerts::buzzerContinuousStart();

      return;
    }
  }


  // ----------------------------------------------------------
  // CURRENT MINUTE
  // ----------------------------------------------------------

  int minuteOfDay =
      dt.hour * 60 +
      dt.minute;


  // ----------------------------------------------------------
  // CHECK ALL FIVE ALARMS
  // ----------------------------------------------------------

  for (
      int i = 0;
      i < MAX_ALARMS;
      i++
  ) {

    if (
        !list[i].used ||
        !list[i].enabled
    ) {

      continue;
    }


    // Is this alarm enabled for today's weekday?
    bool dayMatches = list[i].days[dt.weekday];
    if (!anyDaySelected(list[i].days)) {
      dayMatches = true; // Fallback: if unconstrained, fire today
    }
    if (!dayMatches) {
      continue;
    }


    int target =
        list[i].hour * 60 +
        list[i].minute;


    if (
        minuteOfDay ==
        target &&
        lastFiredMinuteOfDay[i] !=
            minuteOfDay
    ) {

      lastFiredMinuteOfDay[i] =
          minuteOfDay;

      ringingIndex =
          i;


      alerts::raise(
          ALERT_ALARM
      );

      alerts::buzzerContinuousStart();

      break;
    }
  }


  // ----------------------------------------------------------
  // ALLOW FUTURE MINUTES TO FIRE AGAIN
  // ----------------------------------------------------------

  for (
      int i = 0;
      i < MAX_ALARMS;
      i++
  ) {

    if (
        lastFiredMinuteOfDay[i] >= 0 &&
        lastFiredMinuteOfDay[i] !=
            minuteOfDay
    ) {

      lastFiredMinuteOfDay[i] =
          -1;
    }
  }
}


// ============================================================
// COUNT
// ============================================================

int count() {

  int c =
      0;

  for (
      int i = 0;
      i < MAX_ALARMS;
      i++
  ) {

    if (
        list[i].used
    ) {

      c++;
    }
  }

  return c;
}


// ============================================================
// GET
// ============================================================

const Alarm& get(
    int index
) {

  static Alarm empty = {
      false,
      0,
      0,
      false,
      {
          false,
          false,
          false,
          false,
          false,
          false,
          false
      },
      false
  };


  if (
      index < 0 ||
      index >= MAX_ALARMS
  ) {

    return empty;
  }


  return list[index];
}


// ============================================================
// ADD — 24 HOUR
// ============================================================

bool add(
    int hour24,
    int minute,
    const bool daysMask[7],
    uint8_t r,
    uint8_t g,
    uint8_t b
) {

  if (
      daysMask == nullptr
  ) {

    return false;
  }


  for (
      int i = 0;
      i < MAX_ALARMS;
      i++
  ) {

    if (
        !list[i].used
    ) {

      list[i].used =
          true;

      list[i].hour =
          constrain(
              hour24,
              0,
              23
          );

      list[i].minute =
          constrain(
              minute,
              0,
              59
          );

      list[i].isPM =
          list[i].hour >= 12;

      list[i].enabled =
          true;

      list[i].r = r;
      list[i].g = g;
      list[i].b = b;

      for (
          int d = 0;
          d < 7;
          d++
      ) {

        list[i].days[d] =
            daysMask[d];
      }


      // Don't allow an alarm with zero selected days -> default to everyday!
      if (
          !anyDaySelected(
              list[i].days
          )
      ) {

        for (int d = 0; d < 7; d++) {
          list[i].days[d] = true;
        }
      }

      lastFiredMinuteOfDay[i] = -1;

      saveOne(i);

      return true;
    }
  }


  // All five slots occupied.
  return false;
}


// ============================================================
// ADD — 12 HOUR + AM/PM
// ============================================================

bool add12Hour(
    int hour12,
    int minute,
    bool pm,
    const bool daysMask[7]
) {

  return add(
      to24Hour(
          hour12,
          pm
      ),
      minute,
      daysMask
  );
}


// ============================================================
// REMOVE
// ============================================================

void remove(
    int index
) {

  if (
      index < 0 ||
      index >= MAX_ALARMS
  ) {

    return;
  }


  if (
      ringingIndex ==
      index
  ) {

    dismiss();
  }


  if (
      snoozeAlarmIndex ==
      index
  ) {

    snoozeAlarmIndex =
        -1;

    snoozeUntilEpoch =
        0;
  }


  list[index].used =
      false;

  list[index].enabled =
      false;


  saveOne(index);
}


// ============================================================
// ENABLE / DISABLE
// ============================================================

void setEnabled(
    int index,
    bool enabled
) {

  if (
      index < 0 ||
      index >= MAX_ALARMS ||
      !list[index].used
  ) {

    return;
  }


  list[index].enabled =
      enabled;


  if (
      !enabled &&
      ringingIndex ==
          index
  ) {

    dismiss();
  }

  lastFiredMinuteOfDay[index] = -1;

  saveOne(index);
}

// ============================================================
// SET COLOR
// ============================================================

void setColor(
    int index,
    uint8_t r,
    uint8_t g,
    uint8_t b
) {

  if (
      index < 0 ||
      index >= MAX_ALARMS ||
      !list[index].used
  ) {

    return;
  }

  list[index].r = r;
  list[index].g = g;
  list[index].b = b;

  saveOne(index);
}



// ============================================================
// SET TIME — 24 HOUR
// ============================================================

void setTime24(
    int index,
    int hour24,
    int minute
) {

  if (
      index < 0 ||
      index >= MAX_ALARMS ||
      !list[index].used
  ) {

    return;
  }


  list[index].hour =
      constrain(
          hour24,
          0,
          23
      );

  list[index].minute =
      constrain(
          minute,
          0,
          59
      );

  list[index].isPM =
      list[index].hour >= 12;

  lastFiredMinuteOfDay[index] = -1;

  saveOne(index);
}


// ============================================================
// SET TIME — 12 HOUR
// ============================================================

void setTime12(
    int index,
    int hour12,
    int minute,
    bool pm
) {

  setTime24(
      index,
      to24Hour(
          hour12,
          pm
      ),
      minute
  );
}


// ============================================================
// SET DAYS
// ============================================================

void setDays(
    int index,
    const bool daysMask[7]
) {

  if (
      index < 0 ||
      index >= MAX_ALARMS ||
      !list[index].used ||
      daysMask == nullptr
  ) {

    return;
  }


  for (
      int d = 0;
      d < 7;
      d++
  ) {

    list[index].days[d] =
        daysMask[d];
  }


  if (
      !anyDaySelected(
          list[index].days
      )
  ) {

    for (int d = 0; d < 7; d++) {
      list[index].days[d] = true;
    }
  }

  lastFiredMinuteOfDay[index] = -1;

  saveOne(index);
}


// ============================================================
// EVERYDAY
// ============================================================

void setEveryday(
    int index
) {

  bool days[7] = {
      true,
      true,
      true,
      true,
      true,
      true,
      true
  };


  setDays(
      index,
      days
  );
}


// ============================================================
// WEEKDAYS
// ============================================================

void setWeekdays(
    int index
) {

  bool days[7] = {
      false,  // Sunday
      true,   // Monday
      true,   // Tuesday
      true,   // Wednesday
      true,   // Thursday
      true,   // Friday
      false   // Saturday
  };


  setDays(
      index,
      days
  );
}


// ============================================================
// WEEKEND
// ============================================================

void setWeekend(
    int index
) {

  bool days[7] = {
      true,   // Sunday
      false,
      false,
      false,
      false,
      false,
      true    // Saturday
  };


  setDays(
      index,
      days
  );
}


// ============================================================
// RINGING
// ============================================================

bool isRinging() {

  return ringingIndex >= 0;
}


// ============================================================
// GET RINGING
// ============================================================

const Alarm& getRinging() {

  return get(
      ringingIndex
  );
}


// ============================================================
// DISMISS
// ============================================================

void dismiss() {

  if (
      ringingIndex < 0
  ) {

    return;
  }


  alerts::buzzerStop();

  alerts::clear(
      ALERT_ALARM
  );

  ringingIndex =
      -1;
}


// ============================================================
// SNOOZE
// ============================================================

void snooze() {

  if (
      ringingIndex < 0
  ) {

    return;
  }


  int index =
      ringingIndex;


  alerts::buzzerStop();

  alerts::clear(
      ALERT_ALARM
  );


  ringingIndex =
      -1;


  snoozeAlarmIndex =
      index;


  snoozeUntilEpoch =
      timeManager::nowEpoch() +
      (
          ALARM_SNOOZE_MINUTES *
          60UL
      );
}


// ============================================================
// SNOOZED
// ============================================================

bool isSnoozed() {

  return
      snoozeAlarmIndex >= 0 &&
      snoozeUntilEpoch > 0;
}


// ============================================================
// 24H -> 12H
// ============================================================

int to12Hour(
    int hour24
) {

  int h =
      hour24 % 12;


  if (
      h == 0
  ) {

    return 12;
  }


  return h;
}


// ============================================================
// AM / PM
// ============================================================

bool isPM(
    int hour24
) {

  return hour24 >= 12;
}


// ============================================================
// 12H -> 24H
// ============================================================

int to24Hour(
    int hour12,
    bool pm
) {

  hour12 =
      constrain(
          hour12,
          1,
          12
      );


  if (
      pm
  ) {

    return
        hour12 == 12
            ? 12
            : hour12 + 12;
  }


  return
      hour12 == 12
          ? 0
          : hour12;
}

} // namespace alarms