// ============================================================
// HEALTH DEVICE â€” main firmware
// ESP32-C3 Super Mini
// ============================================================

#include <Wire.h>
#include "config.h"

#include "ble_manager.h"
#include "storage.h"
#include "settings.h"
#include "battery.h"
#include "button.h"
#include "alerts.h"
#include "sensors.h"
#include "posture.h"
#include "activity.h"
#include "timer.h"
#include "reminders.h"
#include "alarms.h"
#include "time_manager.h"
#include "wifi_manager.h"
#include "display.h"
#include "wellness.h"
#include "history.h"


// ============================================================
// CONTINUOUS BAD POSTURE ALERT STATE MACHINE
// ============================================================
static unsigned long badPostureStartMs = 0;
static bool postureAlertActive = false;
static bool postureBeepingActive = false;
static bool postureSnoozed = false;
static unsigned long postureSnoozeStartMs = 0;
static unsigned long lastPostureBeepMs = 0;
static DeviceScreen screenBeforePostureAlert = SCR_HOME;

// ============================================================
// LOW POWER MODE
// ============================================================

static bool lowPowerMode = false;


// ============================================================
// HEART-RATE MODE
// false = Mode 1 (8-second automatic scan)
// true  = Mode 2 (real-time BPM)
// ============================================================

static bool hrRealtimeMode = false;

// MAX30102 power state
// The heart-rate sensor is powered only while the HR screen is active.
static bool hrSensorPowered = false;
static bool hrResultHandled = false;


// ============================================================
// TIMER EDIT MODE
// ============================================================

static bool timerEditMode = false;

// 0 = hours, 1 = minutes, 2 = seconds
static int timerEditField = 2;

// 0 = -10, 1 = -1, 2 = +1, 3 = +10
static int timerEditAction = 0;

static unsigned int timerEditHours = 0;
static unsigned int timerEditMinutes = 0;
static unsigned int timerEditSeconds = 0;


// Main MENU selection mode.
// false = normal navigation.
// true  = triple-click activated menu option selection.
static bool menuSelectionMode = false;


static void syncTimerEditDisplay();


// ============================================================
// RGB STATUS LED
// ============================================================

static const unsigned long LED_BLINK_INTERVAL_MS = 400;
static const unsigned long STOPWATCH_STOPPED_LED_MS = 3000;

// Heart-rate / SpO2 measurement feedback.
// Blue = heart-rate scan, Yellow = SpO2 measurement.
static const unsigned long MEASUREMENT_LED_BLINK_MS = 300;
static const unsigned long MEASUREMENT_BEEP_REPEAT_MS = 1200;
static unsigned long lastMeasurementLedMs = 0;
static unsigned long lastMeasurementBeepMs = 0;
static bool measurementLedState = false;
static bool measurementFeedbackWasActive = false;

static const uint8_t LED_YELLOW_RED = 255;
static const uint8_t LED_YELLOW_GREEN = 70;
static const uint8_t LED_YELLOW_BLUE = 0;

static unsigned long lastTimerLedBlinkMs = 0;
static bool timerLedBlinkState = false;

// Mirrors the stopwatch state for the RGB LED.
// The stopwatch itself remains owned by display.cpp.
static bool stopwatchStatusRunning = false;

// Detects an actual RUNNING -> STOPPED transition only.
static bool stopwatchLedWasInMode = false;
static bool stopwatchLedLastRunning = false;
static unsigned long stopwatchStoppedLedUntilMs = 0;


static void setStatusLed(
    bool red,
    bool green,
    bool blue
) {

  // Common-cathode RGB LED. Apply the user-selected brightness.
  const int ledMax = settings::getLedHigh() ? 255 : 80;
  analogWrite(PIN_RGB_RED, red ? ledMax : 0);
  analogWrite(PIN_RGB_GREEN, green ? ledMax : 0);
  analogWrite(PIN_RGB_BLUE, blue ? ledMax : 0);
}


static void setStopwatchYellowLed() {

  const float scale = settings::getLedHigh() ? 1.0f : (80.0f / 255.0f);
  analogWrite(PIN_RGB_RED, (int)(LED_YELLOW_RED * scale));
  analogWrite(PIN_RGB_GREEN, (int)(LED_YELLOW_GREEN * scale));
  analogWrite(PIN_RGB_BLUE, (int)(LED_YELLOW_BLUE * scale));
}

static void setStatusLedRgb(uint8_t r, uint8_t g, uint8_t b) {
  const float scale = settings::getLedHigh() ? 1.0f : (80.0f / 255.0f);
  analogWrite(PIN_RGB_RED, (int)(r * scale));
  analogWrite(PIN_RGB_GREEN, (int)(g * scale));
  analogWrite(PIN_RGB_BLUE, (int)(b * scale));
}


static void updateStatusLed() {
  if (alerts::isRGBOverridden()) return;

  DeviceScreen current =
      display::getCurrentScreen();

  unsigned long now = millis();

  // -----------------------------------------------------------
  // ALARM RINGING -> CUSTOM PER-ALARM RGB LED BLINK
  // -----------------------------------------------------------
  static unsigned long lastAlarmLedBlinkMs = 0;
  static bool alarmLedBlinkState = false;

  if (current == SCR_ALERT_ALARM || alarms::isRinging()) {
    if (now - lastAlarmLedBlinkMs >= 200) {
      lastAlarmLedBlinkMs = now;
      alarmLedBlinkState = !alarmLedBlinkState;
    }
    if (alarmLedBlinkState) {
      const Alarm& a = alarms::getRinging();
      if (a.r == 0 && a.g == 0 && a.b == 0) {
        setStatusLedRgb(255, 0, 0); // fallback bright red
      } else {
        setStatusLedRgb(a.r, a.g, a.b);
      }
    } else {
      setStatusLed(false, false, false);
    }
    return;
  } else {
    lastAlarmLedBlinkMs = now;
    alarmLedBlinkState = false;
  }

  // -----------------------------------------------------------
  // BAD POSTURE ALERT -> RED LIGHT GLOWS
  // -----------------------------------------------------------
  if (postureAlertActive && !postureSnoozed) {
    setStatusLed(true, false, false);
    return;
  }


  // -----------------------------------------------------------
  // TIMER FINISHED -> BLINK RED
  // -----------------------------------------------------------

  if (
      current == SCR_ALERT_TIMER_DONE &&
      healthTimer::isFinished()
  ) {

    if (
        now - lastTimerLedBlinkMs >=
        LED_BLINK_INTERVAL_MS
    ) {

      lastTimerLedBlinkMs = now;
      timerLedBlinkState = !timerLedBlinkState;
    }

    setStatusLed(
        timerLedBlinkState,
        false,
        false
    );

    return;
  }

  lastTimerLedBlinkMs = now;
  timerLedBlinkState = false;


  // -----------------------------------------------------------
  // HEART-RATE MEASUREMENT FEEDBACK
  // -----------------------------------------------------------
  // This feedback is intentionally NOT used in LIVE VITALS.
  // HR scan = blue blink + optional beep-beep.
  // LIVE VITALS = steady cyan glow while a finger is present.

  if (current == SCR_HEART_RATE) {

    bool liveVitals = hrRealtimeMode;
    bool measuring = false;
    if (liveVitals) {
      if (hrSensor::isFingerDetected()) {
        setStatusLed(false, true, true); // cyan glow
        return;
      }
    }
    else {
      measuring = hrSensor::isScanning();
    }

    if (measuring) {

      measurementFeedbackWasActive = true;

      if (now - lastMeasurementLedMs >= MEASUREMENT_LED_BLINK_MS) {
        lastMeasurementLedMs = now;
        measurementLedState = !measurementLedState;
      }

      if (measurementLedState) {
        setStatusLed(false, false, true); // blue
      } else {
        setStatusLed(false, false, false);
      }

      if (settings::getMeasurementSoundEnabled() &&
          settings::getSoundEnabled() &&
          settings::getSoundVolume() > 0 &&
          now - lastMeasurementBeepMs >= MEASUREMENT_BEEP_REPEAT_MS) {
        lastMeasurementBeepMs = now;
        alerts::beepPattern(2, 70, 90); // beep-beep
      }

      return;
    }

    lastMeasurementLedMs = now;
    measurementLedState = false;
    lastMeasurementBeepMs = now;

    // beepPattern() is non-blocking. Cancel a queued measurement
    // beep immediately when the scan ends or the finger is removed.
    if (measurementFeedbackWasActive) {
      alerts::buzzerStop();
      measurementFeedbackWasActive = false;
    }
  }


  // -----------------------------------------------------------
  // HEART-RATE RESULT ALERT
  // -----------------------------------------------------------

  int hrColor = wellness::getHRAlertColor();

  if (hrColor == 1) {
    setStatusLed(false, true, false);
    return;
  }

  if (hrColor == 2) {
    setStatusLed(true, false, false);
    return;
  }

  if (hrColor == 3) {
    setStatusLed(false, false, true);
    return;
  }


  // -----------------------------------------------------------
  // FALL ALERT -> DISABLED
  // -----------------------------------------------------------
  // (Fall alert disabled per user request)


  // -----------------------------------------------------------
  // STOPWATCH
  // RUNNING -> GREEN continuously
  // RUNNING -> STOPPED -> tuned YELLOW for 3 seconds
  // ENTERING STOPWATCH WHILE STOPPED -> LED OFF
  // -----------------------------------------------------------

  if (
      current == SCR_CLOCK &&
      display::getClockMode() == 2
  ) {

    if (stopwatchStatusRunning) {
      stopwatchStoppedLedUntilMs = 0;

      setStatusLed(
          false,
          true,
          false
      );
    }

    else {
      if (stopwatchLedLastRunning) {
        stopwatchStoppedLedUntilMs =
            now + STOPWATCH_STOPPED_LED_MS;
      }

      if (
          stopwatchStoppedLedUntilMs != 0 &&
          (long)(stopwatchStoppedLedUntilMs - now) > 0
      ) {
        setStopwatchYellowLed();
      }
      else {
        setStatusLed(false, false, false);
      }
    }

    stopwatchLedWasInMode = true;
    stopwatchLedLastRunning = stopwatchStatusRunning;
    return;
  }


  // Leaving Stopwatch turns its indication OFF.
  stopwatchLedWasInMode = false;
  stopwatchLedLastRunning = false;
  stopwatchStoppedLedUntilMs = 0;

  setStatusLed(false, false, false);
}


static void enterTimerEditMode() {

  unsigned long total =
      healthTimer::getDurationSeconds();

  timerEditHours =
      total / 3600UL;

  total %= 3600UL;

  timerEditMinutes =
      total / 60UL;

  timerEditSeconds =
      total % 60UL;

  // Start on seconds. The four +/- controls are selected
  // separately with double-click.
  timerEditField =
      2;

  timerEditAction =
      0;

  timerEditMode =
      true;

  syncTimerEditDisplay();
}


static void applyTimerEditAction() {

  int delta =
      0;

  if (
      timerEditAction == 0
  ) {

    delta =
        -10;
  }

  else if (
      timerEditAction == 1
  ) {

    delta =
        -1;
  }

  else if (
      timerEditAction == 2
  ) {

    delta =
        1;
  }

  else {

    delta =
        10;
  }


  // -----------------------------------------------------------
  // HOURS
  // -----------------------------------------------------------

  if (
      timerEditField == 0
  ) {

    int value =
        (int)timerEditHours +
        delta;

    if (
        value < 0
    ) {

      value =
          0;
    }

    if (
        value > 24
    ) {

      value =
          24;
    }

    timerEditHours =
        (unsigned int)value;

    if (
        timerEditHours == 24
    ) {

      timerEditMinutes =
          0;

      timerEditSeconds =
          0;
    }
  }


  // -----------------------------------------------------------
  // MINUTES / SECONDS
  // -----------------------------------------------------------

  else {

    if (
        timerEditHours == 24
    ) {

      return;
    }

    unsigned int* value =
        timerEditField == 1
            ? &timerEditMinutes
            : &timerEditSeconds;

    int currentValue =
        (int)(*value);

    int nextValue =
        currentValue +
        delta;

    // Minutes and seconds cycle inside 00..59.
    while (
        nextValue < 0
    ) {

      nextValue +=
          60;
    }

    while (
        nextValue > 59
    ) {

      nextValue -=
          60;
    }

    *value =
        (unsigned int)nextValue;
  }


  syncTimerEditDisplay();
}


static void moveTimerEditField() {

  // Field movement follows the displayed time from RIGHT to LEFT:
  // SEC -> MIN -> HR -> SEC
  // Display order is: HR : MIN : SEC

  if (
      timerEditField == 2
  ) {

    timerEditField =
        1;
  }

  else if (
      timerEditField == 1
  ) {

    timerEditField =
        0;
  }

  else {

    timerEditField =
        2;
  }

  // Every new time field starts with -10 selected.
  timerEditAction =
      0;

  syncTimerEditDisplay();
}


static void moveTimerEditAction() {

  timerEditAction++;

  if (
      timerEditAction > 3
  ) {

    timerEditAction =
        0;
  }

  syncTimerEditDisplay();
}


static void saveTimerEditMode() {

  unsigned long total =
      (
          (unsigned long)timerEditHours * 3600UL
      ) +
      (
          (unsigned long)timerEditMinutes * 60UL
      ) +
      (unsigned long)timerEditSeconds;

  // Timer module requires at least one second.
  // If the user saves 00:00:00, keep it at 00:00:01.

  if (
      total < 1
  ) {

    total =
        1;
  }

  const unsigned long MAX_SECONDS =
      24UL * 60UL * 60UL;

  if (
      total > MAX_SECONDS
  ) {

    total =
        MAX_SECONDS;
  }

  healthTimer::setDurationSeconds(
      total
  );

  timerEditMode =
      false;

  syncTimerEditDisplay();
}


static void cancelTimerEditMode() {

  timerEditMode =
      false;

  display::setTimerEditState(
      false,
      0,
      0,
      0,
      0,
      0
  );
}


static void syncTimerEditDisplay() {

  display::setTimerEditState(
      timerEditMode,
      timerEditHours,
      timerEditMinutes,
      timerEditSeconds,
      timerEditField,
      timerEditAction
  );
}


static void updateHRSensorPower() {

  DeviceScreen current =
      display::getCurrentScreen();

  bool shouldBePowered =
      (
          current == SCR_HEART_RATE &&
          !lowPowerMode
      );

  if (
      shouldBePowered &&
      !hrSensorPowered
  ) {

    hrSensor::powerOn();

    hrSensorPowered =
        true;

    return;
  }

  if (
      !shouldBePowered &&
      hrSensorPowered
  ) {

    hrSensor::cancelScan();

    hrSensor::stopRealtime();

    hrRealtimeMode = false;

    hrSensor::powerOff();

    hrSensorPowered =
        false;
  }
}


// ============================================================
// REMEMBERS WHICH NORMAL SCREEN TO RETURN TO AFTER AN ALERT
// ============================================================

static DeviceScreen screenBeforeAlert =
    SCR_HOME;

static DeviceScreen screenBeforeFall =
    SCR_HOME;

static bool fallOverlayActive =
    false;


// ============================================================
// PERIODIC TIMERS
// ============================================================

static unsigned long lastBatteryUpdate =
    0;

static const unsigned long
    BATTERY_UPDATE_INTERVAL_MS = 2000;


// ============================================================
// HARDWARE DIAGNOSTICS
// ============================================================

static bool hwOledOk = false;
static bool hwMaxOk = false;
static bool hwMpuOk = false;


// =================================================================
// SERIAL DIAGNOSTICS
// =================================================================

static void printDiagnosticsSerial() {

  Serial.println(
      "---- HEALTH DEVICE DIAGNOSTICS ----"
  );

  Serial.print(
      "OLED     "
  );

  Serial.println(
      hwOledOk ? "OK" : "FAIL"
  );

  Serial.print(
      "MAX30102 "
  );

  Serial.println(
      hwMaxOk ? "OK" : "FAIL"
  );

  Serial.print(
      "MPU-6500 "
  );

  Serial.println(
      hwMpuOk ? "OK" : "FAIL"
  );

  Serial.println(
      "BUTTON   OK"
  );

  Serial.println(
      "STORAGE  OK"
  );

  Serial.println(
      "------------------------------------"
  );
}


// =================================================================
// LOW POWER
// =================================================================

static void enterLowPower() {

  lowPowerMode =
      true;

  hrSensor::cancelScan();

  hrSensor::powerOff();

  hrSensorPowered =
      false;

  display::sleep();
}


static void exitLowPower() {

  lowPowerMode =
      false;

  display::wake();

  display::goHome();
}


// =================================================================
// ALERT ARBITRATION
// =================================================================

static void updateAlertArbitration() {

  DeviceScreen current =
      display::getCurrentScreen();


  bool onOverlay =
      (
          current == SCR_ALERT_ALARM ||
          current == SCR_ALERT_REMINDER ||
          current == SCR_ALERT_TIMER_DONE
      );


  // ---------------------------------------------------------------
  // POSTURE ALERT
  // ---------------------------------------------------------------

  if (
      !wellness::isDnd() &&
      posture::hasBaseline() &&
      !posture::isGood()
  ) {

    alerts::raise(
        ALERT_POSTURE
    );

  }

  else {

    alerts::clear(
        ALERT_POSTURE
    );
  }


  // ---------------------------------------------------------------
  // CRITICAL BATTERY
  // ---------------------------------------------------------------

  if (
      battery::isCritical()
  ) {

    alerts::raise(
        ALERT_CRITICAL
    );

  }

  else {

    alerts::clear(
        ALERT_CRITICAL
    );
  }


  // ---------------------------------------------------------------
  // TIMER
  // ---------------------------------------------------------------

  if (
      healthTimer::isFinished() &&
      !wellness::isDnd()
  ) {

    alerts::raise(
        ALERT_TIMER
    );

  }

  else {

    alerts::clear(
        ALERT_TIMER
    );
  }


  // ---------------------------------------------------------------
  // DND â€” suppress non-critical reminder/timer notifications.
  // Important alerts and alarms must still be delivered.
  // ---------------------------------------------------------------

  if (wellness::isDnd()) {
    // DND suppresses non-critical notifications only.
    // Alarms and important safety alerts are never blocked by DND.
    alerts::clear(ALERT_REMINDER);
    alerts::clear(ALERT_TIMER);
  }


  // ---------------------------------------------------------------
  // REMINDER
  // ---------------------------------------------------------------

  if (
      !wellness::isDnd() &&
      reminders::hasPendingAlert()
  ) {

    alerts::raise(
        ALERT_REMINDER
    );

  }

  else {

    alerts::clear(
        ALERT_REMINDER
    );
  }


  // ---------------------------------------------------------------
  // ALARM
  // ---------------------------------------------------------------

  if (
      alarms::isRinging()
  ) {

    alerts::raise(
        ALERT_ALARM
    );

  }

  else {

    alerts::clear(
        ALERT_ALARM
    );
  }


  AlertPriority active =
      alerts::getActive();


  // ALARM has highest priority (1): immediately switch to SCR_ALERT_ALARM
  // and wake screen, overriding ANY lower-priority alert or overlay!
  if (active == ALERT_ALARM) {
    if (current != SCR_ALERT_ALARM) {
      screenBeforeAlert = (current == SCR_ALERT_POSTURE || current == SCR_ALERT_REMINDER || current == SCR_ALERT_TIMER_DONE)
          ? SCR_HOME
          : current;
      display::setScreen(SCR_ALERT_ALARM);
      display::wake();
    }
  }

  else if (!onOverlay) {

    if (
        active ==
        ALERT_TIMER
    ) {

      screenBeforeAlert =
          current;

      display::setScreen(
          SCR_ALERT_TIMER_DONE
      );
      display::wake();

      if (
          settings::getSoundEnabled()
      ) {

        alerts::beepPattern(
            4,
            200,
            200
        );
      }

    }

    else if (
        active ==
        ALERT_REMINDER
    ) {

      screenBeforeAlert =
          current;

      display::setScreen(
          SCR_ALERT_REMINDER
      );
      display::wake();

      if (
          settings::getSoundEnabled()
      ) {

        alerts::beepPattern(
            2,
            150,
            150
        );
      }
    }
  }
}


// =================================================================
// DISMISS ACTIVE ALERT
// =================================================================

static void dismissActiveOverlay() {

  DeviceScreen current =
      display::getCurrentScreen();


  if (
      current ==
      SCR_ALERT_ALARM
  ) {

    alarms::dismiss();

  }

  else if (
      current ==
      SCR_ALERT_TIMER_DONE
  ) {

    healthTimer::acknowledgeFinish();

    alerts::clear(
        ALERT_TIMER
    );

  }

  else if (
      current ==
      SCR_ALERT_REMINDER
  ) {

    reminders::dismissAlert();

    alerts::clear(
        ALERT_REMINDER
    );

  }

  else {

    return;
  }


  display::setScreen(
      screenBeforeAlert
  );
}


// =================================================================
// BUTTON CLICK SOUND
// =================================================================

static void playButtonClickBeep(
    ButtonEvent ev
) {

  // Only normal click events get the soft feedback beep.
  // Long press and low-power hold remain silent.
  if (
      ev != BTN_SINGLE_CLICK &&
      ev != BTN_DOUBLE_CLICK &&
      ev != BTN_TRIPLE_CLICK
  ) {

    return;
  }


  // Follow the existing global Sound setting.
  // Turning Sound OFF also turns button-click feedback OFF.
  if (
      !settings::getSoundEnabled() ||
      !settings::getClickSoundEnabled()
  ) {

    return;
  }


  // Short pulse = soft/low-volume button feedback.
  alerts::beepPattern(
      1,
      55,
      0
  );
}


// =================================================================
// BUTTON HANDLING
// =================================================================

static void handleButtonEvent(
    ButtonEvent ev
) {

  if (
      ev ==
      BTN_NONE
  ) {

    return;
  }


  DeviceScreen current =
      display::getCurrentScreen();


  // ---------------------------------------------------------------
  // LOW POWER WAKE
  // ---------------------------------------------------------------

  if (
      lowPowerMode
  ) {

    if (
        ev == BTN_SINGLE_CLICK ||
        ev == BTN_LONG_PRESS
    ) {

      exitLowPower();
    }

    return;
  }


  // ---------------------------------------------------------------
  // 3 SECOND LOW POWER
  // ---------------------------------------------------------------

  if (
      ev ==
      BTN_LOW_POWER_HOLD
  ) {

    // While editing an alarm's Set Time screen, a long hold must
    // never enter low-power mode. The hold belongs to the time editor.
    if (current == SCR_ALARM_SETUP) {
      display::requestRedraw();
      return;
    }

    enterLowPower();

    return;
  }


  // Soft feedback for normal button clicks.
  playButtonClickBeep(ev);


  // ---------------------------------------------------------------
  // ALERT OVERLAY (Alarm, Timer, Reminder - Top Priority)
  // ---------------------------------------------------------------

  if (
      current == SCR_ALERT_ALARM ||
      current == SCR_ALERT_TIMER_DONE ||
      current == SCR_ALERT_REMINDER
  ) {

    if (
        ev == BTN_SINGLE_CLICK ||
        ev == BTN_DOUBLE_CLICK ||
        ev == BTN_LONG_PRESS
    ) {

      dismissActiveOverlay();
    }

    return;
  }

  // ---------------------------------------------------------------
  // FALL ALERT OVERLAY
  // ---------------------------------------------------------------

  if (current == SCR_ALERT_FALL) {

    if (
        ev == BTN_SINGLE_CLICK ||
        ev == BTN_DOUBLE_CLICK ||
        ev == BTN_LONG_PRESS
    ) {
      wellness::dismissFallAlert();
      fallOverlayActive = false;
      display::setScreen(screenBeforeFall);
    }

    display::requestRedraw();
    return;
  }

  // ---------------------------------------------------------------
  // POSTURE ALERT DISMISS / SNOOZE
  // ---------------------------------------------------------------
  if (current == SCR_ALERT_POSTURE || (postureAlertActive && !postureSnoozed)) {
    if (
        ev == BTN_SINGLE_CLICK ||
        ev == BTN_DOUBLE_CLICK ||
        ev == BTN_LONG_PRESS
    ) {
      alerts::buzzerStop();
      postureSnoozed = true;
      postureSnoozeStartMs = millis();
      postureAlertActive = false;
      postureBeepingActive = false;
      if (current == SCR_ALERT_POSTURE) {
        display::setScreen(screenBeforePostureAlert);
      }
      display::requestRedraw();
      return;
    }
  }


  // ---------------------------------------------------------------
  // HEALTH HISTORY LISTS
  // ---------------------------------------------------------------

  if (current == SCR_HR_HISTORY || current == SCR_SPO2_HISTORY) {
    if (ev == BTN_SINGLE_CLICK) {
      display::nextHealthHistoryItem();
      display::requestRedraw();
      return;
    }
    if (ev == BTN_TRIPLE_CLICK || ev == BTN_DOUBLE_CLICK) {
      display::resetHealthHistory();
      display::setScreen(SCR_MENU);
      display::requestRedraw();
      return;
    }
    display::requestRedraw();
    return;
  }


  // ---------------------------------------------------------------
  // HEART RATE
  // ---------------------------------------------------------------

  if (
      current ==
      SCR_HEART_RATE
  ) {

    if (
        ev ==
        BTN_TRIPLE_CLICK
    ) {

      // Triple-click toggles: HEART RATE <-> LIVE VITALS.
      // SpO2 is available only as part of LIVE VITALS.
      if (!hrRealtimeMode) {

        hrSensor::cancelScan();
        hrSensor::clearResult();
        hrRealtimeMode = true;
        hrSensor::startRealtime();

        Serial.println(
            "HR MODE: LIVE VITALS"
        );
      }

      else {

        hrRealtimeMode = false;
        hrSensor::stopRealtime();
        hrSensor::cancelScan();
        hrSensor::clearResult();

        Serial.println(
            "HR MODE: 8-SECOND AUTO SCAN"
        );
      }

      display::requestRedraw();
      return;
    }


    if (
        hrRealtimeMode
    ) {

      if (
          ev ==
          BTN_SINGLE_CLICK
      ) {

        display::nextScreen();
      }


      display::requestRedraw();

      return;
    }


    if (
        !hrSensor::isScanning() &&
        !hrSensor::hasResult() &&
        !hrSensor::scanFailed()
    ) {

      if (
          ev ==
          BTN_SINGLE_CLICK
      ) {

        display::nextScreen();

      }

      else if (
          ev ==
          BTN_LONG_PRESS
      ) {

        hrSensor::startScan();
      }


      display::requestRedraw();

      return;
    }


    if (
        hrSensor::isScanning()
    ) {

      if (
          ev ==
          BTN_DOUBLE_CLICK
      ) {

        hrSensor::cancelScan();

        hrSensor::clearResult();
      }


      display::requestRedraw();

      return;
    }


    if (
        hrSensor::hasResult() ||
        hrSensor::scanFailed()
    ) {

      if (
          ev ==
          BTN_SINGLE_CLICK
      ) {

        hrSensor::clearResult();

      }

      else if (
          ev ==
          BTN_LONG_PRESS
      ) {

        hrSensor::clearResult();

        hrSensor::startScan();
      }


      display::requestRedraw();

      return;
    }


    display::requestRedraw();

    return;
  }


  // ---------------------------------------------------------------
  // CLOCK SECTION
  // ---------------------------------------------------------------

  if (
      current ==
      SCR_CLOCK
  ) {

    // -----------------------------------------------------------
    // TIMER EDIT MODE HAS PRIORITY
    // -----------------------------------------------------------
    //
    // While editing, triple click MUST save and exit edit mode.
    // It must NOT change CLOCK / TIMER / STOPWATCH / ALARM.
    // -----------------------------------------------------------

    if (
        timerEditMode
    ) {

      // Single click: apply the currently highlighted action.
      if (
          ev == BTN_SINGLE_CLICK
      ) {

        applyTimerEditAction();
      }

      // Double click: move between -10 / -1 / +1 / +10.
      else if (
          ev == BTN_DOUBLE_CLICK
      ) {

        moveTimerEditAction();
      }

      // Long press: move SEC -> MIN -> HR -> SEC.
      else if (
          ev == BTN_LONG_PRESS
      ) {

        moveTimerEditField();
      }

      // Triple click: SAVE and exit edit mode only.
      else if (
          ev == BTN_TRIPLE_CLICK
      ) {

        saveTimerEditMode();
      }

      display::requestRedraw();

      return;
    }


    // -----------------------------------------------------------
    // NORMAL CLOCK-SECTION TRIPLE CLICK
    // -----------------------------------------------------------
    //
    // CLOCK -> TIMER -> STOPWATCH -> ALARM -> CLOCK
    //
    // This is checked before the individual mode controls so
    // triple click is available in every normal Clock-section mode.
    // -----------------------------------------------------------

    if (
        ev ==
        BTN_TRIPLE_CLICK
    ) {

      display::nextClockMode();

      display::requestRedraw();

      return;
    }


    // -----------------------------------------------------------
    // TIMER
    // -----------------------------------------------------------

    if (
        display::getClockMode() ==
        1
    ) {

      // Long press: START / PAUSE
      if (
          ev == BTN_LONG_PRESS
      ) {

        if (
            healthTimer::isRunning()
        ) {

          healthTimer::pause();
        }

        else {

          healthTimer::start();
        }
      }

      // Double click:
      // Running timer -> reset.
      // Stopped timer -> enter edit mode.
      else if (
          ev == BTN_DOUBLE_CLICK
      ) {

        if (
            healthTimer::isRunning()
        ) {

          healthTimer::reset();
        }

        else {

          enterTimerEditMode();
        }
      }

      // Single click: leave Clock section.
      else if (
          ev == BTN_SINGLE_CLICK
      ) {

        display::nextScreen();
      }

      display::requestRedraw();

      return;
    }


    // -----------------------------------------------------------
    // STOPWATCH
    // -----------------------------------------------------------

    if (
        display::getClockMode() ==
        2
    ) {

      if (
          ev == BTN_LONG_PRESS
      ) {

        display::toggleStopwatch();

        stopwatchStatusRunning =
            !stopwatchStatusRunning;
      }

      else if (
          ev == BTN_DOUBLE_CLICK
      ) {

        display::resetStopwatch();

        stopwatchStatusRunning =
            false;
      }

      else if (
          ev == BTN_SINGLE_CLICK
      ) {

        display::nextScreen();
      }

      display::requestRedraw();

      return;
    }


    // -----------------------------------------------------------
    // CLOCK / ALARM
    // -----------------------------------------------------------

    if (
        ev == BTN_SINGLE_CLICK
    ) {

      display::nextScreen();
    }

    display::requestRedraw();

    return;
  }


  // ---------------------------------------------------------------
  // POSTURE
  // ---------------------------------------------------------------

  if (
      current ==
      SCR_POSTURE
  ) {

    if (
        ev ==
        BTN_SINGLE_CLICK
    ) {

      display::nextScreen();
    }

    else if (
        ev ==
        BTN_LONG_PRESS
    ) {

      display::setScreen(
          SCR_POSTURE_SETUP
      );
    }


    display::requestRedraw();

    return;
  }


  // ---------------------------------------------------------------
  // POSTURE SETUP
  // ---------------------------------------------------------------

  if (
      current ==
      SCR_POSTURE_SETUP
  ) {

    if (
        ev == BTN_SINGLE_CLICK ||
        ev == BTN_LONG_PRESS
    ) {

      posture::startCalibration();

      display::setScreen(
          SCR_POSTURE_CALIBRATING
      );


      if (
          settings::getSoundEnabled()
      ) {

        alerts::beepShort();
      }

    }

    else if (
        ev ==
        BTN_DOUBLE_CLICK
    ) {

      display::setScreen(
          SCR_POSTURE
      );
    }


    display::requestRedraw();

    return;
  }


  // ---------------------------------------------------------------
  // POSTURE CALIBRATING
  // ---------------------------------------------------------------

  if (
      current ==
      SCR_POSTURE_CALIBRATING
  ) {

    if (
        ev == BTN_SINGLE_CLICK ||
        ev == BTN_DOUBLE_CLICK
    ) {

      display::setScreen(
          SCR_POSTURE
      );
    }


    display::requestRedraw();

    return;
  }


  // ---------------------------------------------------------------
  // WELLNESS
  // ---------------------------------------------------------------

  if (current == SCR_WELLNESS) {

    // Only water logging is controlled from this screen.
    // Reminders and breathing have dedicated screens.
    if (ev == BTN_DOUBLE_CLICK) {
      wellness::addWater(1);
      wellness::dismissWaterReminder();
      wellness::dismissExerciseReminder();
      display::requestRedraw();
      return;
    }

    if (ev == BTN_SINGLE_CLICK) {
      display::nextScreen();
    }

    display::requestRedraw();
    return;
  }


  // ---------------------------------------------------------------
  // BREATHING EXERCISE
  // ---------------------------------------------------------------

  if (current == SCR_BREATHING) {

    if (ev == BTN_LONG_PRESS) {
      wellness::toggleBreathing();
    }

    else if (ev == BTN_SINGLE_CLICK) {
      if (wellness::isBreathing()) {
        wellness::toggleBreathing();
      }
      display::nextScreen();
    }

    else if (ev == BTN_DOUBLE_CLICK) {
      if (wellness::isBreathing()) {
        wellness::toggleBreathing();
      }
      display::goHome();
    }

    display::requestRedraw();
    return;
  }


  // ---------------------------------------------------------------
  // GOALS / STREAKS / ACHIEVEMENTS
  // ---------------------------------------------------------------

  if (current == SCR_GOALS) {

    if (ev == BTN_SINGLE_CLICK) {
      display::nextScreen();
    }

    display::requestRedraw();
    return;
  }


  // ---------------------------------------------------------------
  // REMINDERS
  // ---------------------------------------------------------------
  // Reminder creation/editing is handled by the companion application.
  // The device provides an ON/OFF management menu.
  //
  // Normal mode:
  //   1 click  -> leave Reminders / next screen
  //   3 clicks -> open ON/OFF menu
  //
  // ON/OFF menu:
  //   1 click  -> next reminder
  //   2 clicks -> toggle selected reminder ON/OFF
  //   3 clicks -> exit ON/OFF menu

  if (current == SCR_REMINDERS) {

    if (ev == BTN_TRIPLE_CLICK) {

      display::startReminderSelection();
      display::requestRedraw();
      return;
    }

    if (display::isReminderSelectionActive()) {

      if (ev == BTN_SINGLE_CLICK) {
        display::nextReminderItem();
      }

      else if (ev == BTN_DOUBLE_CLICK) {
        display::toggleSelectedReminder();
      }

      display::requestRedraw();
      return;
    }

    if (ev == BTN_SINGLE_CLICK) {
      display::nextScreen();
    }

    display::requestRedraw();
    return;
  }


  // ---------------------------------------------------------------
  // MAIN MENU
  // ---------------------------------------------------------------

  if (
      current ==
      SCR_MENU
  ) {

    // -----------------------------------------------------------
    // TRIPLE CLICK
    // -----------------------------------------------------------

    if (ev == BTN_TRIPLE_CLICK) {

      if (menuSelectionMode) {
        menuSelectionMode = false;
        display::resetMenuSelection();
      }
      else {
        menuSelectionMode = true;
        display::startMenuSelection();
      }

      display::requestRedraw();
      return;
    }


    // -----------------------------------------------------------
    // SELECTION MODE
    // -----------------------------------------------------------

    if (menuSelectionMode) {

      if (ev == BTN_SINGLE_CLICK) {
        display::nextMenuItem();
      }

      else if (ev == BTN_DOUBLE_CLICK) {
        display::activateMenuItem();
        menuSelectionMode = false;
      }

      display::requestRedraw();
      return;
    }


    // -----------------------------------------------------------
    // NORMAL MENU MODE
    // -----------------------------------------------------------

    if (ev == BTN_SINGLE_CLICK) {
      display::nextScreen();
    }

    display::requestRedraw();
    return;
  }


  // ---------------------------------------------------------------
  // SETTINGS MENU
  // ---------------------------------------------------------------

  if (
      current ==
      SCR_SETTINGS
  ) {

    // Single click -> next setting.
    // Double click -> open selected setting.
    // Triple click -> return to the main MENU.

    if (ev == BTN_SINGLE_CLICK) {
      display::nextSettingsItem();
    }

    else if (ev == BTN_DOUBLE_CLICK) {
      display::activateSettingsItem();
    }

    else if (ev == BTN_TRIPLE_CLICK) {
      display::resetSettingsSelection();
      display::setScreen(SCR_MENU);
    }

    display::requestRedraw();
    return;
  }


  // ---------------------------------------------------------------
  // ALARM LIST
  // ---------------------------------------------------------------

  if (
      current ==
      SCR_ALARM_LIST
  ) {

    // Single click -> next alarm.
    if (ev == BTN_SINGLE_CLICK) {

      display::nextAlarmListItem();

      display::requestRedraw();

      return;
    }

    // Double click -> open the selected alarm setup.
    if (ev == BTN_DOUBLE_CLICK) {

      display::openAlarmSetup(
          display::getAlarmListSelection()
      );

      display::requestRedraw();

      return;
    }

    // Triple click -> back to Settings.
    if (ev == BTN_TRIPLE_CLICK) {

      display::setScreen(
          SCR_SETTINGS
      );

      display::requestRedraw();

      return;
    }

    display::requestRedraw();

    return;
  }


  // ---------------------------------------------------------------
  // ALARM SETUP
  // ---------------------------------------------------------------

  if (
      current ==
      SCR_ALARM_SETUP
  ) {

    // Single click and hold-repeat both increase
    // the currently selected Set Time value.
    if (
        ev == BTN_SINGLE_CLICK ||
        ev == BTN_HOLD_REPEAT
    ) {
      display::alarmSetupSingleAction();
    }

    // Long press is used by the Set Time editor too.
    // Consume it here so it cannot reach the global power-off action.
    else if (ev == BTN_LONG_PRESS) {
      display::alarmSetupSingleAction();
    }

    else if (ev == BTN_DOUBLE_CLICK) {
      display::alarmSetupDoubleAction();
    }

    else if (ev == BTN_TRIPLE_CLICK) {
      display::alarmSetupTripleAction();
    }

    display::requestRedraw();
    return;
  }


  // ---------------------------------------------------------------
  // SETTINGS DISPLAY
  // ---------------------------------------------------------------

  if (
      current ==
      SCR_SETTINGS_DISPLAY
  ) {

    if (ev == BTN_SINGLE_CLICK) {
      display::displaySettingsSingleAction();
    }
    else if (ev == BTN_HOLD_REPEAT) {
      display::displaySettingsHoldRepeat();
    }
    else if (ev == BTN_DOUBLE_CLICK) {
      display::displaySettingsDoubleAction();
    }
    else if (ev == BTN_TRIPLE_CLICK) {
      display::displaySettingsTripleAction();
    }

    display::requestRedraw();
    return;
  }


  // ---------------------------------------------------------------
  // SETTINGS SOUND / DND
  // ---------------------------------------------------------------

  if (
      current ==
      SCR_SETTINGS_SOUND
  ) {

    if (ev == BTN_SINGLE_CLICK) {
      display::soundSettingsSingleAction();
    }
    else if (ev == BTN_HOLD_REPEAT) {
      display::soundSettingsHoldRepeat();
    }
    else if (ev == BTN_DOUBLE_CLICK) {
      display::soundSettingsDoubleAction();
    }
    else if (ev == BTN_TRIPLE_CLICK) {
      display::soundSettingsTripleAction();
    }

    display::requestRedraw();
    return;
  }


  // ---------------------------------------------------------------
  // SETTINGS WI-FI
  // ---------------------------------------------------------------

  if (
      current ==
      SCR_SETTINGS_WIFI
  ) {

    // Single click -> next Wi-Fi row.
    if (ev == BTN_SINGLE_CLICK) {

      display::nextWiFiItem();
    }

    // Double click -> toggle Wi-Fi when the Wi-Fi row is selected.
    else if (ev == BTN_DOUBLE_CLICK) {

      if (display::getWiFiSelection() == 0) {
        wifiManager::setEnabled(
            !wifiManager::isEnabled()
        );
      }
    }

    // Triple click -> back to Settings.
    else if (ev == BTN_TRIPLE_CLICK) {

      display::resetWiFiSelection();

      display::setScreen(
          SCR_SETTINGS
      );
    }

    display::requestRedraw();

    return;
  }


  // ---------------------------------------------------------------
  // SETTINGS SYSTEM
  // ---------------------------------------------------------------

  if (
      current ==
      SCR_SETTINGS_SYSTEM
  ) {

    if (ev == BTN_SINGLE_CLICK) {
      display::nextSystemItem();
    }
    else if (ev == BTN_DOUBLE_CLICK) {
      display::activateSystemItem();
    }
    else if (ev == BTN_TRIPLE_CLICK) {
      display::resetSystemSelection();
      display::setScreen(SCR_SETTINGS);
    }

    display::requestRedraw();
    return;
  }


  // ---------------------------------------------------------------
  // ABOUT SYSTEM
  // ---------------------------------------------------------------

  if (
      current ==
      SCR_ABOUT_SYSTEM
  ) {

    if (
        ev == BTN_SINGLE_CLICK ||
        ev == BTN_DOUBLE_CLICK ||
        ev == BTN_TRIPLE_CLICK
    ) {
      display::setScreen(
          SCR_SETTINGS_SYSTEM
      );
    }

    display::requestRedraw();
    return;
  }


  // ---------------------------------------------------------------
  // DIAGNOSTICS
  // ---------------------------------------------------------------

  if (
      current ==
      SCR_DIAGNOSTICS
  ) {

    if (
        ev == BTN_SINGLE_CLICK ||
        ev == BTN_DOUBLE_CLICK ||
        ev == BTN_TRIPLE_CLICK
    ) {

      display::setScreen(
          SCR_SETTINGS_SYSTEM
      );
    }


    display::requestRedraw();

    return;
  }


  // ---------------------------------------------------------------
  // DEFAULT NAVIGATION
  // ---------------------------------------------------------------

  if (
      ev ==
      BTN_SINGLE_CLICK
  ) {

    display::nextScreen();

  }

  else if (
      ev ==
      BTN_DOUBLE_CLICK
  ) {

    display::goHome();
  }


  display::requestRedraw();
}


// =================================================================
// SETUP
// =================================================================

void setup() {

  Serial.begin(
      115200
  );

  delay(200);


  // RGB LED outputs
  pinMode(PIN_RGB_RED, OUTPUT);
  pinMode(PIN_RGB_GREEN, OUTPUT);
  pinMode(PIN_RGB_BLUE, OUTPUT);

  setStatusLed(false, false, false);


  Wire.begin(
      PIN_I2C_SDA,
      PIN_I2C_SCL
  );

  Wire.setClock(
      400000
  );


  storage::begin();
  healthHistory::begin();

  settings::begin();

  button::begin();

  alerts::begin();

  battery::begin();

  timeManager::begin();
  wifiManager::begin();


  hwOledOk =
      display::begin();

  hwMaxOk =
      hrSensor::begin();

  // Keep MAX30102 OFF until the user enters the HR screen.

  hrSensor::powerOff();

  hrSensorPowered =
      false;


  hwMpuOk =
      motionSensor::begin();


  posture::begin();

  activity::begin();

  wellness::begin();

  healthTimer::begin();

  reminders::begin();

  alarms::begin();


  printDiagnosticsSerial();


  // Startup splash

  display::setScreen(
      SCR_STARTUP
  );

  display::render();

  // Boot animation completes inside drawStartup()
  display::goHome();

  bleBegin();
}


// =================================================================
// POSTURE ALERT STATE MACHINE UPDATE
// =================================================================
static void updatePostureAlert() {
  bool hasBase = posture::hasBaseline();
  bool isCalib = posture::isCalibrating();
  bool isBad = hasBase && !isCalib && !posture::isGood();
  unsigned long now = millis();

  if (isBad) {
    if (badPostureStartMs == 0) {
      badPostureStartMs = now;
    }

    unsigned long badDuration = now - badPostureStartMs;

    if (postureSnoozed) {
      // Button was pressed to stop: if position stays bad, beep again after 30 sec!
      if (now - postureSnoozeStartMs >= 30000UL) {
        postureSnoozed = false;
        postureAlertActive = true;
        postureBeepingActive = true;
        lastPostureBeepMs = 0;
      }
    } else {
      // 1. Position stays bad for 30 sec -> light glows and alert on screen
      if (badDuration >= 30000UL) {
        postureAlertActive = true;
      }
      // 2. After 1 min (60 sec) -> starts beeping
      if (badDuration >= 60000UL) {
        postureBeepingActive = true;
      }
    }
  } else {
    // Position fixed -> stop and reset everything completely
    if (badPostureStartMs != 0 || postureAlertActive || postureBeepingActive || postureSnoozed) {
      badPostureStartMs = 0;
      postureAlertActive = false;
      postureBeepingActive = false;
      postureSnoozed = false;
      postureSnoozeStartMs = 0;
      lastPostureBeepMs = 0;
      alerts::buzzerStop();

      if (display::getCurrentScreen() == SCR_ALERT_POSTURE) {
        display::setScreen(screenBeforePostureAlert);
      }
    }
  }

  // Manage screen overlay
  DeviceScreen current = display::getCurrentScreen();
  if (postureAlertActive && !postureSnoozed && !alarms::isRinging()) {
    if (current != SCR_ALERT_POSTURE &&
        current != SCR_ALERT_ALARM &&
        current != SCR_ALERT_FALL &&
        current != SCR_STARTUP) {
      screenBeforePostureAlert = current;
      display::setScreen(SCR_ALERT_POSTURE);
      display::wake();
    }
  } else {
    if (current == SCR_ALERT_POSTURE) {
      display::setScreen(screenBeforePostureAlert);
    }
  }

  // Manage beeping (alerts sound pattern if enabled)
  if (postureBeepingActive && !postureSnoozed && !alarms::isRinging()) {
    if (settings::getSoundEnabled() && settings::getSoundVolume() > 0) {
      if (now - lastPostureBeepMs >= 1500UL) {
        lastPostureBeepMs = now;
        alerts::beepPattern(2, 120, 100);
      }
    }
  }
}

// =================================================================
// LOOP
// =================================================================

void loop() {

bleUpdate();
  unsigned long now =
      millis();


  // ---------------------------------------------------------------
  // BUTTON
  // ---------------------------------------------------------------

  ButtonEvent ev =
      button::update();

  if (
      ev != BTN_NONE
  ) {

    handleButtonEvent(
        ev
    );

    // Any normal button interaction resets the display timeout.
    // A low-power hold intentionally does not count as activity.
    if (ev != BTN_LOW_POWER_HOLD) {
      display::noteActivity();
    }
  }

  display::updateTimeout();


  // ---------------------------------------------------------------
  // TIME
  // ---------------------------------------------------------------

  timeManager::update();
  wifiManager::update();
  { static bool _lastWifiConn = false;
    bool _nowConn = wifiManager::isConnected();
    if (_nowConn && !_lastWifiConn) { wifiManager::flushOfflineQueue(); }
    _lastWifiConn = _nowConn; }


  // ---------------------------------------------------------------
  // HEART-RATE SENSOR POWER
  // ---------------------------------------------------------------

  updateHRSensorPower();


  // ---------------------------------------------------------------
  // SENSORS
  // ---------------------------------------------------------------

  if (
      hrSensorPowered
  ) {

    hrSensor::update();
  }

  motionSensor::update();

  posture::update();

  if (
      posture::calibrationJustFinished() &&
      display::getCurrentScreen() == SCR_POSTURE_CALIBRATING
  ) {
    display::setScreen(SCR_POSTURE);
  }

  updatePostureAlert();

  activity::update();

  if (hrSensor::hasResult()) {
    if (!hrResultHandled) {
      int bpm = hrSensor::getResultBPM();
      wellness::onHeartRateResult(bpm);
      healthHistory::addHeartRate(bpm);
      uint32_t ts = (uint32_t)time(nullptr);
      wifiManager::pushReading("hr", bpm, ts);

      if (hrSensor::isSpO2Valid()) {
        int spo2 = hrSensor::getSpO2();
        if (spo2 >= 70 && spo2 <= 100) {
          healthHistory::addSpO2(spo2);
          wifiManager::pushReading("spo2", spo2, ts);
        }
      }
      hrResultHandled = true;
    }
  }
  else {
    hrResultHandled = false;
  }

  // SpO2 in Live Vitals mode or whenever valid SpO2 reading is detected
  if (hrSensor::isSpO2Valid()) {
    static int lastRecordedSpO2 = 0;
    static unsigned long lastSpO2PushMs = 0;
    int spo2 = hrSensor::getSpO2();
    if (spo2 >= 70 && spo2 <= 100) {
      unsigned long nowMs = millis();
      if ((spo2 != lastRecordedSpO2 && (nowMs - lastSpO2PushMs >= 15000UL)) ||
          (nowMs - lastSpO2PushMs >= 60000UL)) {
        lastRecordedSpO2 = spo2;
        lastSpO2PushMs = nowMs;
        healthHistory::addSpO2(spo2);
        uint32_t ts = (uint32_t)time(nullptr);
        wifiManager::pushReading("spo2", spo2, ts);
      }
    }
  }

  // Footsteps sync to Supabase cloud
  {
    static unsigned long lastPushedSteps = 0;
    static unsigned long lastStepsPushMs = 0;
    unsigned long currentSteps = wellness::getDailySteps();
    if (currentSteps == 0) {
      currentSteps = activity::getSteps();
    }
    if (currentSteps > 0 && currentSteps != lastPushedSteps) {
      unsigned long nowMs = millis();
      unsigned long stepDelta = (currentSteps > lastPushedSteps) ? (currentSteps - lastPushedSteps) : 0;
      if ((stepDelta >= 25 && (nowMs - lastStepsPushMs >= 15000UL)) ||
          (nowMs - lastStepsPushMs >= 60000UL) ||
          (lastPushedSteps == 0 && (nowMs - lastStepsPushMs >= 10000UL))) {
        lastPushedSteps = currentSteps;
        lastStepsPushMs = nowMs;
        uint32_t ts = (uint32_t)time(nullptr);
        wifiManager::pushReading("steps", (int)currentSteps, ts);
      }
    }
  }

  wellness::update();


  // ---------------------------------------------------------------
  // FALL DETECTION OVERLAY
  // ---------------------------------------------------------------

  DeviceScreen afterWellnessScreen =
      display::getCurrentScreen();

  if (
      wellness::fallDetected() &&
      !fallOverlayActive &&
      afterWellnessScreen != SCR_ALERT_FALL
  ) {

    screenBeforeFall =
        afterWellnessScreen;

    fallOverlayActive =
        true;

    display::setScreen(
        SCR_ALERT_FALL
    );
  }

  else if (
      fallOverlayActive &&
      !wellness::fallDetected() &&
      afterWellnessScreen == SCR_ALERT_FALL
  ) {

    fallOverlayActive =
        false;

    display::setScreen(
        screenBeforeFall
    );
  }


  // ---------------------------------------------------------------
  // TIMER / REMINDERS / ALARMS
  // ---------------------------------------------------------------

  healthTimer::update();

  // The timer value is time-based, so keep the Timer screen
  // refreshing while the countdown is running.
  // display::render() is still rate-limited internally.
  if (
      healthTimer::isRunning() &&
      display::getCurrentScreen() == SCR_CLOCK &&
      display::getClockMode() == 1
  ) {

    display::requestRedraw();
  }

  // Keep both schedulers running. DND is enforced by alert arbitration,
  // while alarms remain fully active even when DND is enabled.
  reminders::update();
  alarms::update();


  // ---------------------------------------------------------------
  // BATTERY
  // ---------------------------------------------------------------

  if (
      now - lastBatteryUpdate >=
      BATTERY_UPDATE_INTERVAL_MS
  ) {

    lastBatteryUpdate =
        now;

    battery::update();

    // Every screen uses the shared battery icon/header, so a battery
    // update must refresh whichever screen is currently visible.
    display::requestRedraw();
  }


  // ---------------------------------------------------------------
  // ALERTS / BUZZER
  // ---------------------------------------------------------------

  // Keep the non-blocking buzzer state machine running.
  // This is required for beepPattern() to finish and turn the
  // buzzer OFF after the requested number of beeps.
  alerts::update();

  updateAlertArbitration();


  // ---------------------------------------------------------------
  // RGB STATUS LED
  // ---------------------------------------------------------------

  updateStatusLed();


  // ---------------------------------------------------------------
  // DISPLAY
  // ---------------------------------------------------------------

  display::render();


  delay(1);
}