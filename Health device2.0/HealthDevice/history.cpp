#include "history.h"

#include <Preferences.h>
#include "time_manager.h"

namespace {

Preferences prefs;

static const char* NAMESPACE_NAME = "health_hist";
static const char* HR_COUNT_KEY = "hr_count";
static const char* SPO2_COUNT_KEY = "sp_count";

static void makeKey(char* key, size_t keySize, const char* prefix, int index) {
  snprintf(key, keySize, "%s%d", prefix, index);
}

static void addRecord(const char* prefix, const char* countKey, int value) {
  if (value <= 0) return;

  healthHistory::Record records[healthHistory::MAX_RECORDS];
  int count = prefs.getUChar(countKey, 0);
  if (count > healthHistory::MAX_RECORDS) {
    count = healthHistory::MAX_RECORDS;
  }

  for (int i = count; i > 0; --i) {
    char srcKey[12];
    char dstKey[12];
    makeKey(srcKey, sizeof(srcKey), prefix, i - 1);
    makeKey(dstKey, sizeof(dstKey), prefix, i);

    healthHistory::Record r{};
    if (prefs.getBytes(srcKey, &r, sizeof(r)) == sizeof(r)) {
      prefs.putBytes(dstKey, &r, sizeof(r));
    }
  }

  DateTime dt = timeManager::now();
  healthHistory::Record newest{};
  newest.year = (uint16_t)dt.year;
  newest.month = (uint8_t)dt.month;
  newest.day = (uint8_t)dt.day;
  newest.hour = (uint8_t)dt.hour;
  newest.minute = (uint8_t)dt.minute;
  newest.value = (uint16_t)value;

  char firstKey[12];
  makeKey(firstKey, sizeof(firstKey), prefix, 0);
  prefs.putBytes(firstKey, &newest, sizeof(newest));

  if (count < healthHistory::MAX_RECORDS) {
    ++count;
  }
  prefs.putUChar(countKey, (uint8_t)count);
}

static int readRecords(const char* prefix, const char* countKey,
                       healthHistory::Record* out, int maxRecords) {
  if (!out || maxRecords <= 0) return 0;

  int count = prefs.getUChar(countKey, 0);
  if (count > healthHistory::MAX_RECORDS) {
    count = healthHistory::MAX_RECORDS;
  }
  if (count > maxRecords) {
    count = maxRecords;
  }

  int loaded = 0;
  for (int i = 0; i < count; ++i) {
    char key[12];
    makeKey(key, sizeof(key), prefix, i);
    if (prefs.getBytes(key, &out[loaded], sizeof(healthHistory::Record)) == sizeof(healthHistory::Record)) {
      ++loaded;
    }
  }

  return loaded;
}

static int getCount(const char* key) {
  int count = prefs.getUChar(key, 0);
  if (count < 0) count = 0;
  if (count > healthHistory::MAX_RECORDS) count = healthHistory::MAX_RECORDS;
  return count;
}

} // namespace

namespace healthHistory {

void begin() {
  prefs.begin(NAMESPACE_NAME, false);
}

void addHeartRate(int bpm) {
  addRecord("hr", HR_COUNT_KEY, bpm);
}

void addSpO2(int percent) {
  addRecord("sp", SPO2_COUNT_KEY, percent);
}

int getHeartRate(Record* out, int maxRecords) {
  return readRecords("hr", HR_COUNT_KEY, out, maxRecords);
}

int getSpO2(Record* out, int maxRecords) {
  return readRecords("sp", SPO2_COUNT_KEY, out, maxRecords);
}

int getHeartRateCount() {
  return getCount(HR_COUNT_KEY);
}

int getSpO2Count() {
  return getCount(SPO2_COUNT_KEY);
}

void clearAll() {
  prefs.clear();
}

} // namespace healthHistory
