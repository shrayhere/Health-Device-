#include "activity.h"
#include "sensors.h"

// Rough conversion, tune once step algorithm is validated against real walking.
static const float STRIDE_METERS = 0.70f;

static unsigned long lastStepBaseline = 0;
static unsigned long lastMovementMs = 0;
static unsigned long activeMs = 0;
static unsigned long lastStepSeenCount = 0;

// Approximate walking energy estimate. This is intentionally labeled
// as an estimate because calories depend on body mass, pace and terrain.
static const float KCAL_PER_STEP = 0.04f;

namespace activity {

void begin() {
  lastStepBaseline = motionSensor::getStepCount();
  lastMovementMs = millis();
}

void update() {
  unsigned long steps = motionSensor::getStepCount();
  if (steps != lastStepSeenCount) {
    unsigned long now = millis();
    // count active time in chunks while steps are actively increasing
    if (now - lastMovementMs < 60000) {
      activeMs += (now - lastMovementMs);
    }
    lastMovementMs = now;
    lastStepSeenCount = steps;
  }
}

unsigned long getSteps() {
  return motionSensor::getStepCount() - lastStepBaseline;
}

float getDistanceKm() {
  return (getSteps() * STRIDE_METERS) / 1000.0f;
}

unsigned long getActiveMinutes() {
  return activeMs / 60000UL;
}

unsigned long getCalories() {
  return (unsigned long)(getSteps() * KCAL_PER_STEP + 0.5f);
}

void resetToday() {
  lastStepBaseline = motionSensor::getStepCount();
  activeMs = 0;
}

} // namespace activity
