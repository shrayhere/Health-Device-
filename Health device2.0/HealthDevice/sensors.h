#ifndef SENSORS_H
#define SENSORS_H

#include <Arduino.h>

namespace hrSensor {

  bool begin();
  void update();

  void powerOn();
  void powerOff();

  bool isFingerDetected();
  long getLastIR();

  // ------------------------------------------------------------
  // Mode 1 — 8 second heart-rate scan
  // ------------------------------------------------------------

  void startScan();
  void cancelScan();

  bool isScanning();
  bool hasResult();
  bool scanFailed();

  int getResultBPM();
  void clearResult();

  // ------------------------------------------------------------
  // Mode 2 — Real-time BPM
  // ------------------------------------------------------------

  int getRealtimeBPM();

  int getSpO2();
  bool isSpO2Valid();
void startSpO2Scan();
void cancelSpO2Scan();
bool isSpO2Measuring();

  bool isRealtimeMode();

  void startRealtime();
  void stopRealtime();

  // Returns true when a new heartbeat was detected.
  bool beatDetected();
}

namespace motionSensor {

  bool begin();
  void update();

  float getPitch();
  float getRoll();
  float getAccelMagnitudeG();
  float getGyroMagnitudeDps();

  unsigned long getStepCount();
  void resetStepCount();
}

#endif // SENSORS_H