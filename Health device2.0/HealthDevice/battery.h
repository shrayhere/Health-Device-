#ifndef BATTERY_H
#define BATTERY_H

#include <Arduino.h>

namespace battery {
  void begin();
  void update();              // call periodically (e.g. every 2s) from loop
  float getVoltage();         // last measured voltage
  int   getPercent();         // 0-100
  const char* getStatusText();// "GOOD" / "LOW" / "CRITICAL"
  bool  isCritical();         // true when percent very low
}

#endif // BATTERY_H
