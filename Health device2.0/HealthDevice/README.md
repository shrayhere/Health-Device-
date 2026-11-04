# Health Device — Firmware (Phase 1–11 baseline)

ESP32-C3 Super Mini wearable health device: heart rate (MAX30102), posture
(MPU-6500), steps, timer, reminders, alarms, battery, OLED UI, low-power mode.

## How to install

1. Copy this whole `HealthDevice` folder into your Arduino sketchbook
   (Arduino IDE requires the folder name to match the `.ino` filename —
   it already does: `HealthDevice/HealthDevice.ino`).
2. Install libraries (Library Manager):
   - Adafruit GFX Library
   - Adafruit SSD1306
   - Adafruit BusIO
   - SparkFun MAX3010x Pulse and Proximity Sensor Library
   (Adafruit MPU6050 is **not** used — the MPU-6500 is read directly over
   I2C in `sensors.cpp`, matching the spec's warning about register
   differences.)
3. Board: "ESP32C3 Dev Module" (esp32 core by Espressif).
4. Wire per the pin map below, then upload.

## Pin map

| GPIO | Function        |
|------|-----------------|
| 0    | RGB Red         |
| 1    | RGB Green       |
| 2    | RGB Blue        |
| 3    | Pushbutton (INPUT_PULLUP, pressed = LOW) |
| 4    | Battery voltage (ADC, via divider) |
| 6    | Buzzer          |
| 8    | I2C SDA (OLED, MAX30102, MPU-6500) |
| 10   | I2C SCL         |

## What's implemented vs. what needs your tuning

Implemented and wired end-to-end, per the master spec:
- Hardware bring-up + serial diagnostics for OLED / MAX30102 / MPU-6500
- Home screen, battery header on every screen
- Heart rate: finger detection (threshold 100000, 500ms confirm), animated
  scan screen (no countdown text), NORMAL/HIGH result, result persists after
  finger removal until navigated away, double-press exits, failed-scan screen,
  10-slot HR history in flash
- Posture: no-long-press calibration flow (Posture → Posture Setup → press →
  3s calibrate → baseline saved), GOOD/BAD monitoring vs. baseline
- Activity: step counter (simple accel-magnitude peak detector), distance,
  active time
- Timer: set/start/pause/reset/finish + alert
- Reminders and Alarms: add/enable/disable, time-match firing, alert overlays
- Alert priority arbitration (Alarm > Critical battery > Timer > Reminder >
  Posture) per section 33
- Low power mode: 3s hold, OLED + MAX30102 off, everything else (MPU,
  clock, timer, reminders, alarms, battery, button) keeps running; single
  press or long-press wakes it back up, no reboot
- Persistent storage via ESP32 Preferences for HR history, posture baseline,
  alarms, reminders, and settings

Needs your real-world tuning (flagged inline in code comments too):
- `battery.cpp`: `DIVIDER_FACTOR` — set this to your actual voltage-divider
  ratio once you've measured it with a multimeter against a known battery
  voltage. It's a placeholder (2.0, assumes 100k/100k).
- `sensors.cpp`: `STEP_THRESHOLD_HIGH` / `STEP_THRESHOLD_LOW` — the spec
  explicitly says step counting needs real-world testing; these are
  reasonable starting points, not calibrated.
- `time_manager.cpp`: there's no RTC chip and no Wi-Fi sync yet (spec says
  that's fine for v1) — you set the clock manually. A "Time/Date" editing
  UI isn't wired into the Settings→System screen yet (it shows the menu,
  but editing fields via the single button needs a small digit-picker UI —
  next thing to build once you're ready).
- Full Settings sub-menu navigation (Brightness/Timeout/Sensitivity value
  editing, reminder/alarm creation screens) currently render the read-only
  view from the spec's mockups; wiring up "create new reminder/alarm" and
  in-place value editing with the single button is the natural Phase 12.

## Module map (matches the spec's file list)

`config.h` · `storage.*` · `battery.*` · `button.*` · `alerts.*` ·
`sensors.*` (MAX30102 + MPU-6500) · `posture.*` · `activity.*` · `timer.*`
(namespaced `healthTimer` to avoid clashing with Arduino's own timer APIs) ·
`reminders.*` · `alarms.*` · `time_manager.*` · `display.*` · `settings.*`

Every screen ID lives in one place — the `DeviceScreen` enum in
`display.h` — specifically to avoid the int-vs-enum and duplicate-screen
mismatches that broke the earlier Antigravity-generated build.
