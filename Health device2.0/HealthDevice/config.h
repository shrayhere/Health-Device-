#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>

// ============================================================
// HEALTH DEVICE — GLOBAL CONFIG
// ESP32-C3 Super Mini
// ============================================================

// ---------------- I2C BUS ----------------
#define PIN_I2C_SDA        8
#define PIN_I2C_SCL        10

#define OLED_I2C_ADDR      0x3C
#define MAX30102_I2C_ADDR  0x57
#define MPU6500_I2C_ADDR   0x68
#define MPU6500_WHO_AM_I   0x70

// ---------------- OLED ----------------
#define OLED_WIDTH         128
#define OLED_HEIGHT        64
#define OLED_RESET_PIN     -1

// ---------------- RGB LED (common cathode) ----------------
#define PIN_RGB_RED        0
#define PIN_RGB_GREEN      1
#define PIN_RGB_BLUE       2

// ---------------- BUTTON ----------------
#define PIN_BUTTON         3   // INPUT_PULLUP, pressed = LOW

// ---------------- BATTERY ----------------
#define PIN_BATTERY_ADC    4

// ---------------- BUZZER ----------------
#define PIN_BUZZER         6

// ---------------- FREE PINS ----------------
// GPIO5 and GPIO7 remain free / reserved for future use

// ---------------- BUTTON TIMING ----------------
#define BTN_DEBOUNCE_MS        40
#define BTN_DOUBLE_GAP_MS      500   // max gap between clicks to count as double
#define BTN_LONGPRESS_MS       1000  // ~1s hold = select/confirm
#define BTN_LOWPOWER_HOLD_MS   3000  // ~3s hold = low power toggle

// ---------------- HEART RATE ----------------
#define HR_FINGER_THRESHOLD    100000UL
#define HR_FINGER_CONFIRM_MS   500
#define HR_LOW_BPM             50
#define HR_HIGH_BPM            120
#define HR_HISTORY_MAX         10


// ---------------- WELLNESS DEFAULTS ----------------
#define WATER_GOAL_DEFAULT_CUPS       8
#define WATER_REMINDER_MINUTES        60
#define ACTIVITY_STEP_GOAL            6000UL
#define ACTIVITY_ACTIVE_MIN_GOAL      30UL
#define INACTIVITY_TIMEOUT_MINUTES    45UL

// Fall detector thresholds are prototype tuning values, not medical limits.
//
// The detector deliberately ignores small acceleration spikes and
// fast hand movement. A fall is confirmed by either:
//   1) sustained free-fall -> impact -> settling, or
//   2) strong direct impact -> settling -> orientation change.
#define FALL_IMPACT_G                1.70f
#define FALL_DIRECT_IMPACT_G         2.20f
#define FALL_FREE_FALL_G             0.55f
#define FALL_STABLE_MIN_G            0.80f
#define FALL_STABLE_MAX_G            1.20f
#define FALL_STABLE_GYRO_DPS         25.0f
#define FALL_ORIENTATION_CHANGE_DEG  35.0f
#define FALL_FREEFALL_MIN_DURATION_MS 120UL
#define FALL_FREEFALL_WINDOW_MS      1400UL
#define FALL_POST_IMPACT_WINDOW_MS   2200UL
#define FALL_STABLE_CONFIRM_MS       1000UL
#define FALL_LOW_MOTION_G            0.78f   // retained for compatibility
#define FALL_LOW_TO_CONFIRM_MS       FALL_STABLE_CONFIRM_MS
#define FALL_IMPACT_TO_LOW_MS        FALL_POST_IMPACT_WINDOW_MS
#define FALL_ALERT_MS                10000UL
#define FALL_COOLDOWN_MS             15000UL

// Breathing exercise: 4s inhale, 2s hold, 6s exhale, 2s hold.
#define BREATH_INHALE_MS              4000UL
#define BREATH_HOLD1_MS               2000UL
#define BREATH_EXHALE_MS              6000UL
#define BREATH_HOLD2_MS               2000UL

// ---------------- BATTERY VOLTAGE CURVE ----------------
#define BATT_V_EMPTY   3.30f
#define BATT_V_FULL    4.20f

// ---------------- MISC ----------------
#define SCREEN_TIMEOUT_DEFAULT_MS  0   // 0 = disabled by default, configurable in Settings

#endif // CONFIG_H
