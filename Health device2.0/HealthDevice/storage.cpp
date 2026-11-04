#include "storage.h"
#include <Preferences.h>
#include "config.h"

static Preferences prefs;

// Namespaces kept short (Preferences limits namespace length)
#define NS_HISTORY   "hr_hist"
#define NS_POSTURE   "posture"
#define NS_SETTINGS  "settings"

namespace storage {

void begin() {
  // Nothing persistent to open at boot; each function opens/closes
  // its own namespace so we don't hold flash open across the app.
}

// ---------------- HR HISTORY ----------------
// Stored as a ring buffer: hr_hist has "count" and hr_0..hr_9 (bpm|time)

void addHRRecord(int bpm, uint32_t epochTime) {
  prefs.begin(NS_HISTORY, false);
  int count = prefs.getInt("count", 0);

  // Shift everything down by one (newest goes to index 0)
  int maxN = HR_HISTORY_MAX;
  int bpmArr[HR_HISTORY_MAX];
  uint32_t tArr[HR_HISTORY_MAX];

  int existing = min(count, maxN);
  for (int i = 0; i < existing; i++) {
    char kb[12], kt[12];
    snprintf(kb, sizeof(kb), "b%d", i);
    snprintf(kt, sizeof(kt), "t%d", i);
    bpmArr[i] = prefs.getInt(kb, 0);
    tArr[i]   = prefs.getUInt(kt, 0);
  }

  int newCount = min(existing + 1, maxN);
  // shift
  for (int i = newCount - 1; i > 0; i--) {
    bpmArr[i] = bpmArr[i - 1];
    tArr[i]   = tArr[i - 1];
  }
  bpmArr[0] = bpm;
  tArr[0]   = epochTime;

  for (int i = 0; i < newCount; i++) {
    char kb[12], kt[12];
    snprintf(kb, sizeof(kb), "b%d", i);
    snprintf(kt, sizeof(kt), "t%d", i);
    prefs.putInt(kb, bpmArr[i]);
    prefs.putUInt(kt, tArr[i]);
  }
  prefs.putInt("count", newCount);
  prefs.end();
}

int getHRHistory(HRRecord out[], int maxCount) {
  prefs.begin(NS_HISTORY, true);
  int count = prefs.getInt("count", 0);
  int n = min(count, maxCount);
  for (int i = 0; i < n; i++) {
    char kb[12], kt[12];
    snprintf(kb, sizeof(kb), "b%d", i);
    snprintf(kt, sizeof(kt), "t%d", i);
    out[i].bpm = prefs.getInt(kb, 0);
    out[i].epochTime = prefs.getUInt(kt, 0);
  }
  prefs.end();
  return n;
}

// ---------------- POSTURE BASELINE ----------------

void savePostureBaseline(float pitch, float roll) {
  prefs.begin(NS_POSTURE, false);
  prefs.putFloat("pitch", pitch);
  prefs.putFloat("roll", roll);
  prefs.putBool("set", true);
  prefs.end();
}

bool loadPostureBaseline(float &pitch, float &roll) {
  prefs.begin(NS_POSTURE, true);
  bool set = prefs.getBool("set", false);
  if (set) {
    pitch = prefs.getFloat("pitch", 0);
    roll  = prefs.getFloat("roll", 0);
  }
  prefs.end();
  return set;
}

void clearPostureBaseline() {
  prefs.begin(NS_POSTURE, false);
  prefs.putBool("set", false);
  prefs.end();
}

// ---------------- GENERIC SETTINGS ----------------

void saveBool(const char* key, bool value) {
  prefs.begin(NS_SETTINGS, false);
  prefs.putBool(key, value);
  prefs.end();
}

bool loadBool(const char* key, bool defaultValue) {
  prefs.begin(NS_SETTINGS, true);
  bool v = prefs.getBool(key, defaultValue);
  prefs.end();
  return v;
}

void saveInt(const char* key, int value) {
  prefs.begin(NS_SETTINGS, false);
  prefs.putInt(key, value);
  prefs.end();
}

int loadInt(const char* key, int defaultValue) {
  prefs.begin(NS_SETTINGS, true);
  int v = prefs.getInt(key, defaultValue);
  prefs.end();
  return v;
}

void saveFloat(const char* key, float value) {
  prefs.begin(NS_SETTINGS, false);
  prefs.putFloat(key, value);
  prefs.end();
}

float loadFloat(const char* key, float defaultValue) {
  prefs.begin(NS_SETTINGS, true);
  float v = prefs.getFloat(key, defaultValue);
  prefs.end();
  return v;
}

void saveString(const char* key, const String &value) {
  prefs.begin(NS_SETTINGS, false);
  prefs.putString(key, value);
  prefs.end();
}

String loadString(const char* key, const String &defaultValue) {
  prefs.begin(NS_SETTINGS, true);
  String v = prefs.getString(key, defaultValue);
  prefs.end();
  return v;
}

void resetAll() {
  prefs.begin(NS_HISTORY, false);  prefs.clear(); prefs.end();
  prefs.begin(NS_POSTURE, false);  prefs.clear(); prefs.end();
  prefs.begin(NS_SETTINGS, false); prefs.clear(); prefs.end();
}

} // namespace storage
