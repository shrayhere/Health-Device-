#include "posture.h"
#include "sensors.h"
#include "storage.h"

static bool baselineSet = false;
static float basePitch = 0;
static float baseRoll = 0;

static float sensitivityDeg =
    15.0f;

// ------------------------------------------------------------
// CALIBRATION
// ------------------------------------------------------------

static bool calibrating = false;

static unsigned long calStartMs =
    0;

static const unsigned long
    CAL_DURATION_MS =
        3000;

static bool justFinished =
    false;


// ------------------------------------------------------------
// LIVE POSTURE
// ------------------------------------------------------------

static bool currentlyGood =
    true;

static float currentDeviation =
    0.0f;


// ------------------------------------------------------------
// MPU FILTERING
// ------------------------------------------------------------
//
// The MPU can change by small amounts even when completely
// still. We smooth pitch and roll before calculating posture.
//

static float filteredPitch =
    0.0f;

static float filteredRoll =
    0.0f;

static bool filterInitialized =
    false;


// ------------------------------------------------------------
// CALIBRATION AVERAGING
// ------------------------------------------------------------
//
// Instead of saving one sample as the baseline, average many
// samples during calibration. This makes the saved baseline
// much more stable.
//

static float calPitchSum =
    0.0f;

static float calRollSum =
    0.0f;

static unsigned long calSampleCount =
    0;


// ============================================================
// POSTURE
// ============================================================

namespace posture {


// ------------------------------------------------------------
// BEGIN
// ------------------------------------------------------------

void begin() {

  baselineSet =
      storage::loadPostureBaseline(
          basePitch,
          baseRoll
      );

  sensitivityDeg =
      storage::loadFloat(
          "posture_sens",
          15.0f
      );

  currentDeviation =
      0.0f;

  currentlyGood =
      true;

  filteredPitch =
      0.0f;

  filteredRoll =
      0.0f;

  filterInitialized =
      false;
}


// ------------------------------------------------------------
// BASELINE
// ------------------------------------------------------------

bool hasBaseline() {

  return baselineSet;
}


// ------------------------------------------------------------
// RESET BASELINE
// ------------------------------------------------------------

void resetBaseline() {

  baselineSet =
      false;

  basePitch =
      0.0f;

  baseRoll =
      0.0f;

  currentDeviation =
      0.0f;

  currentlyGood =
      true;

  filteredPitch =
      0.0f;

  filteredRoll =
      0.0f;

  filterInitialized =
      false;

  calPitchSum =
      0.0f;

  calRollSum =
      0.0f;

  calSampleCount =
      0;

  calibrating =
      false;

  justFinished =
      false;

  storage::clearPostureBaseline();
}


// ------------------------------------------------------------
// START CALIBRATION
// ------------------------------------------------------------

void startCalibration() {

  calibrating =
      true;

  calStartMs =
      millis();

  justFinished =
      false;


  calPitchSum =
      0.0f;

  calRollSum =
      0.0f;

  calSampleCount =
      0;


  filterInitialized =
      false;

  currentDeviation =
      0.0f;

  currentlyGood =
      true;
}


// ------------------------------------------------------------
// IS CALIBRATING
// ------------------------------------------------------------

bool isCalibrating() {

  return calibrating;
}


// ------------------------------------------------------------
// CALIBRATION PROGRESS
// ------------------------------------------------------------

int getCalibrationPercent() {

  if (
      !calibrating
  ) {

    return 0;
  }


  unsigned long elapsed =
      millis() -
      calStartMs;


  int pct =
      (int)(
          (elapsed * 100UL) /
          CAL_DURATION_MS
      );


  if (
      pct > 100
  ) {

    pct =
        100;
  }


  return pct;
}


// ------------------------------------------------------------
// CALIBRATION FINISHED
// ------------------------------------------------------------

bool calibrationJustFinished() {

  bool result =
      justFinished;


  justFinished =
      false;


  return result;
}


// ------------------------------------------------------------
// UPDATE
// ------------------------------------------------------------

void update() {

  // ==========================================================
  // CALIBRATION
  // ==========================================================

  if (
      calibrating
  ) {

    float samplePitch =
        motionSensor::getPitch();

    float sampleRoll =
        motionSensor::getRoll();


    unsigned long elapsed =
        millis() -
        calStartMs;


    // Give the user 200 ms to settle before adding samples.
    if (
        elapsed >= 200UL
    ) {

      calPitchSum +=
          samplePitch;

      calRollSum +=
          sampleRoll;

      calSampleCount++;
    }


    // --------------------------------------------------------
    // FINISH CALIBRATION
    // --------------------------------------------------------

    if (
        elapsed >=
        CAL_DURATION_MS
    ) {

      if (
          calSampleCount > 0
      ) {

        basePitch =
            calPitchSum /
            (float)calSampleCount;

        baseRoll =
            calRollSum /
            (float)calSampleCount;
      }

      else {

        basePitch =
            samplePitch;

        baseRoll =
            sampleRoll;
      }


      storage::savePostureBaseline(
          basePitch,
          baseRoll
      );


      baselineSet =
          true;

      calibrating =
          false;

      justFinished =
          true;


      // Start the live filter from the current sensor value.
      filteredPitch =
          samplePitch;

      filteredRoll =
          sampleRoll;

      filterInitialized =
          true;


      currentDeviation =
          0.0f;

      currentlyGood =
          true;


      calPitchSum =
          0.0f;

      calRollSum =
          0.0f;

      calSampleCount =
          0;
    }


    return;
  }


  // ==========================================================
  // NO BASELINE
  // ==========================================================

  if (
      !baselineSet
  ) {

    return;
  }


  // ==========================================================
  // READ MPU
  // ==========================================================

  float rawPitch =
      motionSensor::getPitch();

  float rawRoll =
      motionSensor::getRoll();


  // ==========================================================
  // FIRST LOW-PASS FILTER
  // ==========================================================
  //
  // Lower alpha = more stable.
  // 0.10 gives a good compromise between stability and response.
  //

  const float FILTER_ALPHA =
      0.10f;


  if (
      !filterInitialized
  ) {

    filteredPitch =
        rawPitch;

    filteredRoll =
        rawRoll;

    filterInitialized =
        true;
  }

  else {

    filteredPitch +=
        FILTER_ALPHA *
        (
            rawPitch -
            filteredPitch
        );

    filteredRoll +=
        FILTER_ALPHA *
        (
            rawRoll -
            filteredRoll
        );
  }


  // ==========================================================
  // DEVIATION FROM BASELINE
  // ==========================================================

  float dPitch =
      filteredPitch -
      basePitch;

  float dRoll =
      filteredRoll -
      baseRoll;


  float filteredDeviation =
      sqrt(
          (
              dPitch *
              dPitch
          )
          +
          (
              dRoll *
              dRoll
          )
      );


  // ==========================================================
  // SECOND FILTER
  // ==========================================================
  //
  // Smooth the final displayed deviation as well.
  //

  const float DEVIATION_ALPHA =
      0.12f;


  currentDeviation +=
      DEVIATION_ALPHA *
      (
          filteredDeviation -
          currentDeviation
      );


  // ==========================================================
  // GOOD / BAD
  // ==========================================================

  currentlyGood =
      currentDeviation <=
      sensitivityDeg;
}


// ------------------------------------------------------------
// STATUS
// ------------------------------------------------------------

bool isGood() {
  if (!baselineSet) {
    return false;
  }
  return currentlyGood;
}


// ------------------------------------------------------------
// DEVIATION
// ------------------------------------------------------------

float getDeviationDeg() {

  return currentDeviation;
}


// ------------------------------------------------------------
// SENSITIVITY
// ------------------------------------------------------------

void setSensitivity(
    float degreesTolerance
) {

  sensitivityDeg =
      degreesTolerance;

  storage::saveFloat(
      "posture_sens",
      degreesTolerance
  );
}


// ------------------------------------------------------------
// GET SENSITIVITY
// ------------------------------------------------------------

float getSensitivity() {

  return sensitivityDeg;
}


} // namespace posture