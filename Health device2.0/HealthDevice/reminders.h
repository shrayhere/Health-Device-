#ifndef REMINDERS_H
#define REMINDERS_H

#include <Arduino.h>

#define MAX_REMINDERS 8

struct Reminder {
  bool used;
  char name[16];
  int hour;
  int minute;
  bool repeatDaily; // v1 supports daily or one-off; extend to weekday masks later
  bool enabled;
};

namespace reminders {
  void begin();
  void update(); // call every loop() — fires alerts when time matches

  int  count();
  const Reminder& get(int index);
  bool add(const char* name, int hour, int minute, bool repeatDaily);
  void remove(int index);
  void setEnabled(int index, bool enabled);

  bool hasPendingAlert();
  const Reminder& getPendingAlert();
  void dismissAlert();
}

#endif // REMINDERS_H
