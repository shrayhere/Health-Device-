#ifndef STORAGE_H
#define STORAGE_H

#include <Arduino.h>

// Persistent storage wrapper (ESP32 Preferences).
// Every other module calls into this rather than touching
// Preferences directly, so keys stay in one place.

struct HRRecord {
  int bpm;
  uint32_t epochTime; // seconds, may be 0 if clock not set
};

namespace storage {

  void begin();

  // ---- HR history ----
  void addHRRecord(int bpm, uint32_t epochTime);
  int  getHRHistory(HRRecord out[], int maxCount); // returns count, newest first

  // ---- Posture baseline ----
  void savePostureBaseline(float pitch, float roll);
  bool loadPostureBaseline(float &pitch, float &roll);
  void clearPostureBaseline();

  // ---- Generic settings ----
  void saveBool(const char* key, bool value);
  bool loadBool(const char* key, bool defaultValue);

  void saveInt(const char* key, int value);
  int  loadInt(const char* key, int defaultValue);

  void saveFloat(const char* key, float value);
  float loadFloat(const char* key, float defaultValue);

  void saveString(const char* key, const String &value);
  String loadString(const char* key, const String &defaultValue);

  // ---- Full reset ----
  void resetAll();
}

#endif // STORAGE_H
