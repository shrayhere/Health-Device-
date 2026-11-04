#include "wellness.h"

#include "config.h"
#include "alerts.h"
#include "activity.h"
#include "sensors.h"
#include "storage.h"
#include "time_manager.h"
#include "settings.h"

// ============================================================
// DAILY WELLNESS STATE
// ============================================================

static unsigned long dailySteps = 0;
static unsigned long dailyActiveSeconds = 0;
static unsigned long lastRawStepCount = 0;
static unsigned long lastMovementMs = 0;

static int currentDayId = 0;
static int waterCups = 0;
static int waterGoalCups = WATER_GOAL_DEFAULT_CUPS;
static uint32_t lastWaterEpoch = 0;
static bool waterReminderPendingFlag = false;
static bool exerciseReminderPendingFlag = false;

static int streakDays = 0;
static uint32_t achievementMask = 0;

static const uint32_t ACH_FIRST_1000_STEPS = 1UL << 0;
static const uint32_t ACH_5000_STEPS      = 1UL << 1;
static const uint32_t ACH_10000_STEPS     = 1UL << 2;
static const uint32_t ACH_WATER_GOAL      = 1UL << 3;
static const uint32_t ACH_SCORE_80        = 1UL << 4;
static const uint32_t ACH_STREAK_3        = 1UL << 5;

// ============================================================
// HR ALERT STATE
// ============================================================

static int hrAlertColor = 0;
static unsigned long hrAlertUntilMs = 0;

// ============================================================
// FALL DETECTION
// ============================================================
//
// Prototype detector using two signatures:
// 1) free-fall followed by impact, or
// 2) direct impact followed by sustained stability near 1 G.
//
// This is intentionally independent of the currently displayed screen.
// ============================================================

enum FallState {
  FALL_WAITING,
  FALL_WAIT_IMPACT,
  FALL_WAIT_STABLE
};

static FallState fallState = FALL_WAITING;
static unsigned long fallStateStartedMs = 0;
static unsigned long fallStableSinceMs = 0;
static float impactPitch = 0.0f;
static float impactRoll = 0.0f;
static float impactMagnitude = 0.0f;
static bool cameFromFreeFall = false;
static unsigned long fallAlertUntilMs = 0;
static unsigned long fallCooldownUntilMs = 0;

// ============================================================
// BREATHING EXERCISE
// ============================================================

static bool breathingRunning = false;
static unsigned long breathingStartedMs = 0;

// ============================================================
// DND
// ============================================================

static bool dndEnabled = false;

// ============================================================
// HELPERS
// ============================================================

static int makeDayId(const DateTime &dt) {
  return dt.year * 10000 + dt.month * 100 + dt.day;
}

static unsigned long minimumUnsignedLong(unsigned long a, unsigned long b) {
  return a < b ? a : b;
}

static int calculateScore() {
  float stepProgress =
      dailySteps >= ACTIVITY_STEP_GOAL
          ? 1.0f
          : dailySteps / (float)ACTIVITY_STEP_GOAL;

  float activeProgress =
      dailyActiveSeconds / 60UL >= ACTIVITY_ACTIVE_MIN_GOAL
          ? 1.0f
          : (dailyActiveSeconds / 60UL) / (float)ACTIVITY_ACTIVE_MIN_GOAL;

  float waterProgress =
      waterCups >= waterGoalCups
          ? 1.0f
          : waterCups / (float)waterGoalCups;

  int score =
      (int)(
          50.0f * stepProgress +
          30.0f * activeProgress +
          20.0f * waterProgress +
          0.5f
      );

  return constrain(score, 0, 100);
}

static bool dailyGoalsMet() {
  return
      dailySteps >= ACTIVITY_STEP_GOAL &&
      dailyActiveSeconds / 60UL >= ACTIVITY_ACTIVE_MIN_GOAL &&
      waterCups >= waterGoalCups;
}

static void saveDailyState() {
  storage::saveInt("well_day", currentDayId);
  storage::saveInt("well_steps", (int)dailySteps);
  storage::saveInt("well_active", (int)dailyActiveSeconds);
  storage::saveInt("well_water", waterCups);
  storage::saveInt("well_water_goal", waterGoalCups);
  storage::saveInt("well_streak", streakDays);
  storage::saveInt("well_achv", (int)achievementMask);
  storage::saveInt("well_water_last", (int)lastWaterEpoch);
}

static void updateAchievements() {
  uint32_t oldMask = achievementMask;

  if (dailySteps >= 1000UL) {
    achievementMask |= ACH_FIRST_1000_STEPS;
  }

  if (dailySteps >= 5000UL) {
    achievementMask |= ACH_5000_STEPS;
  }

  if (dailySteps >= 10000UL) {
    achievementMask |= ACH_10000_STEPS;
  }

  if (waterCups >= waterGoalCups) {
    achievementMask |= ACH_WATER_GOAL;
  }

  if (calculateScore() >= 80) {
    achievementMask |= ACH_SCORE_80;
  }

  if (streakDays >= 3) {
    achievementMask |= ACH_STREAK_3;
  }

  if (achievementMask != oldMask) {
    storage::saveInt("well_achv", (int)achievementMask);
  }
}

static void handleDayRollover() {
  DateTime dt = timeManager::now();
  int today = makeDayId(dt);

  if (currentDayId == 0) {
    currentDayId = today;
    storage::saveInt("well_day", currentDayId);
    return;
  }

  if (today == currentDayId) {
    return;
  }

  // A completed previous day increments the streak; an incomplete
  // previous day breaks it. The first recorded day starts at 1.
  if (dailyGoalsMet()) {
    streakDays++;
  } else {
    streakDays = 0;
  }

  currentDayId = today;
  dailySteps = 0;
  dailyActiveSeconds = 0;
  waterCups = 0;
  waterReminderPendingFlag = false;
  exerciseReminderPendingFlag = false;
  lastRawStepCount = motionSensor::getStepCount();
  lastMovementMs = millis();
  lastWaterEpoch = timeManager::nowEpoch();

  activity::resetToday();
  saveDailyState();
  updateAchievements();
}

static void updateDailyMotion() {
  unsigned long now = millis();
  unsigned long rawSteps = motionSensor::getStepCount();

  if (rawSteps < lastRawStepCount) {
    // Sensor step counter reset/restarted. Do not lose the persistent
    // daily total; simply re-baseline the raw sensor count.
    lastRawStepCount = rawSteps;
    return;
  }

  unsigned long delta = rawSteps - lastRawStepCount;

  if (delta > 0) {
    exerciseReminderPendingFlag = false;
    dailySteps += delta;

    unsigned long elapsedSec =
        (now - lastMovementMs) / 1000UL;

    // Count active time conservatively. One step event can represent
    // many sensor updates, but never credit more than one minute per event.
    dailyActiveSeconds +=
        minimumUnsignedLong(elapsedSec, 60UL);

    lastMovementMs = now;
    lastRawStepCount = rawSteps;

    if ((dailySteps % 25UL) == 0) {
      saveDailyState();
    }
  }
}

static void updateExerciseReminder() {
  if (millis() - lastMovementMs >= INACTIVITY_TIMEOUT_MINUTES * 60000UL) {
    if (!exerciseReminderPendingFlag) {
      exerciseReminderPendingFlag = true;

      if (
          settings::getSoundEnabled() &&
          !dndEnabled
      ) {
        alerts::beepPattern(2, 120, 220);
      }
    }
  }
  else {
    exerciseReminderPendingFlag = false;
  }
}


static void updateWaterReminder() {
  if (waterCups >= waterGoalCups) {
    waterReminderPendingFlag = false;
    return;
  }

  uint32_t nowEpoch = timeManager::nowEpoch();

  if (lastWaterEpoch == 0) {
    lastWaterEpoch = nowEpoch;
    storage::saveInt("well_water_last", (int)lastWaterEpoch);
    return;
  }

  uint32_t elapsed =
      nowEpoch >= lastWaterEpoch
          ? nowEpoch - lastWaterEpoch
          : 0;

  if (
      elapsed >= WATER_REMINDER_MINUTES * 60UL &&
      !waterReminderPendingFlag
  ) {
    waterReminderPendingFlag = true;

    if (
        settings::getSoundEnabled() &&
        !dndEnabled
    ) {
      alerts::beepPattern(2, 140, 160);
    }
  }
}

static void updateFallDetector() {
  // Fall alert disabled per user request
  return;
}

// ============================================================
// PUBLIC API
// ============================================================

namespace wellness {

void begin() {
  currentDayId = storage::loadInt("well_day", 0);
  dailySteps = (unsigned long)(storage::loadInt("well_steps", 0) < 0 ? 0 : storage::loadInt("well_steps", 0));
  dailyActiveSeconds = (unsigned long)(storage::loadInt("well_active", 0) < 0 ? 0 : storage::loadInt("well_active", 0));
  waterCups = storage::loadInt("well_water", 0);
  if (waterCups < 0) waterCups = 0;
  waterGoalCups = storage::loadInt("well_water_goal", WATER_GOAL_DEFAULT_CUPS);
  if (waterGoalCups < 1) waterGoalCups = 1;
  streakDays = storage::loadInt("well_streak", 0);
  if (streakDays < 0) streakDays = 0;
  achievementMask = (uint32_t)storage::loadInt("well_achv", 0);
  lastWaterEpoch = (uint32_t)(storage::loadInt("well_water_last", 0) < 0 ? 0 : storage::loadInt("well_water_last", 0));

  dndEnabled = storage::loadBool("dnd", false);

  lastRawStepCount = motionSensor::getStepCount();
  lastMovementMs = millis();

  DateTime dt = timeManager::now();
  int today = makeDayId(dt);

  if (currentDayId == 0) {
    currentDayId = today;
  } else if (currentDayId != today) {
    // Start a clean new day without trying to reconstruct a day that
    // was already ended while the device was off.
    currentDayId = today;
    dailySteps = 0;
    dailyActiveSeconds = 0;
    waterCups = 0;
    waterReminderPendingFlag = false;
    lastRawStepCount = motionSensor::getStepCount();
    lastMovementMs = millis();
  }

  if (lastWaterEpoch == 0) {
    lastWaterEpoch = timeManager::nowEpoch();
  }

  saveDailyState();

  hrAlertColor = 0;
  hrAlertUntilMs = 0;
  fallState = FALL_WAITING;
  fallAlertUntilMs = 0;
  fallCooldownUntilMs = 0;
}

void update() {
  handleDayRollover();
  updateDailyMotion();
  updateExerciseReminder();
  updateWaterReminder();
  updateFallDetector();
  updateAchievements();

  unsigned long now = millis();

  if (hrAlertColor != 0 && now >= hrAlertUntilMs) {
    if (hrAlertColor == 2 || hrAlertColor == 3) {
      alerts::buzzerStop();
    }

    hrAlertColor = 0;
    hrAlertUntilMs = 0;
  }

  if (breathingRunning) {
    // No hardware work is required; renderers use the elapsed time directly.
  }
}

void onHeartRateResult(int bpm) {
  if (bpm <= 0) {
    return;
  }

  // Every successful 8-second scan is stored as a new history entry.
  // The main firmware calls this function only once for each new result.
  storage::addHRRecord(
      bpm,
      timeManager::nowEpoch()
  );

  unsigned long now = millis();

  if (
      hrAlertColor != 0 &&
      now < hrAlertUntilMs
  ) {
    alerts::buzzerStop();
  }

  if (bpm >= HR_HIGH_BPM) {
    hrAlertColor = 2;
    hrAlertUntilMs = now + 1000UL;

    if (settings::getSoundEnabled()) {
      alerts::beepPattern(3, 90, 80);
    }

    Serial.print("HIGH HR ALERT: ");
    Serial.println(bpm);
  }

  else if (bpm < HR_LOW_BPM) {
    hrAlertColor = 3;
    hrAlertUntilMs = now + 1000UL;

    if (settings::getSoundEnabled()) {
      alerts::beepPattern(2, 100, 80);
    }

    Serial.print("LOW HR ALERT: ");
    Serial.println(bpm);
  }

  else {
    hrAlertColor = 1;
    hrAlertUntilMs = now + 400UL;

    if (settings::getSoundEnabled()) {
      alerts::beepShort();
    }
  }
}

int getHRAlertColor() {
  if (hrAlertColor == 0) {
    return 0;
  }

  if (millis() >= hrAlertUntilMs) {
    return 0;
  }

  return hrAlertColor;
}

void addWater(int cups) {
  if (cups <= 0) {
    return;
  }

  waterCups += cups;

  if (waterCups > 99) {
    waterCups = 99;
  }

  lastWaterEpoch = timeManager::nowEpoch();
  waterReminderPendingFlag = false;

  storage::saveInt("well_water", waterCups);
  storage::saveInt("well_water_last", (int)lastWaterEpoch);

  updateAchievements();
}

int getWaterCups() {
  return waterCups;
}

int getWaterGoal() {
  return waterGoalCups;
}

void setWaterGoal(int cups) {
  waterGoalCups = constrain(cups, 1, 20);
  storage::saveInt("well_water_goal", waterGoalCups);
  updateAchievements();
}

bool waterReminderPending() {
  return waterReminderPendingFlag;
}

void dismissWaterReminder() {
  waterReminderPendingFlag = false;
}

unsigned long minutesSinceWater() {
  uint32_t nowEpoch = timeManager::nowEpoch();

  if (nowEpoch < lastWaterEpoch) {
    return 0;
  }

  return (unsigned long)((nowEpoch - lastWaterEpoch) / 60UL);
}

unsigned long getDailySteps() {
  return dailySteps;
}

unsigned long getDailyActiveMinutes() {
  return dailyActiveSeconds / 60UL;
}

int getActivityScore() {
  return calculateScore();
}

bool allDailyGoalsMet() {
  return dailyGoalsMet();
}

bool isInactive() {
  unsigned long now = millis();

  return
      now - lastMovementMs >=
      INACTIVITY_TIMEOUT_MINUTES * 60000UL;
}

unsigned long getInactiveMinutes() {
  return (millis() - lastMovementMs) / 60000UL;
}

bool exerciseReminderPending() {
  return exerciseReminderPendingFlag;
}

void dismissExerciseReminder() {
  exerciseReminderPendingFlag = false;
}

bool fallDetected() {
  return false;
}

void dismissFallAlert() {
  fallAlertUntilMs = 0;
}

void toggleBreathing() {
  if (breathingRunning) {
    breathingRunning = false;
    return;
  }

  breathingRunning = true;
  breathingStartedMs = millis();
}

bool isBreathing() {
  return breathingRunning;
}

const char* getBreathingPhase() {
  if (!breathingRunning) {
    return "READY";
  }

  unsigned long cycle =
      BREATH_INHALE_MS +
      BREATH_HOLD1_MS +
      BREATH_EXHALE_MS +
      BREATH_HOLD2_MS;

  unsigned long t =
      (millis() - breathingStartedMs) % cycle;

  if (t < BREATH_INHALE_MS) {
    return "INHALE";
  }

  t -= BREATH_INHALE_MS;

  if (t < BREATH_HOLD1_MS) {
    return "HOLD";
  }

  t -= BREATH_HOLD1_MS;

  if (t < BREATH_EXHALE_MS) {
    return "EXHALE";
  }

  return "HOLD";
}

int getBreathingPhasePercent() {
  if (!breathingRunning) {
    return 0;
  }

  unsigned long cycle =
      BREATH_INHALE_MS +
      BREATH_HOLD1_MS +
      BREATH_EXHALE_MS +
      BREATH_HOLD2_MS;

  unsigned long t =
      (millis() - breathingStartedMs) % cycle;

  unsigned long phaseDuration = 0;
  unsigned long phaseElapsed = 0;

  if (t < BREATH_INHALE_MS) {
    phaseDuration = BREATH_INHALE_MS;
    phaseElapsed = t;
  }

  else {
    t -= BREATH_INHALE_MS;

    if (t < BREATH_HOLD1_MS) {
      phaseDuration = BREATH_HOLD1_MS;
      phaseElapsed = t;
    }

    else {
      t -= BREATH_HOLD1_MS;

      if (t < BREATH_EXHALE_MS) {
        phaseDuration = BREATH_EXHALE_MS;
        phaseElapsed = t;
      }

      else {
        t -= BREATH_EXHALE_MS;
        phaseDuration = BREATH_HOLD2_MS;
        phaseElapsed = t;
      }
    }
  }

  if (phaseDuration == 0) {
    return 0;
  }

  return constrain(
      (int)(phaseElapsed * 100UL / phaseDuration),
      0,
      100
  );
}

bool isDnd() {
  return dndEnabled;
}

void toggleDnd() {
  setDnd(!dndEnabled);
}

void setDnd(bool enabled) {
  dndEnabled = enabled;
  storage::saveBool("dnd", dndEnabled);

  if (dndEnabled) {
    waterReminderPendingFlag = false;
  }
}

int getStreak() {
  return streakDays;
}

uint32_t getAchievementsMask() {
  return achievementMask;
}

int getAchievementCount() {
  int count = 0;

  uint32_t mask = achievementMask;
  while (mask != 0) {
    if (mask & 1UL) {
      count++;
    }
    mask >>= 1;
  }

  return count;
}

} // namespace wellness
