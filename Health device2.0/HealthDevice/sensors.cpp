#include "sensors.h"
#include "config.h"
#include <Wire.h>
#include "MAX30105.h"
#include "spo2_algorithm.h"


// =================================================================
// MAX30102 — HEART RATE
// =================================================================

static MAX30105 particleSensor;


static bool hrSensorFound = false;
static bool hrPoweredOn = true;


static long lastIR = 0;


static bool fingerDetected = false;
static unsigned long fingerSinceMs = 0;
static bool fingerConfirmed = false;


static unsigned long fingerLostSinceMs = 0;


static const unsigned long FINGER_LOSS_GRACE_MS = 1000;


// -----------------------------------------------------------------
// Prevent automatic restart until finger is removed
// -----------------------------------------------------------------

static bool waitForFingerRemoval = false;


// -----------------------------------------------------------------
// Real-time mode
// -----------------------------------------------------------------

static bool realtimeMode = false;


// -----------------------------------------------------------------
// SpO2 data
// SparkFun/Maxim algorithm uses 100 samples at 25 Hz (~4 seconds).
// -----------------------------------------------------------------
static const int SPO2_BUFFER_SIZE = 100;
static uint32_t spo2IRBuffer[SPO2_BUFFER_SIZE];
static uint32_t spo2RedBuffer[SPO2_BUFFER_SIZE];
static int spo2SampleCount = 0;
static unsigned long lastSpO2SampleMs = 0;
static int spo2Value = 0;
static bool spo2Valid = false;
static const unsigned long SPO2_SAMPLE_INTERVAL_MS = 40;


// =================================================================
// BPM DATA
// =================================================================

static float beatsPerMinute = 0;
static int beatAvg = 0;
static bool beatFlag = false;


static const int RATE_SIZE = 6;


static int rates[RATE_SIZE];


static byte rateSpot = 0;


static int validRateCount = 0;


static unsigned long lastBeatMs = 0;


// =================================================================
// PULSE DETECTOR
// =================================================================

static float irBaseline = 0;


static float filteredPulse = 0;


static float pulsePrev2 = 0;


static float pulsePrev1 = 0;


static float pulseEnvelope = 0;


static bool pulseDetectorReady = false;


static const float BASELINE_ALPHA = 0.015f;


static const float FILTER_ALPHA = 0.35f;


static const unsigned long MIN_BEAT_INTERVAL_MS = 400;


static const unsigned long MAX_BEAT_INTERVAL_MS = 2000;


static const float MIN_PULSE_AMPLITUDE = 80.0f;


static const float PEAK_THRESHOLD_RATIO = 0.28f;


static unsigned long lastDetectorBeatMs = 0;


// =================================================================
// SCAN STATE
// =================================================================

enum ScanState {

  SCAN_IDLE,

  SCAN_WAIT_FINGER,

  SCAN_RUNNING,

  SCAN_DONE_OK,

  SCAN_DONE_FAIL

};


static ScanState scanState = SCAN_IDLE;


static unsigned long scanStartMs = 0;


static int scanBeatCount = 0;


static int scanResultBPM = 0;


static const unsigned long SCAN_MIN_DURATION_MS = 8000;


static const int SCAN_MIN_BEATS = 3;


// =================================================================
// DEBUG
// =================================================================

static unsigned long lastDebugMs = 0;


// =================================================================
// RESET SpO2 DATA
// =================================================================

static void resetSpO2Data() {

  spo2SampleCount = 0;
  lastSpO2SampleMs = 0;
  spo2Value = 0;
  spo2Valid = false;
}


static void processSpO2Sample(
    uint32_t ir,
    uint32_t red,
    unsigned long now
) {

  if (!fingerConfirmed) {
    return;
  }

  if (lastSpO2SampleMs != 0 &&
      now - lastSpO2SampleMs < SPO2_SAMPLE_INTERVAL_MS) {
    return;
  }

  lastSpO2SampleMs = now;

  if (spo2SampleCount < SPO2_BUFFER_SIZE) {
    spo2IRBuffer[spo2SampleCount] = ir;
    spo2RedBuffer[spo2SampleCount] = red;
    spo2SampleCount++;
  }

  if (spo2SampleCount >= SPO2_BUFFER_SIZE) {

    int32_t calculatedSpO2 = 0;
    int8_t validSpO2 = 0;
    int32_t calculatedHR = 0;
    int8_t validHR = 0;

    maxim_heart_rate_and_oxygen_saturation(
        spo2IRBuffer,
        SPO2_BUFFER_SIZE,
        spo2RedBuffer,
        &calculatedSpO2,
        &validSpO2,
        &calculatedHR,
        &validHR
    );

    if (validSpO2 && calculatedSpO2 >= 70 && calculatedSpO2 <= 100) {
      spo2Value = (int)calculatedSpO2;
      spo2Valid = true;

      Serial.print("SpO2: ");
      Serial.print(spo2Value);
      Serial.println("% (LIVE)");
    }

    // Keep the newest half of the window so LIVE VITALS can
    // continuously refresh SpO2 instead of waiting for another
    // completely empty 4-second window.
    const int keepSamples = SPO2_BUFFER_SIZE / 2;
    for (int i = 0; i < keepSamples; i++) {
      spo2IRBuffer[i] = spo2IRBuffer[SPO2_BUFFER_SIZE - keepSamples + i];
      spo2RedBuffer[i] = spo2RedBuffer[SPO2_BUFFER_SIZE - keepSamples + i];
    }
    spo2SampleCount = keepSamples;
  }
}


// =================================================================
// RESET BPM DATA
// =================================================================

static void resetBPMData() {

  beatsPerMinute = 0;

  beatAvg = 0;

  rateSpot = 0;

  validRateCount = 0;

  lastBeatMs = 0;

  lastDetectorBeatMs = 0;

  irBaseline = 0;

  filteredPulse = 0;

  pulsePrev2 = 0;

  pulsePrev1 = 0;

  pulseEnvelope = 0;

  pulseDetectorReady = false;

  beatFlag = false;

  scanBeatCount = 0;


  for (int i = 0; i < RATE_SIZE; i++) {

    rates[i] = 0;
  }
}


// =================================================================
// ADD BPM
// =================================================================

static void addBPM(int bpm) {

  if (bpm < 40 || bpm > 180) {

    return;
  }


  rates[rateSpot] = bpm;

  rateSpot++;


  if (rateSpot >= RATE_SIZE) {

    rateSpot = 0;
  }


  if (validRateCount < RATE_SIZE) {

    validRateCount++;
  }


  long total = 0;


  for (int i = 0; i < validRateCount; i++) {

    total += rates[i];
  }


  beatAvg =
      total / validRateCount;


  beatsPerMinute = bpm;
}


// =================================================================
// REGISTER HEARTBEAT
// =================================================================

static void registerBeat(unsigned long now) {

  beatFlag = true;


  if (lastBeatMs == 0) {

    lastBeatMs = now;

    Serial.println("FIRST BEAT");

    return;
  }


  unsigned long interval =
      now - lastBeatMs;


  if (
      interval < MIN_BEAT_INTERVAL_MS ||
      interval > MAX_BEAT_INTERVAL_MS
  ) {

    return;
  }


  lastBeatMs = now;


  int bpm =
      (int)(60000.0f / interval);


  if (
      bpm < 40 ||
      bpm > 180
  ) {

    return;
  }


  addBPM(bpm);


  if (
      scanState ==
      SCAN_RUNNING
  ) {

    scanBeatCount++;
  }


  Serial.print("BEAT ");

  Serial.print(scanBeatCount);

  Serial.print("  BPM=");

  Serial.print(bpm);

  Serial.print("  AVG=");

  Serial.println(beatAvg);
}


// =================================================================
// HEARTBEAT PROCESSING
// =================================================================

static void processHeartbeat(long ir) {

  unsigned long now =
      millis();


  if (!pulseDetectorReady) {

    irBaseline =
        (float)ir;

    pulseDetectorReady =
        true;

    pulsePrev2 = 0;

    pulsePrev1 = 0;

    pulseEnvelope = 0;

    return;
  }


  // Slowly follow DC level.

  irBaseline +=
      ((float)ir - irBaseline) *
      BASELINE_ALPHA;


  // Remove DC component.

  float acSignal =
      (float)ir - irBaseline;


  // Smooth AC component.

  filteredPulse +=
      (acSignal - filteredPulse) *
      FILTER_ALPHA;


  float absolutePulse =
      fabs(filteredPulse);


  if (
      absolutePulse >
      pulseEnvelope
  ) {

    pulseEnvelope =
        absolutePulse;

  }

  else {

    pulseEnvelope *=
        0.995f;
  }


  if (
      pulseEnvelope <
      MIN_PULSE_AMPLITUDE
  ) {

    pulsePrev2 =
        pulsePrev1;

    pulsePrev1 =
        filteredPulse;

    return;
  }


  float threshold =
      pulseEnvelope *
      PEAK_THRESHOLD_RATIO;


  if (
      threshold <
      MIN_PULSE_AMPLITUDE
  ) {

    threshold =
        MIN_PULSE_AMPLITUDE;
  }


  bool localPeak =

      (pulsePrev1 > pulsePrev2) &&

      (pulsePrev1 >= filteredPulse) &&

      (pulsePrev1 > threshold);


  if (localPeak) {

    if (
        lastDetectorBeatMs == 0 ||
        now - lastDetectorBeatMs >=
            MIN_BEAT_INTERVAL_MS
    ) {

      lastDetectorBeatMs =
          now;

      registerBeat(now);
    }
  }


  pulsePrev2 =
      pulsePrev1;

  pulsePrev1 =
      filteredPulse;
}


// =================================================================
// HR SENSOR
// =================================================================

namespace hrSensor {


bool begin() {

  Wire.beginTransmission(
      MAX30102_I2C_ADDR
  );


  if (
      Wire.endTransmission() != 0
  ) {

    hrSensorFound =
        false;

    Serial.println(
        "MAX30102 NOT FOUND"
    );

    return false;
  }


  if (
      !particleSensor.begin(
          Wire,
          I2C_SPEED_FAST
      )
  ) {

    hrSensorFound =
        false;

    Serial.println(
        "MAX30102 BEGIN FAILED"
    );

    return false;
  }


  particleSensor.setup();


  particleSensor.setPulseAmplitudeIR(
      0x1F
  );


  particleSensor.setPulseAmplitudeRed(
      0x0A
  );


  particleSensor.setPulseAmplitudeGreen(
      0
  );


  hrSensorFound =
      true;

  hrPoweredOn =
      true;


  waitForFingerRemoval =
      false;


  realtimeMode =
      false;


  resetBPMData();
  resetSpO2Data();


  Serial.println(
      "HR SENSOR READY"
  );


  return true;
}


// =================================================================
// POWER ON
// =================================================================

void powerOn() {

  if (!hrSensorFound) {

    return;
  }


  particleSensor.wakeUp();

  hrPoweredOn =
      true;


  realtimeMode =
      false;


  resetBPMData();
  resetSpO2Data();


  waitForFingerRemoval =
      false;
}


// =================================================================
// POWER OFF
// =================================================================

void powerOff() {

  if (!hrSensorFound) {

    return;
  }


  particleSensor.shutDown();

  hrPoweredOn =
      false;


  realtimeMode =
      false;


  scanState =
      SCAN_IDLE;


  resetBPMData();
  resetSpO2Data();
}


// =================================================================
// UPDATE
// =================================================================

void update() {

  beatFlag =
      false;


  if (
      !hrSensorFound ||
      !hrPoweredOn
  ) {

    return;
  }


  long ir =
      particleSensor.getIR();

  long red =
      particleSensor.getRed();


  lastIR =
      ir;


  unsigned long now =
      millis();


  // ===============================================================
  // FINGER DETECTION
  // ===============================================================

  bool aboveThreshold =
      (ir > HR_FINGER_THRESHOLD);


  if (aboveThreshold) {

    fingerLostSinceMs =
        0;


    if (!fingerDetected) {

      fingerDetected =
          true;

      fingerSinceMs =
          now;

      fingerConfirmed =
          false;


      Serial.println(
          "FINGER DETECTED"
      );
    }


    else if (
        !fingerConfirmed &&
        now - fingerSinceMs >=
            HR_FINGER_CONFIRM_MS
    ) {

      fingerConfirmed =
          true;


      Serial.println(
          "FINGER CONFIRMED"
      );

      // LIVE VITALS: every newly confirmed finger starts a
      // completely fresh BPM + SpO2 measurement.
      if (realtimeMode) {
        resetBPMData();
        resetSpO2Data();
        Serial.println("LIVE VITALS MEASUREMENT STARTED");
      }
    }
  }


  else {

    if (
        fingerDetected &&
        fingerLostSinceMs == 0
    ) {

      fingerLostSinceMs =
          now;
    }


    if (
        fingerLostSinceMs != 0 &&
        now - fingerLostSinceMs >=
            FINGER_LOSS_GRACE_MS
    ) {

      fingerDetected =
          false;

      fingerConfirmed =
          false;

      fingerLostSinceMs =
          0;


      // -----------------------------------------------------------
      // Once the finger is removed, automatic scanning is allowed
      // again.
      // -----------------------------------------------------------

      if (waitForFingerRemoval) {

        waitForFingerRemoval =
            false;

        Serial.println(
            "HR READY FOR NEXT SCAN"
        );
      }


      Serial.println(
          "FINGER REMOVED"
      );

      // LIVE VITALS: removing the finger fully resets the live
      // measurement so the next finger placement starts fresh.
      if (realtimeMode) {
        resetBPMData();
        resetSpO2Data();
        Serial.println("LIVE VITALS WAITING FOR FINGER");
      }
      // Normal SpO2 scans keep the last valid result after the
      // finger is removed, just like the normal heart-rate scan.
    }
  }


  // ===============================================================
  // AUTOMATIC SCAN
  // ===============================================================

  if (
      fingerConfirmed &&

      !realtimeMode &&

      !waitForFingerRemoval &&

      scanState ==
          SCAN_IDLE
  ) {

    resetBPMData();


    scanStartMs =
        now;


    scanState =
        SCAN_RUNNING;


    Serial.println(
        "AUTO HR SCAN STARTED"
    );
  }


  // ===============================================================
  // HEARTBEAT PROCESSING
  // ===============================================================

  if (fingerConfirmed) {

    processHeartbeat(ir);

    processSpO2Sample(
        (uint32_t)ir,
        (uint32_t)red,
        now
    );
  }



  // ===============================================================
  // SCAN STATE
  // ===============================================================

  switch (scanState) {


    case SCAN_WAIT_FINGER:

      if (fingerConfirmed) {

        resetBPMData();


        scanStartMs =
            now;


        scanState =
            SCAN_RUNNING;


        Serial.println(
            "HR SCAN STARTED"
        );
      }

      break;


    case SCAN_RUNNING:

      // -----------------------------------------------------------
      // Finger removed
      // -----------------------------------------------------------

      if (!fingerConfirmed) {

        if (
            scanBeatCount >=
                SCAN_MIN_BEATS &&

            beatAvg > 0
        ) {

          scanResultBPM =
              beatAvg;


          scanState =
              SCAN_DONE_OK;


          Serial.print(
              "FINAL BPM: "
          );


          Serial.println(
              scanResultBPM
          );

        }

        else {

          scanState =
              SCAN_DONE_FAIL;


          Serial.print(
              "SCAN FAILED. BEATS: "
          );


          Serial.println(
              scanBeatCount
          );
        }


        break;
      }


      // -----------------------------------------------------------
      // 8 second completion
      // -----------------------------------------------------------

      if (
          now - scanStartMs >=
              SCAN_MIN_DURATION_MS
      ) {

        if (
            scanBeatCount >=
                SCAN_MIN_BEATS &&

            beatAvg > 0
        ) {

          scanResultBPM =
              beatAvg;


          scanState =
              SCAN_DONE_OK;


          Serial.println(
              "8 SECOND SCAN COMPLETE"
          );


          Serial.print(
              "FINAL BPM: "
          );


          Serial.println(
              scanResultBPM
          );

        }

        else {

          scanState =
              SCAN_DONE_FAIL;


          Serial.println(
              "8 SECOND SCAN COMPLETE"
          );


          Serial.print(
              "SCAN FAILED. BEATS: "
          );


          Serial.println(
              scanBeatCount
          );
        }
      }

      break;


    case SCAN_DONE_OK:

      // Keep result.
      break;


    case SCAN_DONE_FAIL:

      // Keep failure.
      break;


    case SCAN_IDLE:

    default:

      break;
  }


  // ===============================================================
  // DEBUG
  // ===============================================================

  if (
      now - lastDebugMs >=
          500
  ) {

    lastDebugMs =
        now;


    Serial.print(
        "IR: "
    );


    Serial.print(
        ir
    );


    Serial.print(
        "  Finger: "
    );


    if (fingerConfirmed) {

      Serial.print(
          "YES"
      );

    }

    else {

      Serial.print(
          "NO "
      );
    }


    Serial.print(
        "  Scan: "
    );


    switch (scanState) {

      case SCAN_IDLE:

        Serial.println(
            "IDLE"
        );

        break;

      case SCAN_WAIT_FINGER:

        Serial.println(
            "WAITING"
        );

        break;

      case SCAN_RUNNING:

        Serial.println(
            "RUNNING"
        );

        break;

      case SCAN_DONE_OK:

        Serial.println(
            "DONE"
        );

        break;

      case SCAN_DONE_FAIL:

        Serial.println(
            "FAILED"
        );

        break;
    }
  }
}


// =================================================================
// GETTERS
// =================================================================

bool isFingerDetected() {

  return fingerConfirmed;
}


long getLastIR() {

  return lastIR;
}


// =================================================================
// START SCAN
// =================================================================

void startScan() {

  realtimeMode =
      false;

  // Manual scan request always unlocks scanning.

  waitForFingerRemoval =
      false;


  resetBPMData();


  scanResultBPM =
      0;


  scanStartMs =
      0;


  if (fingerConfirmed) {

    scanStartMs =
        millis();


    scanState =
        SCAN_RUNNING;


    Serial.println(
        "HR SCAN STARTED"
    );

  }

  else {

    scanState =
        SCAN_WAIT_FINGER;


    Serial.println(
        "HR SCAN WAITING FOR FINGER"
    );
  }
}


// =================================================================
// CANCEL
// =================================================================

void cancelScan() {

  scanState =
      SCAN_IDLE;


  resetBPMData();
}


// =================================================================
// STATE GETTERS
// =================================================================

bool isScanning() {

  return
      scanState ==
          SCAN_WAIT_FINGER ||

      scanState ==
          SCAN_RUNNING;
}


bool hasResult() {

  return scanState ==
         SCAN_DONE_OK;
}


bool scanFailed() {

  return scanState ==
         SCAN_DONE_FAIL;
}


int getResultBPM() {

  return scanResultBPM;
}


// =================================================================
// REAL-TIME BPM
// =================================================================

int getRealtimeBPM() {

  if (beatAvg > 0) {

    return beatAvg;
  }

  return 0;
}


int getSpO2() {

  return spo2Value;
}


bool isSpO2Valid() {

  return spo2Valid;
}


bool isRealtimeMode() {

  return realtimeMode;
}


void startRealtime() {

  realtimeMode =
      true;

  scanState =
      SCAN_IDLE;

  scanResultBPM =
      0;

  waitForFingerRemoval =
      false;

  resetBPMData();

  // Start a fresh real-time SpO2 measurement window too.
  resetSpO2Data();

  Serial.println(
      "LIVE VITALS MODE STARTED"
  );
}


void stopRealtime() {

  realtimeMode =
      false;

  scanState =
      SCAN_IDLE;

  scanResultBPM =
      0;

  resetBPMData();

  Serial.println(
      "HR REAL-TIME MODE STOPPED"
  );
}


// =================================================================
// CLEAR RESULT
// =================================================================

void clearResult() {

  scanState =
      SCAN_IDLE;


  scanResultBPM =
      0;


  resetBPMData();


  // ---------------------------------------------------------------
  // CRITICAL:
  //
  // Do not immediately start another scan if the finger is still
  // touching the sensor.
  //
  // The user must remove the finger first.
  // ---------------------------------------------------------------

  if (fingerConfirmed) {

    waitForFingerRemoval =
        true;


    Serial.println(
        "HR WAITING FOR FINGER REMOVAL"
    );

  }
}


// =================================================================
// BEAT FLAG
// =================================================================

bool beatDetected() {

  return beatFlag;
}

} // namespace hrSensor



// =================================================================
// MPU-6500 — MOTION / POSTURE
// =================================================================

#define MPU_REG_WHO_AM_I     0x75

#define MPU_REG_PWR_MGMT_1   0x6B

#define MPU_REG_ACCEL_XOUT_H 0x3B


static bool motionFound =
    false;


static float pitchDeg =
    0;


static float rollDeg =
    0;


static unsigned long stepCount = 0;
static float accelMagFiltered = 1.0f;
static float accelMagnitudeG = 1.0f;
static float gyroMagnitudeDps = 0.0f;

static bool stepArmed = true;
static unsigned long lastStepMs = 0;

// Smart Pedometer Filtering:
// Normal resting gravity = 1.0G. Human walking impact peak = 1.35G - 1.80G.
static const float STEP_THRESHOLD_HIGH = 1.38f;
static const float STEP_THRESHOLD_LOW  = 0.90f;
static const float STEP_MIN_SWING      = 0.38f;

static const unsigned long STEP_MIN_INTERVAL_MS = 280;   // Max ~3.5 steps/sec (sprinting)
static const unsigned long STEP_MAX_INTERVAL_MS = 2000;  // Cadence timeout (user stopped walking)

// Commercial Smartwatch Streak Filter:
// Random moves, picking up device, or hand gestures produce 1-3 spikes.
// A person must take at least 4 consecutive rhythmic steps before counting begins!
static const int MIN_WALKING_STREAK = 4;
static int stepStreak = 0;
static float currentCycleValley = 1.0f;
static float currentCyclePeak = 1.0f;


// =================================================================
// MPU READ
// =================================================================

static uint8_t mpuReadReg(
    uint8_t reg
) {

  Wire.beginTransmission(
      MPU6500_I2C_ADDR
  );


  Wire.write(
      reg
  );


  Wire.endTransmission(
      false
  );


  Wire.requestFrom(
      (int)MPU6500_I2C_ADDR,
      1
  );


  if (
      Wire.available()
  ) {

    return Wire.read();
  }


  return 0;
}


// =================================================================
// MPU WRITE
// =================================================================

static void mpuWriteReg(
    uint8_t reg,
    uint8_t value
) {

  Wire.beginTransmission(
      MPU6500_I2C_ADDR
  );


  Wire.write(
      reg
  );

  Wire.write(
      value
  );


  Wire.endTransmission();
}


// =================================================================
// READ MPU
// =================================================================

static bool mpuReadAccelGyro(
    int16_t &ax,
    int16_t &ay,
    int16_t &az,
    int16_t &gx,
    int16_t &gy,
    int16_t &gz
) {

  Wire.beginTransmission(
      MPU6500_I2C_ADDR
  );


  Wire.write(
      MPU_REG_ACCEL_XOUT_H
  );


  if (
      Wire.endTransmission(
          false
      ) != 0
  ) {

    return false;
  }


  Wire.requestFrom(
      (int)MPU6500_I2C_ADDR,
      14
  );


  if (
      Wire.available() < 14
  ) {

    return false;
  }


  ax =
      (Wire.read() << 8) |
      Wire.read();


  ay =
      (Wire.read() << 8) |
      Wire.read();


  az =
      (Wire.read() << 8) |
      Wire.read();


  // Skip temperature.

  Wire.read();

  Wire.read();


  gx =
      (Wire.read() << 8) |
      Wire.read();


  gy =
      (Wire.read() << 8) |
      Wire.read();


  gz =
      (Wire.read() << 8) |
      Wire.read();


  return true;
}


// =================================================================
// MOTION SENSOR
// =================================================================

namespace motionSensor {


bool begin() {

  uint8_t who =
      mpuReadReg(
          MPU_REG_WHO_AM_I
      );


  if (
      who != MPU6500_WHO_AM_I
  ) {

    motionFound =
        false;

    return false;
  }


  mpuWriteReg(
      MPU_REG_PWR_MGMT_1,
      0x00
  );


  delay(10);


  motionFound =
      true;


  return true;
}


// =================================================================
// UPDATE
// =================================================================

void update() {

  if (!motionFound) {

    return;
  }


  int16_t ax;
  int16_t ay;
  int16_t az;

  int16_t gx;
  int16_t gy;
  int16_t gz;


  if (
      !mpuReadAccelGyro(
          ax,
          ay,
          az,
          gx,
          gy,
          gz
      )
  ) {

    return;
  }


  float axg =
      ax / 16384.0f;

  float ayg =
      ay / 16384.0f;

  float azg =
      az / 16384.0f;


  // ---------------------------------------------------------------
  // PITCH
  // ---------------------------------------------------------------

  pitchDeg =

      atan2(
          -axg,

          sqrt(
              ayg * ayg +
              azg * azg
          )
      )

      * 180.0 /
      PI;


  // ---------------------------------------------------------------
  // ROLL
  // ---------------------------------------------------------------

  rollDeg =

      atan2(
          ayg,
          azg
      )

      * 180.0 /
      PI;


  // ---------------------------------------------------------------
  // STEP DETECTION
  // ---------------------------------------------------------------

  float mag =

      sqrt(
          axg * axg +
          ayg * ayg +
          azg * azg
      );

  accelMagnitudeG = mag;

  // MPU-6500 defaults to +/-250 dps after reset, so the default
  // sensitivity is approximately 131 LSB per degree/second.
  float gxDps = gx / 131.0f;
  float gyDps = gy / 131.0f;
  float gzDps = gz / 131.0f;

  gyroMagnitudeDps =
      sqrt(
          gxDps * gxDps +
          gyDps * gyDps +
          gzDps * gzDps
      );


  accelMagFiltered =

      accelMagFiltered *
          0.8f +

      mag *
          0.2f;


  unsigned long now =
      millis();


  // Reset walking streak if more than 2 seconds elapsed since last step (motion paused)
  if (stepStreak > 0 && (now - lastStepMs > STEP_MAX_INTERVAL_MS)) {
    stepStreak = 0;
    currentCycleValley = 1.0f;
    currentCyclePeak = 1.0f;
  }

  // Track min/max swing during cycle
  if (accelMagFiltered < currentCycleValley) {
    currentCycleValley = accelMagFiltered;
  }
  if (accelMagFiltered > currentCyclePeak) {
    currentCyclePeak = accelMagFiltered;
  }

  // Detect genuine footstep impact peak with swing validation
  if (
      stepArmed &&
      accelMagFiltered > STEP_THRESHOLD_HIGH &&
      (currentCyclePeak - currentCycleValley >= STEP_MIN_SWING) &&
      now - lastStepMs > STEP_MIN_INTERVAL_MS
  ) {
    lastStepMs = now;
    stepArmed = false;
    currentCycleValley = accelMagFiltered; // reset for next trough

    stepStreak++;
    if (stepStreak == MIN_WALKING_STREAK) {
      // 4 continuous rhythmic footsteps confirmed: retroactively credit all 4!
      stepCount += MIN_WALKING_STREAK;
    } else if (stepStreak > MIN_WALKING_STREAK) {
      // User is continuously walking: count each step directly
      stepCount++;
    }
    // Note: If stepStreak < 4 (random gesture or picking up device),
    // stepCount is NOT incremented, and 2-second timeout discards it!
  }
  else if (
      !stepArmed &&
      accelMagFiltered < STEP_THRESHOLD_LOW
  ) {
    stepArmed = true;
    currentCyclePeak = accelMagFiltered; // reset for next peak
  }
}


// =================================================================
// GETTERS
// =================================================================

float getPitch() {

  return pitchDeg;
}


float getRoll() {

  return rollDeg;
}


float getAccelMagnitudeG() {

  return accelMagnitudeG;
}


float getGyroMagnitudeDps() {

  return gyroMagnitudeDps;
}


unsigned long getStepCount() {

  return stepCount;
}


void resetStepCount() {
  stepCount = 0;
  stepStreak = 0;
  lastStepMs = 0;
  currentCycleValley = 1.0f;
  currentCyclePeak = 1.0f;
}

} // namespace motionSensor