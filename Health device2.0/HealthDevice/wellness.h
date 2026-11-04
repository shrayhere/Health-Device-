#ifndef WELLNESS_H
#define WELLNESS_H

#include <Arduino.h>

namespace wellness {

  void begin();
  void update();

  // Heart-rate alert state. 0=off, 1=green, 2=red, 3=blue.
  void onHeartRateResult(int bpm);
  int getHRAlertColor();

  // Water tracking/reminder.
  void addWater(int cups = 1);
  int getWaterCups();
  int getWaterGoal();
  void setWaterGoal(int cups);
  bool waterReminderPending();
  void dismissWaterReminder();
  unsigned long minutesSinceWater();

  // Daily wellness tracking.
  unsigned long getDailySteps();
  unsigned long getDailyActiveMinutes();
  int getActivityScore();
  bool allDailyGoalsMet();

  // Automatic inactivity detector.
  bool isInactive();
  unsigned long getInactiveMinutes();
  bool exerciseReminderPending();
  void dismissExerciseReminder();

  // Fall detector.
  bool fallDetected();
  void dismissFallAlert();

  // Breathing exercise.
  void toggleBreathing();
  bool isBreathing();
  const char* getBreathingPhase();
  int getBreathingPhasePercent();

  // Do Not Disturb.
  bool isDnd();
  void toggleDnd();
  void setDnd(bool enabled);

  // Goals / streaks / achievements.
  int getStreak();
  uint32_t getAchievementsMask();
  int getAchievementCount();
}

#endif // WELLNESS_H
