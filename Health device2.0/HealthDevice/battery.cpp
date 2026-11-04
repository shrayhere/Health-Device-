#include "battery.h"
#include "config.h"

// Battery voltage divider
// Default: 100k / 100k divider -> factor 2.0
static const float DIVIDER_FACTOR = 2.0f;

// ESP32 ADC reference
static const float ADC_REF_V = 3.3f;
static const int ADC_MAX = 4095;

static float lastVoltage = 3.7f;
static int lastPercent = 50;

namespace battery {

void begin() {

  pinMode(
      PIN_BATTERY_ADC,
      INPUT
  );

  update();
}


void update() {

  int raw =
      analogRead(
          PIN_BATTERY_ADC
      );

  float vAtPin =
      (raw / (float)ADC_MAX) *
      ADC_REF_V;

  lastVoltage =
      vAtPin *
      DIVIDER_FACTOR;


  float pct =
      (lastVoltage - BATT_V_EMPTY) /
      (BATT_V_FULL - BATT_V_EMPTY) *
      100.0f;


  if (pct < 0)
    pct = 0;

  if (pct > 100)
    pct = 100;


  lastPercent =
      (int)(pct + 0.5f);
}


float getVoltage() {

  return lastVoltage;
}


int getPercent() {

  return lastPercent;
}


const char* getStatusText() {

  if (lastPercent <= 10)
    return "CRITICAL";

  if (lastPercent <= 25)
    return "LOW";

  return "GOOD";
}


bool isCritical() {

  return lastPercent <= 10;
}

} // namespace battery