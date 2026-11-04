#ifndef ALERTS_H
#define ALERTS_H

#include <Arduino.h>

// RGB colors
enum RGBColor { RGB_OFF, RGB_GREEN, RGB_RED, RGB_BLUE, RGB_YELLOW };

// Alert priority (lower number = higher priority), per spec section 33
enum AlertPriority {
  ALERT_NONE = 0,
  ALERT_ALARM = 1,
  ALERT_CRITICAL = 2,
  ALERT_TIMER = 3,
  ALERT_REMINDER = 4,
  ALERT_POSTURE = 5
};

namespace alerts {
  void begin();
  void update(); // call every loop() — handles non-blocking buzzer patterns

  void setRGB(RGBColor color);
  void overrideRGB(int r, int g, int b, unsigned long durationMs = 3000);
  bool isRGBOverridden();

  // Non-blocking beep patterns
  void beepShort();          // normal HR result / posture calibrated
  void beepLong();           // high HR warning
  void beepPattern(int count, int onMs, int offMs); // generic
  void buzzerContinuousStart(); // alarms: keep buzzing until stopped
  void buzzerStop();

  // Alert stack (priority arbitration for which screen takes over)
  void raise(AlertPriority p);
  void clear(AlertPriority p);
  AlertPriority getActive(); // highest-priority currently active alert
}

#endif // ALERTS_H
