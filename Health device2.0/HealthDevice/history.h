#ifndef HEALTH_HISTORY_H
#define HEALTH_HISTORY_H

#include <Arduino.h>

namespace healthHistory {

  static const int MAX_RECORDS = 20;

  struct Record {
    uint16_t year;
    uint8_t month;
    uint8_t day;
    uint8_t hour;
    uint8_t minute;
    uint16_t value;
  };

  void begin();

  void addHeartRate(int bpm);
  void addSpO2(int percent);

  int getHeartRate(Record* out, int maxRecords);
  int getSpO2(Record* out, int maxRecords);

  int getHeartRateCount();
  int getSpO2Count();

  void clearAll();
}

#endif
