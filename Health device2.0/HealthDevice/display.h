#ifndef DISPLAY_H
#define DISPLAY_H

#include <Arduino.h>


// ============================================================
// DEVICE SCREENS
// ============================================================

enum DeviceScreen {

  SCR_STARTUP,

  SCR_HOME,

  SCR_MENU,

  SCR_HEART_RATE,

  SCR_POSTURE,

  SCR_POSTURE_SETUP,

  SCR_POSTURE_CALIBRATING,

  SCR_ACTIVITY,

  SCR_WELLNESS,
  SCR_BREATHING,
  SCR_GOALS,

  // Main CLOCK section
  SCR_CLOCK,

  SCR_HR_HISTORY,
  SCR_SPO2_HISTORY,

  SCR_BATTERY,

  SCR_REMINDERS,

  SCR_SETTINGS,

  SCR_ALARM_LIST,

  SCR_ALARM_SETUP,

  SCR_SETTINGS_WIFI,

  SCR_SETTINGS_POSTURE,

  SCR_SETTINGS_DISPLAY,

  SCR_SETTINGS_SOUND,

  SCR_SETTINGS_SYSTEM,

  SCR_DIAGNOSTICS,

  SCR_ABOUT_SYSTEM,

  // Alert overlays
  SCR_ALERT_ALARM,

  SCR_ALERT_REMINDER,

  SCR_ALERT_TIMER_DONE,

  SCR_ALERT_FALL,

  SCR_ALERT_POSTURE,

  SCR_LOW_POWER,

  SCR_COUNT
};


// ============================================================
// DISPLAY API
// ============================================================

namespace display {

  bool begin();

  void goHome();

  void setScreen(
      DeviceScreen screen
  );

  DeviceScreen getCurrentScreen();

  void nextScreen();

  // ==========================================================
  // MAIN MENU
  // ==========================================================

  void startMenuSelection();
  void nextMenuItem();
  void activateMenuItem();
  void resetMenuSelection();

  void startSettingsSelection();
  void nextSettingsItem();
  void activateSettingsItem();
  void resetSettingsSelection();

  // ==========================================================
  // WI-FI SETTINGS
  // ==========================================================

  void startWiFiSelection();
  void nextWiFiItem();
  int getWiFiSelection();
  void resetWiFiSelection();

  // ==========================================================
  // ALARM LIST
  // ==========================================================

  void startAlarmListSelection();
  void nextAlarmListItem();
  int getAlarmListSelection();
  bool isAlarmListSelectionActive();
  void resetAlarmListSelection();

  void openAlarmSetup(int index);
  void nextAlarmSetupItem();
  void activateAlarmSetupItem();
  void alarmSetupSingleAction();
  void alarmSetupDoubleAction();
  void alarmSetupTripleAction();

  // ==========================================================
  // REMINDER ON/OFF MENU
  // ==========================================================

  void startReminderSelection();

  void nextReminderItem();

  void toggleSelectedReminder();

  bool isReminderSelectionActive();

  void resetReminderSelection();

  // Heart-rate screen modes
  void setHeartRateSpO2Mode(bool enabled);
  bool isHeartRateSpO2Mode();

  // Health history
  void startHealthHistory();
  void nextHealthHistoryItem();
  void resetHealthHistory();


  // ==========================================================
  // CLOCK SECTION
  // ==========================================================

  void nextClockMode();

  int getClockMode();

  void toggleStopwatch();

  void resetStopwatch();


  // ==========================================================
  // TIMER EDIT DISPLAY STATE
  // ==========================================================

  void setTimerEditState(
      bool active,
      unsigned int hours,
      unsigned int minutes,
      unsigned int seconds,
      int field,
      int action
  );


  // ==========================================================
  // POWER / RENDER
  // ==========================================================

  bool isAsleep();

  void sleep();

  void wake();

  // Display settings
  void startDisplaySettings();
  void displaySettingsSingleAction();
  void displaySettingsDoubleAction();
  void displaySettingsTripleAction();
  void displaySettingsHoldRepeat();
  int getDisplaySettingsSelection();
  bool isDisplaySettingsEditMode();

  // Sound settings
  void startSoundSettings();
  void soundSettingsSingleAction();
  void soundSettingsHoldRepeat();
  void soundSettingsDoubleAction();
  void soundSettingsTripleAction();
  int getSoundSettingsSelection();
  bool isSoundSettingsEditMode();

  // System settings
  void startSystemSelection();
  void nextSystemItem();
  void activateSystemItem();
  void resetSystemSelection();

  // Automatic screen timeout
  void noteActivity();
  void updateTimeout();

  void requestRedraw();
  void setOrientation(int rot);

  void render();
}

#endif