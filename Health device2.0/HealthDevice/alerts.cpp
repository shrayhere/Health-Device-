#include "alerts.h"
#include "config.h"
#include "settings.h"

static bool activeFlags[6] = {false,false,false,false,false,false}; // indexed by AlertPriority

// ---- non-blocking beep pattern state ----
static bool patternActive = false;
static int  patternCount = 0;
static int  patternOnMs = 0;
static int  patternOffMs = 0;
static int  patternStep = 0;
static unsigned long patternLastChange = 0;
static bool patternOn = false;

static bool continuousBuzz = false;

static void buzzerOutput(bool on) {
  if (!on || !settings::getSoundEnabled() || settings::getSoundVolume() <= 0) {
    analogWrite(PIN_BUZZER, 0);
    return;
  }

  int duty = map(settings::getSoundVolume(), 0, 100, 0, 255);
  analogWrite(PIN_BUZZER, duty);
}

namespace alerts {


static unsigned long overrideUntilMs = 0;

void overrideRGB(int r, int g, int b, unsigned long durationMs) {
  overrideUntilMs = millis() + durationMs;
  pinMode(PIN_RGB_RED, OUTPUT);
  pinMode(PIN_RGB_GREEN, OUTPUT);
  pinMode(PIN_RGB_BLUE, OUTPUT);
  analogWrite(PIN_RGB_RED, constrain(r, 0, 255));
  analogWrite(PIN_RGB_GREEN, constrain(g, 0, 255));
  analogWrite(PIN_RGB_BLUE, constrain(b, 0, 255));
}

bool isRGBOverridden() {
  if (overrideUntilMs == 0) return false;
  if (millis() >= overrideUntilMs) {
    overrideUntilMs = 0;
    analogWrite(PIN_RGB_RED, 0);
    analogWrite(PIN_RGB_GREEN, 0);
    analogWrite(PIN_RGB_BLUE, 0);
    return false;
  }
  return true;
}

void begin() {
  pinMode(PIN_RGB_RED, OUTPUT);
  pinMode(PIN_RGB_GREEN, OUTPUT);
  pinMode(PIN_RGB_BLUE, OUTPUT);
  pinMode(PIN_BUZZER, OUTPUT);
  setRGB(RGB_OFF);
  buzzerOutput(false);
}

void setRGB(RGBColor color) {
  bool r=false, g=false, b=false;
  switch (color) {
    case RGB_GREEN:  g = true; break;
    case RGB_RED:    r = true; break;
    case RGB_BLUE:   b = true; break;
    case RGB_YELLOW: r = true; g = true; break;
    case RGB_OFF:
    default: break;
  }
  digitalWrite(PIN_RGB_RED, r ? HIGH : LOW);
  digitalWrite(PIN_RGB_GREEN, g ? HIGH : LOW);
  digitalWrite(PIN_RGB_BLUE, b ? HIGH : LOW);
}

void beepPattern(int count, int onMs, int offMs) {
  if (!settings::getSoundEnabled() || settings::getSoundVolume() <= 0 || count <= 0) {
    buzzerOutput(false);
    patternActive = false;
    continuousBuzz = false;
    return;
  }

  patternActive = true;
  patternCount = count;
  patternOnMs = onMs;
  patternOffMs = offMs;
  patternStep = 0;
  patternOn = true;
  patternLastChange = millis();
  buzzerOutput(true);
}

void beepShort() {
  beepPattern(1, 120, 0);
}

void beepLong() {
  beepPattern(3, 250, 150);
}

void buzzerContinuousStart() {
  if (!settings::getSoundEnabled() || settings::getSoundVolume() <= 0) {
    buzzerStop();
    return;
  }

  continuousBuzz = true;
  patternActive = false;
  buzzerOutput(true);
}

void buzzerStop() {
  continuousBuzz = false;
  patternActive = false;
  buzzerOutput(false);
}

void update() {
  if (continuousBuzz) return; // stays on until buzzerStop()
  if (!patternActive) return;

  unsigned long now = millis();
  unsigned long elapsed = now - patternLastChange;

  if (patternOn) {
    if (elapsed >= (unsigned long)patternOnMs) {
      buzzerOutput(false);
      patternOn = false;
      patternLastChange = now;
      patternStep++;
      if (patternStep >= patternCount) {
        patternActive = false;
      }
    }
  } else {
    if (elapsed >= (unsigned long)patternOffMs) {
      if (patternStep < patternCount) {
        buzzerOutput(true);
        patternOn = true;
        patternLastChange = now;
      } else {
        patternActive = false;
      }
    }
  }
}

void raise(AlertPriority p) {
  if (p == ALERT_NONE) return;
  activeFlags[p] = true;
}

void clear(AlertPriority p) {
  if (p == ALERT_NONE) return;
  activeFlags[p] = false;
}

AlertPriority getActive() {
  for (int p = 1; p <= 5; p++) {
    if (activeFlags[p]) return (AlertPriority)p;
  }
  return ALERT_NONE;
}

} // namespace alerts
