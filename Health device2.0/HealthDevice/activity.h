#ifndef ACTIVITY_H
#define ACTIVITY_H

#include <Arduino.h>

namespace activity {
  void begin();
  void update();

  unsigned long getSteps();
  float getDistanceKm();
  unsigned long getActiveMinutes();
  unsigned long getCalories();

  void resetToday();
}

#endif // ACTIVITY_H
