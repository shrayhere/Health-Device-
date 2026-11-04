#ifndef SETTINGS_H
#define SETTINGS_H

#include <Arduino.h>

namespace settings {
  void begin();
  int  getBrightness();
  void setBrightness(int pct);
  int  getScreenTimeoutSec();
  void setScreenTimeoutSec(int sec);
  int  getOrientation();
  void setOrientation(int rotation);
  bool getLedHigh();
  void setLedHigh(bool high);
  bool getSoundEnabled();
  void setSoundEnabled(bool enabled);
  int  getSoundVolume();
  void setSoundVolume(int pct);
  bool getClickSoundEnabled();
  void setClickSoundEnabled(bool enabled);
  bool getMeasurementSoundEnabled();
  void setMeasurementSoundEnabled(bool enabled);
  bool getUse24Hour();
  void setUse24Hour(bool use24h);
}

#endif // SETTINGS_H
