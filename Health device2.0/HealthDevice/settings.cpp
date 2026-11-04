#include "settings.h"
#include "storage.h"
#include "config.h"

static int brightness = 100;
static int screenTimeoutSec = SCREEN_TIMEOUT_DEFAULT_MS / 1000;
static bool soundEnabled = true;
static int soundVolume = 70;
static bool clickSoundEnabled = true;
static bool measurementSoundEnabled = true;
static bool use24Hour = true;
static int displayOrientation = 0;
static bool ledHigh = true;

namespace settings {

void begin() {
  brightness = storage::loadInt("disp_bright", 100);
  screenTimeoutSec = storage::loadInt("disp_timeout", 0);
  soundEnabled = storage::loadBool("sound_on", true);
  soundVolume = storage::loadInt("sound_vol", 70);
  soundVolume = constrain(soundVolume, 0, 100);
  clickSoundEnabled = storage::loadBool("click_sound", true);
  measurementSoundEnabled = storage::loadBool("measure_sound", true);
  use24Hour = storage::loadBool("clock_24h", true);
  displayOrientation = storage::loadInt("disp_rot", 0);
  ledHigh = storage::loadBool("led_high", true);
  if (displayOrientation != 0 && displayOrientation != 2) displayOrientation = 0;
}

int getBrightness() { return brightness; }
void setBrightness(int pct) {
  brightness = constrain(pct, 0, 100);
  storage::saveInt("disp_bright", brightness);
}

int getScreenTimeoutSec() { return screenTimeoutSec; }
void setScreenTimeoutSec(int sec) {
  screenTimeoutSec = constrain(sec, 0, 3600);
  storage::saveInt("disp_timeout", screenTimeoutSec);
}

int getOrientation() { return displayOrientation; }
void setOrientation(int rotation) {
  displayOrientation = (rotation == 2) ? 2 : 0;
  storage::saveInt("disp_rot", displayOrientation);
}

bool getLedHigh() { return ledHigh; }
void setLedHigh(bool high) {
  ledHigh = high;
  storage::saveBool("led_high", high);
}

bool getSoundEnabled() { return soundEnabled; }
void setSoundEnabled(bool enabled) {
  soundEnabled = enabled;
  storage::saveBool("sound_on", enabled);
}

int getSoundVolume() { return soundVolume; }
void setSoundVolume(int pct) {
  soundVolume = constrain(pct, 0, 100);
  storage::saveInt("sound_vol", soundVolume);
}

bool getClickSoundEnabled() { return clickSoundEnabled; }
void setClickSoundEnabled(bool enabled) {
  clickSoundEnabled = enabled;
  storage::saveBool("click_sound", enabled);
}

bool getMeasurementSoundEnabled() { return measurementSoundEnabled; }
void setMeasurementSoundEnabled(bool enabled) {
  measurementSoundEnabled = enabled;
  storage::saveBool("measure_sound", enabled);
}

bool getUse24Hour() { return use24Hour; }
void setUse24Hour(bool use24h) {
  use24Hour = use24h;
  storage::saveBool("clock_24h", use24h);
}

} // namespace settings
