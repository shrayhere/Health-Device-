#ifndef TIMER_H
#define TIMER_H

#include <Arduino.h>

namespace healthTimer {

  void begin();
  void update();

  void setDurationSeconds(unsigned long seconds);
  unsigned long getDurationSeconds();

  void start();
  void pause();
  void reset();

  bool isRunning();
  bool isFinished();
  void acknowledgeFinish();

  unsigned long getRemainingSeconds();

}

#endif // TIMER_H