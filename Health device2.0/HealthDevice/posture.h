#ifndef POSTURE_H
#define POSTURE_H

#include <Arduino.h>

namespace posture {
  void begin();          // loads saved baseline, if any
  void update();           // call every loop() — compares live pitch/roll to baseline

  bool hasBaseline();
  void resetBaseline();      // clears the saved posture calibration

  // Calibration flow (POSTURE SETUP screen)
  void startCalibration();     // begins the ~3s hold-still countdown
  bool isCalibrating();
  int  getCalibrationPercent(); // 0-100 progress for the bar
  bool calibrationJustFinished(); // true for one cycle when done

  bool isGood();          // current posture vs baseline
  float getDeviationDeg(); // how far off, for tuning "sensitivity"

  void setSensitivity(float degreesTolerance); // Settings -> Posture -> Sensitivity
  float getSensitivity();
}

#endif // POSTURE_H
