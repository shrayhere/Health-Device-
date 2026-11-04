#include "timer.h"

static unsigned long durationSec = 25 * 60;
static unsigned long remainingSec = durationSec;

static bool running = false;
static bool finished = false;

static unsigned long lastTickMs = 0;


namespace healthTimer {


void begin() {

  remainingSec =
      durationSec;

  running =
      false;

  finished =
      false;

  lastTickMs =
      millis();
}


void setDurationSeconds(
    unsigned long seconds
) {

  // ------------------------------------------------------------
  // Safety limits
  // Minimum: 1 second
  // Maximum: 24 hours
  // ------------------------------------------------------------

  if (
      seconds < 1
  ) {

    seconds =
        1;
  }

  const unsigned long MAX_SECONDS =
      24UL * 60UL * 60UL;

  if (
      seconds > MAX_SECONDS
  ) {

    seconds =
        MAX_SECONDS;
  }


  durationSec =
      seconds;


  // Only change the visible remaining time
  // when the timer isn't currently running.

  if (
      !running
  ) {

    remainingSec =
        durationSec;
  }
}


unsigned long getDurationSeconds() {

  return durationSec;
}


void start() {

  // If timer has reached zero,
  // start a fresh countdown.

  if (
      remainingSec == 0
  ) {

    remainingSec =
        durationSec;
  }


  // Never allow an empty timer to start.

  if (
      remainingSec == 0
  ) {

    remainingSec =
        1;
  }


  running =
      true;

  finished =
      false;

  lastTickMs =
      millis();
}


void pause() {

  running =
      false;
}


void reset() {

  running =
      false;

  finished =
      false;

  remainingSec =
      durationSec;

  lastTickMs =
      millis();
}


bool isRunning() {

  return running;
}


bool isFinished() {

  return finished;
}


void acknowledgeFinish() {

  finished =
      false;

  running =
      false;

  remainingSec =
      durationSec;

  lastTickMs =
      millis();
}


unsigned long getRemainingSeconds() {

  return remainingSec;
}


void update() {

  if (
      !running
  ) {

    return;
  }


  unsigned long now =
      millis();


  if (
      now - lastTickMs <
      1000
  ) {

    return;
  }


  unsigned long ticks =
      (
          now - lastTickMs
      ) / 1000;


  lastTickMs +=
      ticks * 1000;


  // Timer has finished.

  if (
      ticks >= remainingSec
  ) {

    remainingSec =
        0;

    running =
        false;

    finished =
        true;

    return;
  }


  remainingSec -=
      ticks;
}


} // namespace healthTimer