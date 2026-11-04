#include "display.h"
#include "config.h"

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Fonts/TomThumb.h>
#include <Adafruit_SSD1306.h>

#include "battery.h"
#include "alerts.h"
#include "sensors.h"
#include "posture.h"
#include "activity.h"
#include "timer.h"
#include "reminders.h"
#include "alarms.h"
#include "time_manager.h"
#include "storage.h"
#include "settings.h"
#include "wellness.h"
#include "wifi_manager.h"
#include "history.h"

// ============================================================
// OLED
// ============================================================

static Adafruit_SSD1306 oled(
    OLED_WIDTH,
    OLED_HEIGHT,
    &Wire,
    OLED_RESET_PIN
);

static bool oledFound = false;

static bool asleep = false;

// ============================================================
// CURRENT SCREEN
// ============================================================

static DeviceScreen currentScreen =
    SCR_STARTUP;

static DeviceScreen screenBeforeAlert =
    SCR_HOME;

static bool redrawNeeded =
    true;

static unsigned long lastRenderMs =
    0;

// ============================================================
// CLOCK MODE
// ============================================================
//
// 0 = CLOCK
// 1 = TIMER
// 2 = STOPWATCH
// 3 = ALARM
//

static int clockMode =
    0;

// ============================================================
// MAIN MENU SELECTION
// ============================================================

// 0 = Posture Setup
// 1 = Alarms
// 2 = Reminders
// 3 = Display
// 4 = Sound
// 5 = Wi-Fi
// 6 = System

static int settingsMenuSelection =
    -1;

static bool settingsMenuSelectionActive =
    false;

static int settingsMenuOffset =
    0;

// ============================================================
// DISPLAY SETTINGS EDITOR
// ============================================================
// 0 = Screen Timeout
// 1 = Always On
// 2 = Orientation

static int displaySettingsSelection = 0;
static bool displaySettingsEditMode = false;
static unsigned long lastDisplayActivityMs = 0;

// Sound settings editor
static int soundSettingsSelection = 0; // 0=Sound, 1=Volume, 2=DND, 3=Click Sound
static bool soundSettingsEditMode = false;

// System settings selection
// 0 = Time / Date
// 1 = Reset Data
// 2 = Diagnostics
// 3 = LED Brightness
// 4 = About System
static int systemSelection = 0;

// ============================================================
// WI-FI SETTINGS SELECTION
// ============================================================

static int wifiMenuSelection =
    0;

// ============================================================
// ALARM LIST SELECTION
// ============================================================

static int alarmListSelection =
    0;

static int alarmListOffset =
    0;

static bool alarmListSelectionActive =
    false;

// ============================================================
// ALARM SETUP EDITOR
// ============================================================

static int alarmSetupIndex = 0;
static int alarmSetupSelection = 0;
static bool alarmSetupEditMode = false;
static int alarmSetupEditType = 0;

// Time editor: 0=hour, 1=minute, 2=AM/PM
static int alarmTimeField = 0;
static int alarmEditHour12 = 12;
static int alarmEditMinute = 0;
static bool alarmEditPM = false;

// Repeat editor: 0=Everyday, 1=Weekdays, 2=Weekend, 3=Custom
static int alarmRepeatChoice = 0;
static int alarmCustomDay = 0;
static bool alarmCustomDays[7] = {true, true, true, true, true, true, true};

// ============================================================
// MAIN MENU SELECTION
// ============================================================

static int menuSelection =
    -1;

static bool menuSelectionActive =
    false;

static int menuRowOffset =
    0;

static int healthHistoryOffset =
    0;

// ============================================================
// MAIN MENU ICONS
// ============================================================

static const uint8_t icon_wellness[] PROGMEM = {
  0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x00,0x00,
  0x07,0x0e,0x00, 0x0f,0x9f,0x00, 0x0f,0xff,0x00, 0x0f,0xef,0x00,
  0x0d,0xef,0x00, 0x09,0xd7,0x00, 0x02,0x50,0x00, 0x07,0xbe,0x00,
  0x03,0xfc,0x00, 0x01,0xf8,0x00, 0x00,0xf0,0x00, 0x00,0x60,0x00,
  0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x00,0x00
};

static const uint8_t icon_breathing[] PROGMEM = {
  0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x00,0x00,
  0x00,0x00,0x00, 0x00,0x60,0x00, 0x00,0x60,0x00, 0x03,0x6c,0x00,
  0x06,0xf6,0x00, 0x0c,0xf3,0x00, 0x08,0xf1,0x00, 0x11,0xf8,0x80,
  0x13,0x9c,0x80, 0x16,0x96,0x80, 0x32,0x94,0xc0, 0x35,0x9a,0xc0,
  0x13,0x0c,0x80, 0x0c,0x07,0x80, 0x00,0x00,0x00, 0x00,0x00,0x00
};

static const uint8_t icon_goals[] PROGMEM = {
  0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x01,0x00,
  0x00,0x03,0x40, 0x01,0xe3,0xc0, 0x07,0xfb,0x80, 0x0e,0x0a,0x00,
  0x19,0xe4,0x00, 0x1b,0xea,0x00, 0x32,0x13,0x00, 0x36,0xab,0x00,
  0x36,0xcb,0x00, 0x32,0x1b,0x00, 0x13,0x33,0x00, 0x19,0xe6,0x00,
  0x0c,0x0c,0x00, 0x07,0xfc,0x00, 0x03,0xf0,0x00, 0x00,0x00,0x00
};

static const uint8_t icon_reminders[] PROGMEM = {
  0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x00,0x00,
  0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x61,0x00,
  0x08,0xf3,0x00, 0x05,0xfa,0x00, 0x13,0xfc,0x80, 0x03,0xfc,0x00,
  0x03,0xfc,0x00, 0x03,0xfc,0x00, 0x03,0xfc,0x00, 0x07,0xfe,0x00,
  0x0f,0xff,0x00, 0x00,0xf0,0x00, 0x00,0x60,0x00, 0x00,0x00,0x00
};

static const uint8_t icon_clock[] PROGMEM = {
  0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x00,0xf0, 0x03,0xfc,0x00,
  0x06,0x06,0x00, 0x0c,0x03,0x00, 0x08,0x61,0x00, 0x18,0x61,0x80,
  0x10,0x60,0x80, 0x10,0x70,0x80, 0x18,0x09,0x80, 0x08,0x01,0x00,
  0x0c,0x03,0x00, 0x06,0x06,0x00, 0x03,0x9c,0x00, 0x00,0xf0,0x00,
  0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x00,0x00
};

static const uint8_t icon_hr_history[] PROGMEM = {
  0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x00,0x00,
  0x06,0x18,0x00, 0x1d,0xe6,0x00, 0x30,0xc2,0x00, 0x30,0x03,0x00,
  0x21,0x01,0x00, 0x31,0xa3,0x00, 0x1e,0xba,0x00, 0x18,0xc4,0x40,
  0x0c,0x4c,0x40, 0x06,0x1b,0x40, 0x03,0x3f,0x40, 0x01,0xcf,0x40,
  0x00,0xcf,0x40, 0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x00,0x00
};

static const uint8_t icon_spo2_history[] PROGMEM = {
  0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x00, 0x00,0x01, 0xe0,0x00,
  0x03,0x70,0x00, 0x07,0x50,0x00, 0x07,0x98,0x00, 0x0f,0x4c,0x00,
  0x1f,0x04,0x00, 0x1f,0xee,0x00, 0x1f,0xea,0x00, 0x3f,0xfe,0x00,
  0x3f,0xfe,0x00, 0x3b,0x3b,0x00, 0x1a,0x1b,0x00, 0x0f,0x5b,0x00,
  0x07,0xff,0xc0, 0x03,0xff,0xc0, 0x00,0x00,0x80, 0x00,0x00,0x00
};

static const uint8_t icon_settings[] PROGMEM = {
  0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x60,0x00,
  0x00,0x60,0x00, 0x06,0xf6,0x00, 0x0f,0x8f,0x00, 0x06,0x06,0x00,
  0x06,0xf6,0x00, 0x1d,0xfb,0x80, 0x19,0xf9,0x80, 0x0c,0xf3,0x00,
  0x06,0x66,0x00, 0x0f,0x8f,0x00, 0x07,0xfe,0x00, 0x00,0xf0,0x00,
  0x00,0x60,0x00, 0x00,0x00,0x00, 0x00,0x00,0x00, 0x00,0x00,0x00
};

static const char* menuNames[] = {
  "Wellness", "Breathing", "Goals", "Reminders",
  "Clock", "HR History", "Settings"
};

static const uint8_t* menuIcons[] = {
  icon_wellness, icon_breathing, icon_goals, icon_reminders,
  icon_clock, icon_hr_history, icon_settings
};

static const DeviceScreen menuScreens[] = {
  SCR_WELLNESS, SCR_BREATHING, SCR_GOALS, SCR_REMINDERS,
  SCR_CLOCK, SCR_HR_HISTORY, SCR_SETTINGS
};

static const int MENU_ITEM_COUNT = 7;

// ============================================================
// REMINDER ON/OFF SELECTION
// ============================================================
// reminderSelection stores the position among USED reminders,
// not the raw array index, so deleted/unused slots are skipped.

static int reminderSelection =
    0;

static int reminderListOffset =
    0;

static bool reminderSelectionActive =
    false;

static int getReminderRawIndex(
    int position
) {

  int found =
      0;

  for (int i = 0; i < MAX_REMINDERS; i++) {

    const Reminder& r =
        reminders::get(i);

    if (!r.used) {
      continue;
    }

    if (found == position) {
      return i;
    }

    found++;
  }

  return -1;
}

// ============================================================
// STOPWATCH
// ============================================================

static bool stopwatchRunning =
    false;

static unsigned long stopwatchStartMs =
    0;

static unsigned long stopwatchElapsedMs =
    0;

// ============================================================
// TIMER EDIT STATE
// ============================================================

static bool timerEditMode =
    false;

static unsigned int timerEditHours =
    0;

static unsigned int timerEditMinutes =
    0;

static unsigned int timerEditSeconds =
    0;

// 0 = hours
// 1 = minutes
// 2 = seconds

static int timerEditField =
    2;

// 0 = -10
// 1 = -1
// 2 = +1
// 3 = +10

static int timerEditAction =
    0;


// Last successful 8-second heart-rate scan shown on HOME.
// This is intentionally separate from realtime BPM.
static int lastScannedBpm =
    0;


// ============================================================
// RENDER INTERVAL
// ============================================================

static const unsigned long
    RENDER_INTERVAL_MS =
        100;

// ============================================================
// SMALL HELPERS
// ============================================================

// ============================================================
// WI-FI STATUS BITMAPS — 23x23 MONOCHROME
// ============================================================

static const uint8_t icon_wifi_connected[] PROGMEM = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x38, 0x00, 0x00, 0xfe,
  0x00, 0x03, 0x83, 0x80, 0x06, 0x00, 0xc0, 0x00, 0x7e, 0x00, 0x01, 0x83, 0x00, 0x00, 0x38, 0x00, 0x00, 0x7c, 0x00, 0x00, 0x00, 0x00, 0x00,
  0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

static const uint8_t icon_wifi_disconnected[] PROGMEM = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7c, 0x00, 0x01, 0xc7,
  0x00, 0x03, 0x01, 0x80, 0x02, 0x7c, 0x80, 0x00, 0xc6, 0x00, 0x01, 0x82, 0x00, 0x00, 0x74, 0x80, 0x00, 0x23, 0x00, 0x00, 0x13, 0x00, 0x00,
  0x34, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

static const uint8_t icon_wifi_disabled[] PROGMEM = {
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7c, 0x80, 0x01, 0xc5,
  0x00, 0x03, 0x02, 0x80, 0x02, 0x74, 0x80, 0x00, 0xca, 0x00, 0x01, 0x93, 0x00, 0x00, 0x28, 0x00, 0x00, 0x4c, 0x00, 0x00, 0x90, 0x00, 0x00,
  0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
};

static void drawWiFiIcon(int wifiX = 88, int wifiY = -7) {

  const bool enabled = wifiManager::isEnabled();
  const bool connected = wifiManager::isConnected();
  const bool connecting = wifiManager::isConnecting();

  // IMPORTANT: keep the existing Wi-Fi bitmap artwork.
  // Only the position is shared between every state.
  // Connected is the reference position: 88, -7.
  //
  // Connecting uses the connected bitmap, so it naturally has the
  // exact same geometry and position.
  // Disconnected and disabled use their existing bitmaps at the
  // exact same top-left position as connected.
  // Use the requested position. The HOME screen passes (0, -7);
  // settings/header screens use the default (88, -7).
  const int x = wifiX;
  const int y = wifiY;

  if (!enabled) {
    oled.drawBitmap(
        x,
        y,
        icon_wifi_disabled,
        23,
        23,
        SSD1306_WHITE
    );
    return;
  }

  if (connecting) {
    if (((millis() / 350UL) % 2UL) == 0UL) {
      oled.drawBitmap(
          x,
          y,
          icon_wifi_connected,
          23,
          23,
          SSD1306_WHITE
      );
    }
    return;
  }

  if (connected) {
    oled.drawBitmap(
        x,
        y,
        icon_wifi_connected,
        23,
        23,
        SSD1306_WHITE
    );
    return;
  }

  oled.drawBitmap(
      x,
      y,
      icon_wifi_disconnected,
      23,
      23,
      SSD1306_WHITE
  );
}

static void drawBatteryIcon(bool drawWifi = true) {

  // Same battery icon used on the HOME screen.
  const int batteryX = 108;
  const int batteryY = 1;
  const int batteryW = 17;
  const int batteryH = 8;

  if (drawWifi) {
    drawWiFiIcon();
  }

  oled.drawRect(
      batteryX,
      batteryY,
      batteryW,
      batteryH,
      SSD1306_WHITE
  );

  oled.fillRect(
      batteryX + batteryW,
      batteryY + 2,
      2,
      4,
      SSD1306_WHITE
  );

  int batteryPercent =
      battery::getPercent();

  if (
      batteryPercent < 0
  ) {
    batteryPercent = 0;
  }

  if (
      batteryPercent > 100
  ) {
    batteryPercent = 100;
  }

  int batteryFill =
      (batteryW - 2) *
      batteryPercent /
      100;

  if (
      batteryFill > 0
  ) {
    oled.fillRect(
        batteryX + 1,
        batteryY + 1,
        batteryFill,
        batteryH - 2,
        SSD1306_WHITE
    );
  }

}


static void drawBatteryHeader(
    const char* title
) {

  oled.setTextSize(
      1
  );

  oled.setTextColor(
      SSD1306_WHITE
  );

  oled.setCursor(
      0,
      0
  );

  oled.print(
      title
  );

  drawBatteryIcon();

  oled.drawFastHLine(
      0,
      10,
      OLED_WIDTH,
      SSD1306_WHITE
  );
}

static void centerText(
    const char* text,
    int y,
    int textSize = 1
) {

  oled.setTextSize(
      textSize
  );

  int16_t x1;
  int16_t y1;

  uint16_t w;
  uint16_t h;

  oled.getTextBounds(
      text,
      0,
      0,
      &x1,
      &y1,
      &w,
      &h
  );

  oled.setCursor(
      (OLED_WIDTH - w) / 2,
      y
  );

  oled.print(
      text
  );
}

// ============================================================
// BOOT ANIMATION ASSETS & FUNCTIONS
// ============================================================

static const uint8_t castleBitmap[] PROGMEM = {
  0x00,0x00,0x00,0x00,0x00,0xC0,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0xB8,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x86,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x80,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x03,0x40,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x60,0x00,0x04,0x30,0x00,0x03,
  0x00,0x00,0x00,0x58,0x00,0x18,0x08,0x00,0x02,0xC0,
  0x00,0x00,0x00,0x46,0x00,0x20,0x04,0x00,0x02,0x30,
  0x00,0x00,0x00,0x40,0x00,0x40,0x03,0x00,0x02,0x00,
  0x00,0x00,0x00,0x40,0x0F,0xB8,0xE3,0x80,0x02,0x00,
  0x00,0x00,0x00,0xA0,0x0E,0x38,0xE3,0xC0,0x05,0x00,
  0x00,0x00,0x01,0x10,0x0E,0x38,0xE3,0xB0,0x08,0x80,
  0x00,0x02,0x08,0x1F,0xFF,0xFF,0xF8,0x10,0x40,0x00,
  0x00,0x04,0x04,0x10,0x00,0x00,0x08,0x20,0x20,0x00,
  0x00,0x08,0x02,0x10,0x00,0x00,0x08,0x40,0x10,0x00,
  0x00,0x71,0xC7,0x10,0x00,0x00,0x0B,0x8E,0x38,0x00,
  0x00,0x71,0xC7,0x90,0x00,0x00,0x0B,0x8E,0x3C,0x00,
  0x00,0x71,0xC7,0x50,0x00,0x00,0x0B,0x8E,0x3A,0x00,
  0x00,0xFF,0xFF,0xF1,0x00,0x00,0x0F,0xFF,0xFF,0x00,
  0x00,0x80,0x00,0x30,0x00,0x00,0x0C,0x00,0x01,0x00,
  0x00,0x80,0x00,0x30,0x00,0x00,0x4C,0x00,0x01,0x00,
  0x00,0x80,0x00,0x30,0x00,0x00,0x0C,0x00,0x01,0x00,
  0x00,0x87,0x0E,0x30,0x70,0x01,0xCC,0x70,0xE1,0x00,
  0x00,0x87,0x0E,0x30,0x70,0x01,0xCC,0x70,0xE1,0x00,
  0x00,0x87,0x0E,0x30,0x70,0x01,0xCC,0x70,0xE1,0x00,
  0x00,0x87,0x0E,0x30,0x70,0x01,0xCC,0x70,0xE1,0x00,
  0x00,0x87,0x0E,0x30,0x70,0x01,0xCC,0x70,0xE1,0x00,
  0x00,0x80,0x00,0x30,0x00,0x00,0x0C,0x00,0x01,0x00,
  0x00,0x80,0x02,0x30,0x00,0x00,0x0C,0x00,0x09,0x00,
  0x00,0x80,0x00,0x30,0x0F,0xF8,0x0C,0x00,0x01,0x00,
  0x00,0x80,0x00,0x30,0x08,0x08,0x0C,0x00,0x01,0x00,
  0x00,0x90,0x00,0x30,0x08,0x08,0x0C,0x00,0x01,0x00,
  0x00,0x80,0x00,0x30,0x08,0x08,0x0C,0x80,0x01,0x00,
  0x00,0x80,0x00,0x30,0x08,0x28,0x0C,0x00,0x01,0x00,
  0x00,0x80,0x00,0x34,0x08,0x08,0x0C,0x00,0x01,0x00,
  0x00,0x80,0x00,0x30,0x08,0x08,0x1C,0x00,0x01,0x00,
  0x00,0x80,0x00,0x30,0x08,0x08,0x0C,0x00,0x01,0x00,
  0x00,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x00,
  0x1F,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xF8
};

static const uint8_t firework1[] PROGMEM = {
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00
};

static const uint8_t firework2[] PROGMEM = {
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x01,0x00,0x01,0x00,0x01,0x00,
  0x0F,0xE0,0x01,0x00,0x01,0x00,0x01,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
};

static const uint8_t firework3[] PROGMEM = {
  0x00,0x00,0x00,0x00,0x00,0x00,0x01,0x00,
  0x05,0x40,0x01,0x00,0x0F,0xE0,0x01,0x00,
  0x05,0x40,0x01,0x00,0x00,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
};

static const uint8_t firework4[] PROGMEM = {
  0x00,0x00,0x00,0x00,0x01,0x00,0x10,0x10,
  0x05,0x40,0x01,0x00,0x2F,0xE8,0x01,0x00,
  0x05,0x40,0x10,0x10,0x01,0x00,0x00,0x00,
  0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
};

static void drawFireworkSprite(int x, int y, int frame) {
  const uint8_t* sprite;
  if (frame == 0) sprite = firework1;
  else if (frame == 1) sprite = firework2;
  else if (frame == 2) sprite = firework3;
  else sprite = firework4;

  oled.drawBitmap(x, y, sprite, 16, 16, SSD1306_WHITE);
}

// ============================================================
// STARTUP (Animated Boot Sequence - 3 Parts)
// ============================================================

static void drawStartup() {
  // Part 1: Initial "HEALTH DEVICE" Title
  oled.clearDisplay();
  oled.setTextColor(SSD1306_WHITE);
  oled.setTextSize(2);
  oled.setCursor(4, 20);
  oled.println("HEALTH");
  oled.setCursor(16, 40);
  oled.println("DEVICE");
  oled.display();
  delay(1500);
  yield();

  // Part 2: Animated Fireworks, Castle & Loading Bar
  unsigned long animStart = millis();
  const unsigned long animDuration = 4000;
  int animFrame = 0;

  while (millis() - animStart < animDuration) {
    unsigned long elapsed = millis() - animStart;
    yield();

    oled.clearDisplay();

    // Fireworks around the castle
    drawFireworkSprite(4, 4, animFrame);
    drawFireworkSprite(108, 3, (animFrame + 2) % 4);
    drawFireworkSprite(16, 24, (animFrame + 1) % 4);
    drawFireworkSprite(96, 25, (animFrame + 3) % 4);

    // Center Castle Bitmap
    oled.drawBitmap(24, 12, castleBitmap, 80, 40, SSD1306_WHITE);

    // Loading Label
    oled.setTextSize(1);
    oled.setTextColor(SSD1306_WHITE);
    oled.setCursor(4, 46);
    oled.print("LOADING");

    // Progress Bar Outline & Animated Fill
    oled.drawRect(4, 55, 120, 7, SSD1306_WHITE);
    int progressWidth = (int)((elapsed * 114UL) / animDuration);
    if (progressWidth > 114) progressWidth = 114;
    oled.fillRect(7, 57, progressWidth, 3, SSD1306_WHITE);

    oled.display();

    animFrame = (animFrame + 1) % 4;
    delay(140);
  }

  // Part 3: "HEALTH DEVICE" with Author "Shaurya Gupta"
  oled.clearDisplay();
  oled.setTextColor(SSD1306_WHITE);
  oled.setTextSize(2);
  oled.setCursor(4, 12);
  oled.println("HEALTH");
  oled.setCursor(16, 32);
  oled.println("DEVICE");
  oled.setTextSize(1);
  oled.setCursor(30, 54);
  oled.println("Shaurya Gupta");
  oled.display();
  delay(2000);
  yield();
}

// ============================================================
// HOME
// ============================================================

static void drawHome() {

  oled.clearDisplay();

  // ----------------------------------------------------------
  // TOP HEADER
  // ----------------------------------------------------------

  oled.setTextSize(
      1
  );

  oled.setTextColor(
      SSD1306_WHITE
  );

  // Center SMART HEALTH in the Home header.
  centerText(
      "SMART HEALTH",
      1,
      1
  );

  // Home Wi-Fi icon: use the space previously occupied by the heart.
  drawWiFiIcon(0, -7);

  // Battery icon (Wi-Fi already drawn at the Home position).
  drawBatteryIcon(false);



  // ----------------------------------------------------------
  // TIME
  // ----------------------------------------------------------

  String timeText =
      timeManager::formatTimeHHMM(
          settings::getUse24Hour()
      );

  centerText(
      timeText.c_str(),
      13,
      2
  );


  // ----------------------------------------------------------
  // DATE
  // ----------------------------------------------------------

  String dateText =
      timeManager::formatDateShort();

  centerText(
      dateText.c_str(),
      29,
      1
  );


  // ----------------------------------------------------------
  // DIVIDER
  // ----------------------------------------------------------

  oled.drawFastHLine(
      0,
      39,
      OLED_WIDTH,
      SSD1306_WHITE
  );


  // ----------------------------------------------------------
  // HEART RATE
  // ----------------------------------------------------------

  // Small heart icon
  oled.fillCircle(
      7,
      45,
      3,
      SSD1306_WHITE
  );

  oled.fillCircle(
      12,
      45,
      3,
      SSD1306_WHITE
  );

  oled.fillTriangle(
      4,
      46,
      15,
      46,
      9,
      53,
      SSD1306_WHITE
  );

  int bpm =
      lastScannedBpm;

  if (
      bpm < 0
  ) {
    bpm = 0;
  }

  oled.setTextSize(
      1
  );

  char bpmBuf[8];

  snprintf(
      bpmBuf,
      sizeof(bpmBuf),
      "%d",
      bpm
  );

  oled.setCursor(
      20,
      43
  );

  oled.print(
      bpmBuf
  );

  oled.print(
      " BPM"
  );

  oled.setCursor(
      20,
      55
  );

  oled.print("Steps ");
  oled.print(activity::getSteps());


  // ----------------------------------------------------------
  // CENTER DIVIDER
  // ----------------------------------------------------------

  oled.drawFastVLine(
      76,
      41,
      22,
      SSD1306_WHITE
  );


  // ----------------------------------------------------------
  // POSTURE
  // ----------------------------------------------------------

  // Use a very small bitmap font so the posture label has
  // more breathing room from the seated-person indicator.
  oled.setFont(&TomThumb);
  oled.setTextSize(1);
  oled.setTextColor(SSD1306_WHITE);

  oled.setCursor(
      82,
      48
  );

  oled.print(
      "POSTURE"
  );

  oled.setCursor(
      82,
      58
  );

  oled.print(
      posture::hasBaseline()
          ? (
              posture::isGood()
                  ? "GOOD"
                  : "BAD"
            )
          : "N/A"
  );

  oled.setFont();


  // ----------------------------------------------------------
  // SMALL POSTURE INDICATOR
  // ----------------------------------------------------------

  // Head
  oled.fillCircle(
      119,
      45,
      2,
      SSD1306_WHITE
  );

  // Body
  oled.drawFastVLine(
      119,
      48,
      8,
      SSD1306_WHITE
  );

  // Legs
  oled.drawLine(
      119,
      56,
      116,
      61,
      SSD1306_WHITE
  );

  oled.drawLine(
      119,
      56,
      123,
      61,
      SSD1306_WHITE
  );

  // Arms
  oled.drawLine(
      119,
      50,
      115,
      53,
      SSD1306_WHITE
  );

  oled.drawLine(
      119,
      50,
      123,
      53,
      SSD1306_WHITE
  );


  oled.display();
}

// ============================================================
// HEART RATE — MODE 1 IDLE
// ============================================================

static void drawHeartRateIdle() {

  oled.clearDisplay();

  drawBatteryHeader(
      "HEART RATE"
  );

  centerText(
      "-- BPM",
      22,
      1
  );

  centerText(
      "PLACE FINGER",
      40,
      1
  );

  centerText(
      "TO SCAN",
      52,
      1
  );

  oled.display();
}

// ============================================================
// HEART RATE — MODE 1 SCANNING
// ============================================================

static void drawHeartRateScanning() {

  oled.clearDisplay();

  drawBatteryHeader(
      "HEART RATE"
  );

  int offset =
      (millis() / 60) %
      OLED_WIDTH;

  int midY =
      36;

  int prevX =
      0;

  int prevY =
      midY;

  for (
      int x = 0;
      x < OLED_WIDTH;
      x++
  ) {

    int phase =
        (x + offset) %
        24;

    int y =
        midY;

    if (
        phase < 4
    ) {

      y =
          midY -
          phase * 4;
    }

    else if (
        phase < 8
    ) {

      y =
          midY -
          (8 - phase) * 4;
    }

    else if (
        phase < 12
    ) {

      y =
          midY +
          (phase - 8) * 2;
    }

    else {

      y =
          midY;
    }

    if (
        x > 0
    ) {

      oled.drawLine(
          prevX,
          prevY,
          x,
          y,
          SSD1306_WHITE
      );
    }

    prevX =
        x;

    prevY =
        y;
  }

  oled.display();
}

// ============================================================
// LIVE VITALS — REAL-TIME BPM + SpO2
// ============================================================

static void drawHeartRateRealtime() {

  oled.clearDisplay();

  // Real-time screen contains both continuously updated vitals.
  drawBatteryHeader(
      "LIVE VITALS"
  );

  int bpm =
      hrSensor::getRealtimeBPM();

  // ----------------------------------------------------------
  // HEART RATE
  // ----------------------------------------------------------

  oled.setTextSize(1);
  oled.setCursor(4, 17);
  oled.print("HEART RATE");

  if (bpm > 0) {

    char bpmBuf[12];

    snprintf(
        bpmBuf,
        sizeof(bpmBuf),
        "%d BPM",
        bpm
    );

    // Keep the BPM value compact so 3-digit values (e.g. 120 BPM)
    // never cross into the SpO2 column.
    oled.setTextSize(1);
    oled.setCursor(4, 30);
    oled.print(bpmBuf);

    oled.setTextSize(1);
    oled.setCursor(4, 47);
    oled.print(
        bpm >= HR_HIGH_BPM
            ? "HIGH"
            : "NORMAL"
    );
  }
  else {

    // Keep the placeholder the same compact size as a real BPM value.
    oled.setTextSize(1);
    oled.setCursor(4, 30);
    oled.print("-- BPM");

    oled.setTextSize(1);
    oled.setCursor(4, 47);
    oled.print("PLACE FINGER");
  }

  // ----------------------------------------------------------
  // DIVIDER
  // ----------------------------------------------------------

  oled.drawFastVLine(
      76,
      17,
      43,
      SSD1306_WHITE
  );

  // ----------------------------------------------------------
  // SpO2
  // ----------------------------------------------------------

  oled.setTextSize(1);
  oled.setCursor(84, 17);
  oled.print("SpO2");

  if (hrSensor::isSpO2Valid()) {

    char spo2Buf[10];

    snprintf(
        spo2Buf,
        sizeof(spo2Buf),
        "%d%%",
        hrSensor::getSpO2()
    );

    oled.setTextSize(2);
    oled.setCursor(84, 28);
    oled.print(spo2Buf);

    oled.setTextSize(1);
    oled.setCursor(84, 47);
    oled.print("OXYGEN");
  }
  else {

    oled.setTextSize(2);
    oled.setCursor(84, 28);
    oled.print("--%");

    oled.setTextSize(1);
    oled.setCursor(84, 47);

    if (hrSensor::isFingerDetected()) {
      oled.print("MEASURING");
    }
    else {
      oled.print("FINGER");
    }
  }

  // ----------------------------------------------------------
  // LIVE ECG-STYLE PULSE WAVE
  // ----------------------------------------------------------

  int offset =
      (millis() / 55) % 24;

  int midY =
      57;

  int prevX =
      0;

  int prevY =
      midY;

  for (
      int x = 0;
      x < OLED_WIDTH;
      x++
  ) {

    int phase =
        (x + offset) % 24;

    int y =
        midY;

    if (phase < 4) {
      y = midY - phase * 2;
    }
    else if (phase < 8) {
      y = midY - (8 - phase) * 2;
    }
    else if (phase < 12) {
      y = midY + (phase - 8);
    }

    if (x > 0) {
      oled.drawLine(
          prevX,
          prevY,
          x,
          y,
          SSD1306_WHITE
      );
    }

    prevX = x;
    prevY = y;
  }

  oled.display();
}

// ============================================================
// HEART RATE — RESULT
// ============================================================

static void drawHeartRateResult() {

  // Capture the successful scan before the HR result can be
  // cleared when leaving the Heart Rate screen.
  int scannedBpm =
      hrSensor::getResultBPM();

  if (
      scannedBpm > 0
  ) {

    lastScannedBpm =
        scannedBpm;
  }

  oled.clearDisplay();

  drawBatteryHeader(
      "HEART RATE"
  );

  char buf[16];

  snprintf(
      buf,
      sizeof(buf),
      "%d BPM",
      hrSensor::getResultBPM()
  );

  centerText(
      buf,
      20,
      2
  );

  centerText(
      hrSensor::getResultBPM() >=
          HR_HIGH_BPM
          ? "HIGH"
          : "NORMAL",
      42,
      1
  );

  centerText(
      "NORMAL<120 HIGH>=120",
      56,
      1
  );

  oled.display();
}

// ============================================================
// HEART RATE — FAILED
// ============================================================

static void drawHeartRateFailed() {

  oled.clearDisplay();

  drawBatteryHeader(
      "HEART RATE"
  );

  centerText(
      "NO RESULT",
      26,
      1
  );

  centerText(
      "TRY AGAIN",
      40,
      1
  );

  oled.display();
}

// ============================================================
// HEALTH HISTORY LISTS
// ============================================================

static const char* heartRateStatus(int bpm) {
  if (bpm < 60) return "LOW";
  if (bpm >= HR_HIGH_BPM) return "H";
  return "N";
}

static const char* spo2Status(int value) {
  if (value < 95) return "L";
  return "N";
}

static void drawHealthHistoryList(bool spo2) {

  oled.clearDisplay();

  drawBatteryHeader(
      spo2 ? "SPO2 HISTORY" : "HR HISTORY"
  );

  healthHistory::Record recs[
      healthHistory::MAX_RECORDS
  ];

  int n = spo2
      ? healthHistory::getSpO2(recs, healthHistory::MAX_RECORDS)
      : healthHistory::getHeartRate(recs, healthHistory::MAX_RECORDS);

  if (n == 0) {
    centerText(
        "NO HISTORY YET",
        30,
        1
    );
    oled.display();
    return;
  }

  int maxOffset = n > 4 ? n - 4 : 0;
  int offset = constrain(
      healthHistoryOffset,
      0,
      maxOffset
  );

  for (int row = 0; row < 4; ++row) {
    int index = offset + row;
    if (index >= n) break;

    const healthHistory::Record& r = recs[index];

    char dateTime[20];
    snprintf(
        dateTime,
        sizeof(dateTime),
        "%02u/%02u %02u:%02u",
        (unsigned)r.day,
        (unsigned)r.month,
        (unsigned)r.hour,
        (unsigned)r.minute
    );

    char valueText[10];
    char statusText[8];

    if (spo2) {
      snprintf(valueText, sizeof(valueText), "%u%%", (unsigned)r.value);
      snprintf(statusText, sizeof(statusText), "%s", spo2Status(r.value));
    }
    else {
      snprintf(valueText, sizeof(valueText), "%u", (unsigned)r.value);
      snprintf(statusText, sizeof(statusText), "%s", heartRateStatus(r.value));
    }

    int y = 14 + row * 11;

    // History rows use the smallest readable OLED font so 3-digit
    // values and the status never run into each other.
    oled.setTextSize(1);

    oled.setCursor(0, y);
    oled.print(dateTime);

    oled.setCursor(70, y);
    oled.print(valueText);

    oled.setCursor(108, y);
    oled.print(statusText);
  }

  if (maxOffset > 0) {
    oled.drawFastHLine(0, 59, 118, SSD1306_WHITE);
    oled.setCursor(120, 57);
    oled.print("v");
  }

  oled.display();
}

static void drawHRHistory() {
  drawHealthHistoryList(false);
}

static void drawSpO2History() {
  drawHealthHistoryList(true);
}


// ============================================================
// POSTURE SETUP
// ============================================================

static void drawPostureSetup() {

  oled.clearDisplay();

  drawBatteryIcon();

  centerText(
      "POSTURE SETUP",
      4,
      1
  );

  centerText(
      "SIT UPRIGHT",
      22,
      1
  );

  centerText(
      "HOLD STILL",
      34,
      1
  );

  centerText(
      "PRESS TO START",
      50,
      1
  );

  oled.display();
}

// ============================================================
// POSTURE CALIBRATING
// ============================================================

static void drawPostureCalibrating() {

  oled.clearDisplay();

  drawBatteryIcon();

  centerText(
      "CALIBRATING",
      4,
      1
  );

  centerText(
      "SIT UPRIGHT",
      18,
      1
  );

  int pct =
      posture::getCalibrationPercent();

  int barW =
      (OLED_WIDTH - 20) *
      pct /
      100;

  oled.drawRect(
      10,
      32,
      OLED_WIDTH - 20,
      8,
      SSD1306_WHITE
  );

  oled.fillRect(
      10,
      32,
      barW,
      8,
      SSD1306_WHITE
  );

  centerText(
      "HOLD STILL",
      48,
      1
  );

  oled.display();
}

// ============================================================
// POSTURE CALIBRATED
// ============================================================

static void drawPostureCalibrated() {

  oled.clearDisplay();

  drawBatteryIcon();

  centerText(
      "CALIBRATED",
      20,
      1
  );

  centerText(
      "BASELINE SAVED",
      36,
      1
  );

  oled.display();
}

// ============================================================
// POSTURE
// ============================================================

static void drawPosture() {

  oled.clearDisplay();

  drawBatteryHeader(
      "POSTURE"
  );

  // ----------------------------------------------------------
  // NO BASELINE
  // ----------------------------------------------------------

  if (
      !posture::hasBaseline()
  ) {

    // Keep the left area empty for the posture bitmap that will
    // be added later.
    oled.drawFastVLine(
        30,
        14,
        42,
        SSD1306_WHITE
    );

    oled.setTextSize(
        1
    );

    oled.setCursor(
        40,
        22
    );

    oled.print(
        "NOT CALIBRATED"
    );

    oled.setCursor(
        40,
        38
    );

    oled.print(
        "LONG PRESS"
    );

    oled.setCursor(
        40,
        49
    );

    oled.print(
        "TO SETUP"
    );

    oled.display();

    return;
  }

  // ----------------------------------------------------------
  // LIVE POSTURE UI
  // ----------------------------------------------------------
  //
  // Left side is intentionally left empty for the bitmap that
  // will be added later. The live data uses the full right side.
  // ----------------------------------------------------------

  oled.drawFastVLine(
      30,
      14,
      42,
      SSD1306_WHITE
  );

  const bool good =
      posture::isGood();

  const float tilt =
      posture::getDeviationDeg();

  // ----------------------------------------------------------
  // STATUS
  // ----------------------------------------------------------

  oled.setTextSize(
      2
  );

  oled.setTextColor(
      SSD1306_WHITE
  );

  if (
      good
  ) {

    oled.setCursor(
        48,
        15
    );

    oled.print(
        "GOOD"
    );
  }

  else {

    oled.setCursor(
        52,
        15
    );

    oled.print(
        "BAD"
    );
  }

  // ----------------------------------------------------------
  // LIVE TILT
  // ----------------------------------------------------------

  char tiltBuf[16];

  snprintf(
      tiltBuf,
      sizeof(tiltBuf),
      "TILT %.0f deg",
      tilt
  );

  oled.setTextSize(
      1
  );

  oled.setCursor(
      45,
      33
  );

  oled.print(
      tiltBuf
  );

  // ----------------------------------------------------------
  // POSITION BAR
  // ----------------------------------------------------------

  const int barX =
      38;

  const int barY =
      45;

  const int barW =
      84;

  oled.drawFastHLine(
      barX,
      barY,
      barW,
      SSD1306_WHITE
  );

  float sensitivity =
      posture::getSensitivity();

  if (
      sensitivity < 1.0f
  ) {

    sensitivity =
        1.0f;
  }

  float maxTilt =
      sensitivity * 2.0f;

  float ratio =
      tilt / maxTilt;

  if (
      ratio < 0.0f
  ) {

    ratio =
        0.0f;
  }

  if (
      ratio > 1.0f
  ) {

    ratio =
        1.0f;
  }

  int markerX =
      barX +
      (int)(ratio * (barW - 1));

  oled.drawFastVLine(
      markerX,
      barY - 3,
      7,
      SSD1306_WHITE
  );

  // Threshold marker.
  int thresholdX =
      barX +
      (int)(0.5f * (barW - 1));

  oled.drawFastVLine(
      thresholdX,
      barY - 2,
      5,
      SSD1306_WHITE
  );

  // ----------------------------------------------------------
  // BAR LABELS
  // ----------------------------------------------------------

  oled.setTextSize(
      1
  );

  oled.setCursor(
      38,
      51
  );

  oled.print(
      "GOOD"
  );

  oled.setCursor(
      99,
      51
  );

  oled.print(
      "BAD"
  );

  oled.display();
}

// ============================================================
// ACTIVITY
// ============================================================

static void drawActivityStepsIcon(int x, int y) {

  // Small two-footprint icon.
  oled.fillCircle(x + 3, y + 3, 2, SSD1306_WHITE);
  oled.fillRoundRect(x + 1, y + 6, 5, 7, 2, SSD1306_WHITE);
  oled.fillCircle(x + 10, y + 2, 2, SSD1306_WHITE);
  oled.fillRoundRect(x + 8, y + 5, 5, 7, 2, SSD1306_WHITE);
}

static void drawActivityDistanceIcon(int x, int y) {

  // Small location pin icon.
  oled.drawCircle(x + 6, y + 4, 5, SSD1306_WHITE);
  oled.fillCircle(x + 6, y + 4, 2, SSD1306_WHITE);
  oled.drawLine(x + 2, y + 8, x + 6, y + 13, SSD1306_WHITE);
  oled.drawLine(x + 10, y + 8, x + 6, y + 13, SSD1306_WHITE);
}

static void drawActivityCaloriesIcon(int x, int y) {

  // Small flame icon.
  oled.drawLine(x + 6, y + 1, x + 3, y + 6, SSD1306_WHITE);
  oled.drawLine(x + 3, y + 6, x + 2, y + 10, SSD1306_WHITE);
  oled.drawLine(x + 2, y + 10, x + 5, y + 13, SSD1306_WHITE);
  oled.drawLine(x + 5, y + 13, x + 9, y + 13, SSD1306_WHITE);
  oled.drawLine(x + 9, y + 13, x + 12, y + 10, SSD1306_WHITE);
  oled.drawLine(x + 12, y + 10, x + 11, y + 6, SSD1306_WHITE);
  oled.drawLine(x + 11, y + 6, x + 8, y + 8, SSD1306_WHITE);
  oled.drawLine(x + 8, y + 8, x + 9, y + 3, SSD1306_WHITE);
  oled.drawLine(x + 9, y + 3, x + 6, y + 1, SSD1306_WHITE);
  oled.drawLine(x + 6, y + 6, x + 5, y + 9, SSD1306_WHITE);
  oled.drawLine(x + 5, y + 9, x + 7, y + 11, SSD1306_WHITE);
  oled.drawLine(x + 7, y + 11, x + 9, y + 9, SSD1306_WHITE);
}

static void drawActivityRightValue(const char* value, int y) {

  oled.setTextSize(1);

  int16_t x1;
  int16_t y1;
  uint16_t w;
  uint16_t h;

  oled.getTextBounds(
      value,
      0,
      0,
      &x1,
      &y1,
      &w,
      &h
  );

  oled.setCursor(
      OLED_WIDTH - 2 - w,
      y
  );

  oled.print(value);
}

static void drawActivity() {

  oled.clearDisplay();

  drawBatteryHeader(
      "ACTIVITY"
  );

  // ============================================================
  // STEPS
  // ============================================================

  drawActivityStepsIcon(
      2,
      17
  );

  oled.setTextSize(1);
  oled.setCursor(20, 18);
  oled.print("STEPS");

  char stepBuf[16];

  snprintf(
      stepBuf,
      sizeof(stepBuf),
      "%lu",
      activity::getSteps()
  );

  drawActivityRightValue(
      stepBuf,
      18
  );

  // ============================================================
  // DISTANCE
  // ============================================================

  drawActivityDistanceIcon(
      2,
      31
  );

  oled.setCursor(20, 32);
  oled.print("DISTANCE");

  char distanceBuf[20];

  snprintf(
      distanceBuf,
      sizeof(distanceBuf),
      "%.2f km",
      activity::getDistanceKm()
  );

  drawActivityRightValue(
      distanceBuf,
      32
  );

  // ============================================================
  // CALORIES
  // ============================================================

  drawActivityCaloriesIcon(
      2,
      45
  );

  oled.setCursor(20, 46);
  oled.print("CALORIES");

  char calorieBuf[20];

  snprintf(
      calorieBuf,
      sizeof(calorieBuf),
      "%lu kcal",
      activity::getCalories()
  );

  drawActivityRightValue(
      calorieBuf,
      46
  );

  // ============================================================
  // BOTTOM DOTTED LINE
  // ============================================================

  for (
      int x = 14;
      x < OLED_WIDTH - 8;
      x += 4
  ) {
    oled.drawPixel(
        x,
        61,
        SSD1306_WHITE
    );
  }

  oled.display();
}

// ============================================================
// WELLNESS DASHBOARD
// ============================================================
// Simple daily dashboard. Goals/score/streaks have their own screen.
// Fall and inactivity detection run automatically in the background.
// ============================================================

static void drawWellness() {

  oled.clearDisplay();

  drawBatteryHeader(
      "WELLNESS"
  );

  oled.setCursor(
      0,
      15
  );
  oled.print("WATER");

  oled.setCursor(
      0,
      27
  );
  oled.print(wellness::getWaterCups());
  oled.print(" / ");
  oled.print(wellness::getWaterGoal());
  oled.print(" CUPS");

  oled.setCursor(
      72,
      15
  );
  oled.print("MOVE");

  oled.setCursor(
      72,
      27
  );
  oled.print(wellness::getDailyActiveMinutes());
  oled.print("/");
  oled.print(ACTIVITY_ACTIVE_MIN_GOAL);
  oled.print("m");

  oled.drawFastHLine(
      0,
      35,
      OLED_WIDTH,
      SSD1306_WHITE
  );

  oled.setCursor(
      0,
      42
  );
  oled.print("STEPS");

  oled.setCursor(
      72,
      42
  );
  oled.print(wellness::getDailySteps());

  oled.setCursor(
      0,
      56
  );

  if (wellness::waterReminderPending()) {
    oled.print("WATER DUE");
  }
  else if (wellness::isInactive()) {
    oled.print("MOVE BREAK");
  }
  else {
    oled.print("DBL = +1 CUP");
  }

  oled.display();
}

// ============================================================
// BREATHING EXERCISE
// ============================================================

static void drawBreathing() {

  oled.clearDisplay();

  drawBatteryHeader(
      "BREATHING"
  );

  centerText(
      wellness::getBreathingPhase(),
      17,
      2
  );

  int percent =
      wellness::getBreathingPhasePercent();

  oled.drawRect(
      10,
      38,
      OLED_WIDTH - 20,
      8,
      SSD1306_WHITE
  );

  if (percent > 0) {
    int fill =
        (OLED_WIDTH - 22) * percent / 100;

    oled.fillRect(
        11,
        39,
        fill,
        6,
        SSD1306_WHITE
    );
  }

  centerText(
      wellness::isBreathing()
          ? "LONG = STOP"
          : "LONG = START",
      52,
      1
  );

  oled.display();
}

// ============================================================
// GOALS / STREAKS / ACHIEVEMENTS
// ============================================================

static void drawGoals() {

  oled.clearDisplay();

  drawBatteryHeader(
      "GOALS"
  );

  oled.setCursor(
      0,
      16
  );

  oled.print("STP ");
  oled.print(wellness::getDailySteps());
  oled.print("/");
  oled.print(ACTIVITY_STEP_GOAL);

  oled.setCursor(
      0,
      27
  );

  oled.print("ACT ");
  oled.print(wellness::getDailyActiveMinutes());
  oled.print("/");
  oled.print(ACTIVITY_ACTIVE_MIN_GOAL);
  oled.print("m");

  oled.setCursor(
      0,
      38
  );

  oled.print("WTR ");
  oled.print(wellness::getWaterCups());
  oled.print("/");
  oled.print(wellness::getWaterGoal());

  oled.setCursor(
      74,
      16
  );

  oled.print("SCORE ");
  oled.print(wellness::getActivityScore());

  oled.setCursor(
      74,
      27
  );

  oled.print("STREAK ");
  oled.print(wellness::getStreak());

  oled.setCursor(
      74,
      38
  );

  oled.print("ACH ");
  oled.print(wellness::getAchievementCount());
  oled.print("/6");

  oled.drawFastHLine(
      0,
      47,
      OLED_WIDTH,
      SSD1306_WHITE
  );

  centerText(
      wellness::allDailyGoalsMet()
          ? "ALL GOALS MET"
          : "KEEP GOING",
      53,
      1
  );

  oled.display();
}


// ============================================================
// CLOCK SECTION CODED LOGOS
// ============================================================
//
// Four compact custom icons:
// CLOCK      = clock face
// TIMER      = hourglass
// STOPWATCH  = stopwatch
// ALARM      = alarm clock
//
// Drawn directly with Adafruit GFX primitives.
// NO BITMAPS.
// ============================================================

static void drawClockIcon(
    int cx,
    int cy,
    int mode,
    bool selected
) {

  const int boxW =
      15;

  const int boxH =
      14;

  int boxX =
      cx -
      boxW / 2;

  int boxY =
      cy -
      boxH / 2;

  // ----------------------------------------------------------
  // Selected background
  // ----------------------------------------------------------

  if (
      selected
  ) {

    oled.fillRoundRect(
        boxX,
        boxY,
        boxW,
        boxH,
        2,
        SSD1306_WHITE
    );
  }

  uint16_t fg =
      selected
          ? SSD1306_BLACK
          : SSD1306_WHITE;

  // ----------------------------------------------------------
  // CLOCK
  // ----------------------------------------------------------

  if (
      mode == 0
  ) {

    oled.drawCircle(
        cx,
        cy,
        5,
        fg
    );

    oled.drawLine(
        cx,
        cy,
        cx,
        cy - 3,
        fg
    );

    oled.drawLine(
        cx,
        cy,
        cx + 3,
        cy + 2,
        fg
    );
  }

  // ----------------------------------------------------------
  // TIMER / HOURGLASS
  // ----------------------------------------------------------

  else if (
      mode == 1
  ) {

    oled.drawLine(
        cx - 4,
        cy - 5,
        cx + 4,
        cy - 5,
        fg
    );

    oled.drawLine(
        cx - 4,
        cy + 5,
        cx + 4,
        cy + 5,
        fg
    );

    oled.drawLine(
        cx - 4,
        cy - 5,
        cx + 4,
        cy + 5,
        fg
    );

    oled.drawLine(
        cx + 4,
        cy - 5,
        cx - 4,
        cy + 5,
        fg
    );

    oled.drawFastHLine(
        cx - 2,
        cy - 1,
        5,
        fg
    );
  }

  // ----------------------------------------------------------
  // STOPWATCH
  // ----------------------------------------------------------

  else if (
      mode == 2
  ) {

    oled.drawCircle(
        cx,
        cy + 1,
        5,
        fg
    );

    oled.drawLine(
        cx,
        cy + 1,
        cx,
        cy - 2,
        fg
    );

    oled.drawLine(
        cx,
        cy + 1,
        cx + 2,
        cy + 2,
        fg
    );

    oled.drawFastHLine(
        cx - 2,
        cy - 6,
        5,
        fg
    );

    oled.drawLine(
        cx + 3,
        cy - 4,
        cx + 5,
        cy - 6,
        fg
    );
  }

  // ----------------------------------------------------------
  // ALARM
  // ----------------------------------------------------------

  else {

    oled.drawCircle(
        cx,
        cy + 1,
        4,
        fg
    );

    oled.drawLine(
        cx,
        cy + 1,
        cx,
        cy - 2,
        fg
    );

    oled.drawLine(
        cx,
        cy + 1,
        cx + 2,
        cy + 2,
        fg
    );

    oled.drawLine(
        cx - 4,
        cy - 4,
        cx - 6,
        cy - 6,
        fg
    );

    oled.drawLine(
        cx + 4,
        cy - 4,
        cx + 6,
        cy - 6,
        fg
    );

    oled.drawFastHLine(
        cx - 2,
        cy + 6,
        5,
        fg
    );
  }
}

// ============================================================
// CLOCK MODE NAME
// ============================================================

static const char* getClockModeName() {

  switch (
      clockMode
  ) {

    case 1:

      return "TIMER";

    case 2:

      return "STOPWATCH";

    case 3:

      return "ALARM";

    default:

      return "CLOCK";
  }
}

// ============================================================
// CLOCK ICON BAR
// ============================================================

static void drawClockTabs() {

  const int positions[4] = {

      15,
      47,
      79,
      111
  };

  for (
      int i = 0;
      i < 4;
      i++
  ) {

    drawClockIcon(
        positions[i],
        19,
        i,
        clockMode == i
    );
  }

  // Selected underline

  int underlineX =
      positions[clockMode] -
      7;

  oled.fillRect(
      underlineX,
      29,
      15,
      2,
      SSD1306_WHITE
  );
}

// ============================================================
// CLOCK
// ============================================================

static void drawClock() {

  oled.clearDisplay();

  drawBatteryHeader(
      getClockModeName()
  );

  drawClockTabs();

  String timeText =
      timeManager::formatTimeHHMM(
          settings::getUse24Hour()
      );

  String dateText =
      timeManager::formatDateShort();

  centerText(
      timeText.c_str(),
      38,
      2
  );

  centerText(
      dateText.c_str(),
      55,
      1
  );

  oled.display();
}

// ============================================================
// CLOCK TIMER
// ============================================================

static void drawClockTimer() {

  oled.clearDisplay();

  drawBatteryHeader(
      getClockModeName()
  );

  drawClockTabs();

  // ----------------------------------------------------------
  // TIMER EDIT MODE
  // ----------------------------------------------------------

  if (
      timerEditMode
  ) {

    char hoursBuf[3];

    char minutesBuf[3];

    char secondsBuf[3];

    snprintf(
        hoursBuf,
        sizeof(hoursBuf),
        "%02u",
        timerEditHours
    );

    snprintf(
        minutesBuf,
        sizeof(minutesBuf),
        "%02u",
        timerEditMinutes
    );

    snprintf(
        secondsBuf,
        sizeof(secondsBuf),
        "%02u",
        timerEditSeconds
    );

    // Smaller timer display.
    // This leaves room for the four adjustment controls.

    const int hoursX =
        16;

    const int minutesX =
        52;

    const int secondsX =
        88;

    const int timeY =
        32;

    int selectedX =
        timerEditField == 0
            ? hoursX
            : (
                timerEditField == 1
                    ? minutesX
                    : secondsX
              );

    // Selected time field.

    oled.fillRoundRect(
        selectedX - 2,
        timeY - 2,
        28,
        19,
        2,
        SSD1306_WHITE
    );

    oled.setTextSize(
        2
    );

    // HOURS

    oled.setTextColor(
        timerEditField == 0
            ? SSD1306_BLACK
            : SSD1306_WHITE
    );

    oled.setCursor(
        hoursX,
        timeY
    );

    oled.print(
        hoursBuf
    );

    // FIRST COLON

    oled.setTextColor(
        SSD1306_WHITE
    );

    oled.setCursor(
        42,
        timeY
    );

    oled.print(
        ":"
    );

    // MINUTES

    oled.setTextColor(
        timerEditField == 1
            ? SSD1306_BLACK
            : SSD1306_WHITE
    );

    oled.setCursor(
        minutesX,
        timeY
    );

    oled.print(
        minutesBuf
    );

    // SECOND COLON

    oled.setTextColor(
        SSD1306_WHITE
    );

    oled.setCursor(
        78,
        timeY
    );

    oled.print(
        ":"
    );

    // SECONDS

    oled.setTextColor(
        timerEditField == 2
            ? SSD1306_BLACK
            : SSD1306_WHITE
    );

    oled.setCursor(
        secondsX,
        timeY
    );

    oled.print(
        secondsBuf
    );

    // --------------------------------------------------------
    // -10 / -1 / +1 / +10 ACTION SELECTOR
    // --------------------------------------------------------

    const char* actionLabels[4] = {

        "-10",
        "-1",
        "+1",
        "+10"
    };

    const int actionX[4] = {

        0,
        32,
        64,
        96
    };

    const int actionY =
        51;

    const int actionW =
        32;

    const int actionH =
        12;

    for (
        int i = 0;
        i < 4;
        i++
    ) {

      if (
          i ==
          timerEditAction
      ) {

        oled.fillRoundRect(
            actionX[i],
            actionY,
            actionW,
            actionH,
            2,
            SSD1306_WHITE
        );

        oled.setTextColor(
            SSD1306_BLACK
        );
      }

      else {

        oled.drawRoundRect(
            actionX[i],
            actionY,
            actionW,
            actionH,
            2,
            SSD1306_WHITE
        );

        oled.setTextColor(
            SSD1306_WHITE
        );
      }

      oled.setTextSize(
          1
      );

      int16_t x1;
      int16_t y1;

      uint16_t w;
      uint16_t h;

      oled.getTextBounds(
          actionLabels[i],
          0,
          0,
          &x1,
          &y1,
          &w,
          &h
      );

      oled.setCursor(
          actionX[i] +
              (actionW - w) / 2,
          actionY +
              (actionH - h) / 2 -
              1
      );

      oled.print(
          actionLabels[i]
      );
    }

    oled.setTextColor(
        SSD1306_WHITE
    );

    oled.display();

    return;
  }

  // ----------------------------------------------------------
  // NORMAL TIMER MODE
  // ----------------------------------------------------------

  if (
      healthTimer::isFinished()
  ) {

    centerText(
        "00:00",
        37,
        2
    );

    centerText(
        "DONE",
        56,
        1
    );
  }

  else {

    unsigned long rem =
        healthTimer::getRemainingSeconds();

    char buf[8];

    snprintf(
        buf,
        sizeof(buf),
        "%02lu:%02lu",
        rem / 60,
        rem % 60
    );

    centerText(
        buf,
        37,
        2
    );

    centerText(
        healthTimer::isRunning()
            ? "RUNNING"
            : "PAUSED",
        56,
        1
    );
  }

  oled.display();
}

// ============================================================
// CLOCK STOPWATCH
// ============================================================

static unsigned long getStopwatchElapsedMs() {

  if (
      stopwatchRunning
  ) {

    return stopwatchElapsedMs +
           (
               millis() -
               stopwatchStartMs
           );
  }

  return stopwatchElapsedMs;
}

static void drawClockStopwatch() {

  oled.clearDisplay();

  drawBatteryHeader(
      getClockModeName()
  );

  drawClockTabs();

  unsigned long elapsed =
      getStopwatchElapsedMs();

  unsigned long totalSeconds =
      elapsed /
      1000UL;

  unsigned int minutes =
      totalSeconds /
      60UL;

  unsigned int seconds =
      totalSeconds %
      60UL;

  char buf[12];

  snprintf(
      buf,
      sizeof(buf),
      "%02u:%02u",
      minutes,
      seconds
  );

  centerText(
      buf,
      37,
      2
  );

  centerText(
      stopwatchRunning
          ? "RUNNING"
          : "STOPPED",
      56,
      1
  );

  oled.display();
}

// ============================================================
// CLOCK ALARM
// ============================================================

static void drawClockAlarm() {

  oled.clearDisplay();

  drawBatteryHeader(
      getClockModeName()
  );

  drawClockTabs();

  int n =
      alarms::count();

  if (
      n == 0
  ) {

    centerText(
        "NO ALARMS",
        40,
        1
    );
  }

  else {

    int shown =
        0;

    for (
        int i = 0;
        i < MAX_ALARMS &&
        shown < 2;
        i++
    ) {

      const Alarm& a =
          alarms::get(i);

      if (
          !a.used
      ) {

        continue;
      }

      char buf[12];

      snprintf(
          buf,
          sizeof(buf),
          "%02d:%02d %s",
          a.hour,
          a.minute,
          a.enabled
              ? "ON"
              : "OFF"
      );

      centerText(
          buf,
          37 + shown * 12,
          1
      );

      shown++;
    }
  }

  oled.display();
}

// ============================================================
// TIMER
// ============================================================

static void drawTimer() {

  oled.clearDisplay();

  drawBatteryHeader(
      "TIMER"
  );

  unsigned long rem =
      healthTimer::getRemainingSeconds();

  char buf[8];

  snprintf(
      buf,
      sizeof(buf),
      "%02lu:%02lu",
      rem / 60,
      rem % 60
  );

  centerText(
      buf,
      20,
      2
  );

  centerText(
      healthTimer::isRunning()
          ? "RUNNING"
          : "PAUSED",
      44,
      1
  );

  centerText(
      "HOLD=START/PAUSE DBL=RESET",
      56,
      1
  );

  oled.display();
}

// ============================================================
// FALL ALERT
// ============================================================

static void drawFallAlert() {

  oled.clearDisplay();

  drawBatteryIcon();

  centerText(
      "FALL DETECTED",
      14,
      1
  );

  centerText(
      "CHECK DEVICE",
      29,
      1
  );

  centerText(
      "PRESS = DISMISS",
      48,
      1
  );

  centerText(
      "ALERT ACTIVE",
      59,
      1
  );

  oled.display();
}

// ============================================================
// POSTURE ALERT
// ============================================================

static void drawPostureAlert() {
  oled.clearDisplay();
  drawBatteryIcon();

  centerText("POSTURE", 12, 2);
  centerText("PLEASE SIT UPRIGHT", 34, 1);
  centerText("PRESS BTN TO SNOOZE", 52, 1);

  oled.display();
}

// ============================================================
// TIMER DONE
// ============================================================

static void drawTimerDone() {

  oled.clearDisplay();

  drawBatteryIcon();

  centerText(
      "TIMER DONE",
      12,
      1
  );

  centerText(
      "00:00",
      28,
      2
  );

  centerText(
      "PRESS TO STOP",
      50,
      1
  );

  oled.display();
}

// ============================================================
// REMINDERS
// ============================================================

static void drawReminders() {

  oled.clearDisplay();

  drawBatteryHeader(
      "REMINDERS"
  );

  int n =
      reminders::count();

  if (n == 0) {

    centerText(
        "NO REMINDERS",
        27,
        1
    );

    centerText(
        "SET IN APP",
        43,
        1
    );

    oled.display();
    return;
  }

  // Keep the selection valid if the app changes the reminder list.
  if (reminderSelection >= n) {
    reminderSelection = n - 1;
  }

  if (reminderSelection < 0) {
    reminderSelection = 0;
  }

  int pageStart =
      (reminderSelection / 4) * 4;

  reminderListOffset =
      pageStart;

  for (
      int position = pageStart;
      position < n &&
      position < pageStart + 4;
      position++
  ) {

    int rawIndex =
        getReminderRawIndex(position);

    if (rawIndex < 0) {
      continue;
    }

    const Reminder& r =
        reminders::get(rawIndex);

    int y =
        13 + (position - pageStart) * 11;

    bool selected =
        reminderSelectionActive &&
        position == reminderSelection;

    if (selected) {

      oled.fillRect(
          0,
          y - 1,
          OLED_WIDTH,
          10,
          SSD1306_WHITE
      );

      oled.setTextColor(
          SSD1306_BLACK
      );
    }
    else {

      oled.setTextColor(
          SSD1306_WHITE
      );
    }

    // Time
    char timeBuf[8];

    snprintf(
        timeBuf,
        sizeof(timeBuf),
        "%02d:%02d",
        r.hour,
        r.minute
    );

    oled.setCursor(
        1,
        y
    );

    oled.print(
        timeBuf
    );

    // Short reminder name so the status remains visible.
    char nameBuf[11];

    strncpy(
        nameBuf,
        r.name,
        sizeof(nameBuf) - 1
    );

    nameBuf[sizeof(nameBuf) - 1] =
        '\0';

    oled.setCursor(
        37,
        y
    );

    oled.print(
        nameBuf
    );

    // ON/OFF state.
    oled.setCursor(
        105,
        y
    );

    oled.print(
        r.enabled
            ? "ON"
            : "OFF"
    );

    oled.setTextColor(
        SSD1306_WHITE
    );
  }

  if (reminderSelectionActive) {

    oled.setCursor(
        0,
        58
    );

    oled.print(
        "1X NEXT 2X ON/OFF"
    );
  }
  else {

    oled.setCursor(
        0,
        58
    );

    oled.print(
        "3X = ON/OFF MENU"
    );
  }

  oled.display();
}

// ============================================================
// REMINDER ALERT
// ============================================================

static void drawReminderAlert() {

  oled.clearDisplay();

  drawBatteryIcon();

  centerText(
      "REMINDER",
      8,
      1
  );

  if (
      reminders::hasPendingAlert()
  ) {

    centerText(
        reminders::getPendingAlert().name,
        26,
        1
    );
  }

  centerText(
      "TIME TO MOVE",
      40,
      1
  );

  centerText(
      "PRESS = DISMISS",
      54,
      1
  );

  oled.display();
}

// ============================================================
// ALARMS
// ============================================================

static void drawAlarms() {

  oled.clearDisplay();

  drawBatteryHeader(
      "ALARMS"
  );

  int n =
      alarms::count();

  if (
      n == 0
  ) {

    centerText(
        "NO ALARMS",
        30,
        1
    );
  }

  else {

    int shown =
        0;

    for (
        int i = 0;
        i < MAX_ALARMS &&
        shown < 4;
        i++
    ) {

      const Alarm& a =
          alarms::get(i);

      if (
          !a.used
      ) {

        continue;
      }

      char buf[8];

      snprintf(
          buf,
          sizeof(buf),
          "%02d:%02d",
          a.hour,
          a.minute
      );

      oled.setCursor(
          0,
          14 + shown * 11
      );

      oled.print(
          buf
      );

      oled.setCursor(
          90,
          14 + shown * 11
      );

      oled.print(
          a.enabled
              ? "ON"
              : "OFF"
      );

      shown++;
    }
  }

  oled.display();
}

// ============================================================
// ALARM SETUP
// ============================================================

static const char* alarmSetupItems[] = {
    "Time",
    "Repeat",
    "Enabled",
    "Delete"
};

static void getAlarmRepeatLabel(const Alarm& a, char* out, size_t outSize) {

  bool all = true;
  bool weekdays = true;
  bool weekendOnly = true;

  for (int i = 0; i < 7; i++) {
    if (!a.days[i]) all = false;

    if (i == 0 || i == 6) {
      if (!a.days[i]) weekendOnly = false;
    }
    else {
      if (!a.days[i]) weekdays = false;
      if (a.days[i]) weekendOnly = false;
    }
  }

  if (all) {
    snprintf(out, outSize, "Everyday");
  }
  else if (weekdays && !a.days[0] && !a.days[6]) {
    snprintf(out, outSize, "Weekdays");
  }
  else if (weekendOnly) {
    snprintf(out, outSize, "Weekend");
  }
  else {
    snprintf(out, outSize, "Custom");
  }
}

static void drawAlarmSetup() {

  oled.clearDisplay();

  char title[12];
  snprintf(title, sizeof(title), "ALARM %d", alarmSetupIndex + 1);
  drawBatteryHeader(title);

  if (alarmSetupIndex < 0 || alarmSetupIndex >= MAX_ALARMS) {
    centerText("INVALID ALARM", 28, 1);
    oled.display();
    return;
  }

  const Alarm& a = alarms::get(alarmSetupIndex);

  if (!a.used) {
    centerText("EMPTY ALARM", 24, 1);
    centerText("2X CREATE", 40, 1);
    oled.display();
    return;
  }

  if (alarmSetupEditMode && alarmSetupEditType == 1) {
    centerText("SET TIME", 14, 1);

    // Keep hour, minute, and AM/PM clearly separated.
    const int hourBoxX = 12;
    const int minuteBoxX = 43;
    const int ampmBoxX = 78;
    const int boxY = 26;
    const int boxH = 18;

    if (alarmTimeField == 0) {
      oled.fillRoundRect(hourBoxX, boxY, 27, boxH, 2, SSD1306_WHITE);
    }
    else if (alarmTimeField == 1) {
      oled.fillRoundRect(minuteBoxX, boxY, 27, boxH, 2, SSD1306_WHITE);
    }
    else {
      oled.fillRoundRect(ampmBoxX, boxY, 34, boxH, 2, SSD1306_WHITE);
    }

    oled.setTextSize(2);

    // Hour
    oled.setTextColor(
        alarmTimeField == 0 ? SSD1306_BLACK : SSD1306_WHITE
    );
    oled.setCursor(hourBoxX + 3, 28);
    oled.printf("%02d", alarmEditHour12);

    // Colon
    oled.setTextColor(SSD1306_WHITE);
    oled.setCursor(38, 28);
    oled.print(":");

    // Minute
    oled.setTextColor(
        alarmTimeField == 1 ? SSD1306_BLACK : SSD1306_WHITE
    );
    oled.setCursor(minuteBoxX + 3, 28);
    oled.printf("%02d", alarmEditMinute);

    // AM / PM
    oled.setTextColor(
        alarmTimeField == 2 ? SSD1306_BLACK : SSD1306_WHITE
    );
    oled.setTextSize(1);
    oled.setCursor(ampmBoxX + 9, 31);
    oled.print(alarmEditPM ? "PM" : "AM");

    oled.setTextColor(SSD1306_WHITE);
    oled.display();
    return;
  }

  if (alarmSetupEditMode && alarmSetupEditType == 2) {
    centerText("REPEAT", 13, 1);

    const char* labels[] = {"Everyday", "Weekdays", "Weekend", "Custom"};
    oled.setCursor(0, 29);
    oled.print("> ");
    oled.print(labels[alarmRepeatChoice]);

    oled.display();
    return;
  }

  if (alarmSetupEditMode && alarmSetupEditType == 3) {
    centerText("CUSTOM DAYS", 12, 1);

    const char* dayNames[] = {"SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"};
    for (int i = 0; i < 7; i++) {
      int x = 2 + i * 18;
      if (i == alarmCustomDay) {
        oled.fillRect(x, 25, 17, 17, SSD1306_WHITE);
        oled.setTextColor(SSD1306_BLACK);
      }
      else {
        oled.setTextColor(SSD1306_WHITE);
      }
      oled.setCursor(x + 2, 28);
      oled.print(dayNames[i][0]);
      oled.setTextColor(SSD1306_WHITE);
      oled.setCursor(x + 2, 45);
      oled.print(alarmCustomDays[i] ? "ON" : "--");
    }

    oled.display();
    return;
  }

  const int rowY = 14;
  for (int i = 0; i < 4; i++) {
    int y = rowY + i * 12;
    bool selected = (i == alarmSetupSelection);
    if (selected) {
      oled.fillRect(0, y, OLED_WIDTH, 11, SSD1306_WHITE);
      oled.setTextColor(SSD1306_BLACK);
    }
    else {
      oled.setTextColor(SSD1306_WHITE);
    }

    oled.setCursor(2, y + 2);
    oled.print(alarmSetupItems[i]);

    oled.setCursor(55, y + 2);
    if (i == 0) {
      oled.printf("%02d:%02d %s", alarms::to12Hour(a.hour), a.minute,
                  alarms::isPM(a.hour) ? "PM" : "AM");
    }
    else if (i == 1) {
      char repeat[12];
      getAlarmRepeatLabel(a, repeat, sizeof(repeat));
      oled.print(repeat);
    }
    else if (i == 2) {
      oled.print(a.enabled ? "ON" : "OFF");
    }
    else {
      oled.print("REMOVE");
    }
  }

  oled.setTextColor(SSD1306_WHITE);
  oled.display();
}

// ============================================================
// ALARM LIST
// ============================================================

static void drawAlarmList() {

  oled.clearDisplay();

  drawBatteryHeader(
      "ALARMS"
  );

  // Show three alarm slots at a time.
  // The list can scroll through all five slots.
  for (
      int row = 0;
      row < 3;
      row++
  ) {

    int index =
        alarmListOffset + row;

    if (
        index >= MAX_ALARMS
    ) {
      break;
    }

    const Alarm& a =
        alarms::get(index);

    int y =
        13 + row * 15;

    bool selected =
        alarmListSelectionActive &&
        index == alarmListSelection;

    if (selected) {

      oled.fillRoundRect(
          0,
          y,
          OLED_WIDTH,
          13,
          2,
          SSD1306_WHITE
      );

      oled.setTextColor(
          SSD1306_BLACK
      );
    }
    else {

      oled.setTextColor(
          SSD1306_WHITE
      );
    }

    char timeBuf[12];

    if (!a.used) {

      snprintf(
          timeBuf,
          sizeof(timeBuf),
          "--:--"
      );
    }
    else {

      int hour12 =
          alarms::to12Hour(a.hour);

      snprintf(
          timeBuf,
          sizeof(timeBuf),
          "%02d:%02d %s",
          hour12,
          a.minute,
          alarms::isPM(a.hour)
              ? "PM"
              : "AM"
      );
    }

    oled.setCursor(
        3,
        y + 3
    );

    oled.print(
        "A"
    );

    oled.print(
        index + 1
    );

    oled.print(
        "  "
    );

    oled.print(
        timeBuf
    );

    oled.setCursor(
        104,
        y + 3
    );

    oled.print(
        a.used && a.enabled
            ? "ON"
            : "OFF"
    );
  }

  oled.setTextColor(
      SSD1306_WHITE
  );

  // Small scroll indicator when viewing the lower alarms.
  if (alarmListOffset > 0) {

    oled.setCursor(
        121,
        10
    );

    oled.print(
        "^"
    );
  }

  if (alarmListOffset < MAX_ALARMS - 3) {

    oled.setCursor(
        121,
        59
    );

    oled.print(
        "v"
    );
  }

  oled.display();
}

// ============================================================
// ALARM ALERT
// ============================================================

static void drawAlarmAlert() {

  oled.clearDisplay();

  drawBatteryIcon();

  centerText(
      "ALARM",
      10,
      2
  );

  if (
      alarms::isRinging()
  ) {

    const Alarm& a =
        alarms::getRinging();

    char buf[8];

    snprintf(
        buf,
        sizeof(buf),
        "%02d:%02d",
        a.hour,
        a.minute
    );

    centerText(
        buf,
        32,
        1
    );
  }

  centerText(
      "WAKE UP",
      44,
      1
  );

  centerText(
      "PRESS = DISMISS",
      56,
      1
  );

  oled.display();
}

// ============================================================
// BATTERY
// ============================================================

static void drawBattery() {

  oled.clearDisplay();

  drawBatteryIcon();

  char title[16];

  snprintf(
      title,
      sizeof(title),
      "BATTERY %d%%",
      battery::getPercent()
  );

  oled.setTextSize(
      1
  );

  oled.setCursor(
      0,
      0
  );

  oled.print(
      title
  );

  oled.drawFastHLine(
      0,
      10,
      OLED_WIDTH,
      SSD1306_WHITE
  );

  char pctBuf[6];

  snprintf(
      pctBuf,
      sizeof(pctBuf),
      "%d%%",
      battery::getPercent()
  );

  centerText(
      pctBuf,
      16,
      2
  );

  int barW =
      (OLED_WIDTH - 20) *
      battery::getPercent() /
      100;

  oled.drawRect(
      10,
      38,
      OLED_WIDTH - 20,
      8,
      SSD1306_WHITE
  );

  oled.fillRect(
      10,
      38,
      barW,
      8,
      SSD1306_WHITE
  );

  char vBuf[12];

  snprintf(
      vBuf,
      sizeof(vBuf),
      "%.2f V",
      battery::getVoltage()
  );

  centerText(
      vBuf,
      50,
      1
  );


  oled.display();
}

// ============================================================
// MAIN MENU UI
// ============================================================

static void drawMenu() {

  oled.clearDisplay();

  const int columnX[2] = {32, 96};
  const int iconY[2] = {1, 33};
  const int textY[2] = {23, 55};

  if (menuSelection >= 0) {
    int selectedRow = menuSelection / 2;

    if (selectedRow < menuRowOffset) {
      menuRowOffset = selectedRow;
    }

    if (selectedRow >= menuRowOffset + 2) {
      menuRowOffset = selectedRow - 1;
    }

    if (menuRowOffset > 3) {
      menuRowOffset = 3;
    }
  }

  for (int row = 0; row < 2; row++) {
    int actualRow = menuRowOffset + row;

    for (int col = 0; col < 2; col++) {
      int index = actualRow * 2 + col;

      if (index >= MENU_ITEM_COUNT) {
        continue;
      }

      int cx = columnX[col];
      int iy = iconY[row];
      int ty = textY[row];

      if (menuSelectionActive && menuSelection == index) {
        oled.drawRoundRect(cx - 30, iy - 1, 60, 30, 3, SSD1306_WHITE);
      }

      oled.drawBitmap(cx - 10, iy, menuIcons[index], 20, 20, SSD1306_WHITE);

      oled.setTextSize(1);
      oled.setTextColor(SSD1306_WHITE);

      int16_t x1;
      int16_t y1;
      uint16_t w;
      uint16_t h;

      oled.getTextBounds(menuNames[index], 0, 0, &x1, &y1, &w, &h);
      oled.setCursor(cx - (w / 2), ty);
      oled.print(menuNames[index]);
    }
  }

  oled.display();
}

// ============================================================
// SETTINGS MENU
// ============================================================

static void drawSettingsMenu() {

  oled.clearDisplay();

  drawBatteryHeader(
      "SETTINGS"
  );

  const char* items[] = {
      "Posture Setup",
      "Alarms",
      "Reminders",
      "Display",
      "Sound",
      "Wi-Fi",
      "System"
  };

  const int itemCount = 7;
  const int visibleCount = 5;
  const int rowHeight = 10;
  const int firstY = 10;

  int maxOffset = itemCount - visibleCount;

  if (settingsMenuOffset > maxOffset) {
    settingsMenuOffset = maxOffset;
  }

  if (settingsMenuSelectionActive) {
    if (settingsMenuSelection < settingsMenuOffset) {
      settingsMenuOffset = settingsMenuSelection;
    }
    else if (settingsMenuSelection >= settingsMenuOffset + visibleCount) {
      settingsMenuOffset = settingsMenuSelection - visibleCount + 1;
    }
  }

  for (int row = 0; row < visibleCount; row++) {

    int index = settingsMenuOffset + row;

    if (index >= itemCount) {
      break;
    }

    int y = firstY + row * rowHeight;
    bool selected =
        settingsMenuSelectionActive &&
        index == settingsMenuSelection;

    if (selected) {
      oled.fillRoundRect(
          0, y, OLED_WIDTH, rowHeight - 1, 2, SSD1306_WHITE
      );
      oled.setTextColor(SSD1306_BLACK);
    }
    else {
      oled.setTextColor(SSD1306_WHITE);
    }

    oled.setCursor(4, y + 1);
    oled.print(items[index]);
  }

  if (settingsMenuOffset < maxOffset) {
    oled.fillTriangle(
        122, 61, 118, 61, 120, 58, SSD1306_WHITE
    );
  }

  if (settingsMenuOffset > 0) {
    oled.fillTriangle(
        120, 9, 118, 12, 122, 12, SSD1306_WHITE
    );
  }

  oled.setTextColor(SSD1306_WHITE);
  oled.display();
}

// ============================================================
// SETTINGS — WI-FI
// ============================================================

static void drawSettingsWiFi() {

  oled.clearDisplay();

  drawBatteryHeader(
      "WI-FI"
  );

  const bool enabled =
      wifiManager::isEnabled();

  const bool connected =
      wifiManager::isConnected();

  const char* statusText =
      !enabled
          ? "Disabled"
          : (
              connected
                  ? "Connected"
                  : (
                      wifiManager::isConnecting()
                          ? "Connecting"
                          : "Disconnected"
                    )
            );

  String networkText =
      wifiManager::getSSID();

  if (networkText.length() == 0) {
    networkText = "--";
  }

  const char* labels[3] = {
      "Wi-Fi",
      "Status",
      "Network"
  };

  for (int i = 0; i < 3; i++) {

    const int y =
        16 + i * 14;

    const bool selected =
        i == wifiMenuSelection;

    if (selected) {
      oled.fillRoundRect(
          0,
          y,
          OLED_WIDTH,
          12,
          2,
          SSD1306_WHITE
      );

      oled.setTextColor(
          SSD1306_BLACK
      );
    }
    else {
      oled.setTextColor(
          SSD1306_WHITE
      );
    }

    oled.setCursor(
        3,
        y + 2
    );

    oled.print(
        labels[i]
    );

    oled.setCursor(
        70,
        y + 2
    );

    if (i == 0) {
      oled.print(
          enabled
              ? "ON"
              : "OFF"
      );
    }
    else if (i == 1) {
      oled.print(
          statusText
      );
    }
    else {
      oled.print(
          networkText
      );
    }
  }

  oled.setTextColor(
      SSD1306_WHITE
  );

  oled.display();
}

// ============================================================
// SETTINGS — POSTURE
// ============================================================

static void drawSettingsPosture() {

  oled.clearDisplay();

  drawBatteryIcon();

  centerText(
      "POSTURE SETTINGS",
      4,
      1
  );

  oled.setCursor(
      0,
      20
  );

  oled.print(
      "> Recalibrate"
  );

  oled.setCursor(
      0,
      32
  );

  oled.print(
      "  Monitoring"
  );

  oled.setCursor(
      0,
      44
  );

  oled.print(
      "  Sensitivity"
  );

  oled.display();
}

// ============================================================
// SETTINGS — DISPLAY
// ============================================================

static void drawSettingsDisplay() {

  oled.clearDisplay();

  drawBatteryIcon();

  centerText(
      "DISPLAY",
      4,
      1
  );

  const int ys[3] = {18, 32, 46};
  const char* labels[3] = {
      "Timeout",
      "Always On",
      "Orientation"
  };

  for (int i = 0; i < 3; i++) {

    bool selected =
        (i == displaySettingsSelection);

    if (selected) {
      oled.fillRect(0, ys[i] - 1, OLED_WIDTH, 10, SSD1306_WHITE);
      oled.setTextColor(SSD1306_BLACK);
    }
    else {
      oled.setTextColor(SSD1306_WHITE);
    }

    oled.setCursor(2, ys[i]);
    oled.print(labels[i]);

    oled.setCursor(82, ys[i]);

    if (i == 0) {
      int sec = settings::getScreenTimeoutSec();
      if (sec == 0) oled.print("NEVER");
      else {
        oled.print(sec);
        oled.print("s");
      }
    }
    else if (i == 1) {
      oled.print(settings::getScreenTimeoutSec() == 0 ? "ON" : "OFF");
    }
    else {
      oled.print(settings::getOrientation() == 2 ? "180" : "0");
      oled.print("deg");
    }
  }

  oled.setTextColor(SSD1306_WHITE);
  oled.display();
}

// ============================================================
// SETTINGS — SOUND
// ============================================================

static void drawSettingsSound() {

  oled.clearDisplay();
  drawBatteryIcon();
  centerText("SOUND", 4, 1);

  const int ys[4] = {17, 29, 41, 53};

  for (int i = 0; i < 4; i++) {
    bool selected = (i == soundSettingsSelection);

    if (selected) {
      oled.fillRect(0, ys[i] - 1, OLED_WIDTH, 11, SSD1306_WHITE);
      oled.setTextColor(SSD1306_BLACK);
    } else {
      oled.setTextColor(SSD1306_WHITE);
    }

    oled.setCursor(2, ys[i]);

    if (i == 0) {
      oled.print("Sound");
      oled.setCursor(88, ys[i]);
      oled.print(settings::getSoundEnabled() ? "ON" : "OFF");
    }
    else if (i == 1) {
      oled.print("Volume");
      int volume = settings::getSoundVolume();
      int filled = map(volume, 0, 100, 0, 50);
      int barX = 67;
      int barY = ys[i] + 1;
      oled.drawRect(barX, barY, 52, 8, selected ? SSD1306_BLACK : SSD1306_WHITE);
      if (filled > 3) {
        oled.fillRect(barX + 2, barY + 2, filled - 3, 4, selected ? SSD1306_BLACK : SSD1306_WHITE);
      }
    }
    else if (i == 2) {
      oled.print("DND");
      oled.setCursor(88, ys[i]);
      oled.print(wellness::isDnd() ? "ON" : "OFF");
    }
    else {
      oled.print("Click Sound");
      oled.setCursor(88, ys[i]);
      oled.print(settings::getClickSoundEnabled() ? "ON" : "OFF");
    }
  }

  oled.setTextColor(SSD1306_WHITE);
  oled.display();
}

// ============================================================
// SETTINGS — SYSTEM
// ============================================================

static void drawSettingsSystem() {

  oled.clearDisplay();

  drawBatteryIcon();

  centerText(
      "SYSTEM",
      4,
      1
  );

  const int ys[5] = {14, 25, 36, 47, 58};

  const char* labels[5] = {
      "Time / Date",
      "Reset Data",
      "Diagnostics",
      "LED Brightness",
      "About System"
  };

  for (int i = 0; i < 5; i++) {

    bool selected =
        (i == systemSelection);

    if (selected) {
      oled.fillRect(
          0,
          ys[i] - 1,
          OLED_WIDTH,
          11,
          SSD1306_WHITE
      );
      oled.setTextColor(SSD1306_BLACK);
    }
    else {
      oled.setTextColor(SSD1306_WHITE);
    }

    oled.setCursor(
        2,
        ys[i]
    );

    oled.print(
        labels[i]
    );

    if (i == 3) {
      oled.setCursor(92, ys[i]);
      oled.print(settings::getLedHigh() ? "HIGH" : "LOW");
    }
  }

  oled.setTextColor(SSD1306_WHITE);
  oled.display();
}

// ============================================================
// ABOUT SYSTEM
// ============================================================

static void drawAboutSystem() {

  oled.clearDisplay();

  drawBatteryHeader(
      "ABOUT SYSTEM"
  );

  centerText(
      "HEALTH DEVICE",
      15,
      1
  );

  oled.setCursor(
      0,
      28
  );
  oled.print("MCU: ESP32-C3");

  oled.setCursor(
      0,
      39
  );
  oled.print("OLED: SSD1306 128x64");

  oled.setCursor(
      0,
      50
  );
  oled.print("HR: MAX30102");

  oled.setCursor(
      0,
      61
  );
  oled.print("IMU: MPU-6500");

  oled.display();
}

// ============================================================
// DIAGNOSTICS
// ============================================================

static void drawDiagnostics() {

  oled.clearDisplay();

  drawBatteryHeader(
      "SYSTEM"
  );

  centerText(
      "HEALTH DEVICE",
      12,
      1
  );

  oled.setCursor(
      0,
      26
  );

  oled.print(
      "ESP32-C3   OK"
  );

  oled.setCursor(
      0,
      36
  );

  oled.print(
      "MPU-6500   OK"
  );

  oled.setCursor(
      0,
      46
  );

  oled.print(
      "MAX30102   OK"
  );

  oled.setCursor(
      0,
      56
  );

  oled.print(
      "OLED       OK"
  );

  oled.display();
}

// ============================================================
// LOW POWER
// ============================================================

static void drawLowPower() {

  oled.clearDisplay();

  drawBatteryIcon();

  centerText(
      "LOW POWER",
      20,
      1
  );

  centerText(
      "DISPLAY SLEEPING",
      34,
      1
  );

  centerText(
      "HR SENSOR OFF",
      46,
      1
  );

  oled.display();
}

// ============================================================
// PUBLIC API
// ============================================================

namespace display {

// ============================================================
// BEGIN
// ============================================================

bool begin() {

  if (
      !oled.begin(
          SSD1306_SWITCHCAPVCC,
          OLED_I2C_ADDR
      )
  ) {

    oledFound =
        false;

    return false;
  }

  oled.clearDisplay();

  oled.display();

  oledFound =
      true;

  oled.setRotation(settings::getOrientation());

  lastDisplayActivityMs = millis();

  currentScreen =
      SCR_STARTUP;

  timerEditMode =
      false;

  timerEditField =
      2;

  timerEditAction =
      0;

  settingsMenuSelection =
      -1;

  settingsMenuOffset =
      0;

  settingsMenuSelectionActive =
      false;

  menuSelection = -1;
  menuSelectionActive = false;
  menuRowOffset = 0;

  reminderSelection = 0;
  reminderListOffset = 0;
  reminderSelectionActive = false;

  return true;
}

// ============================================================
// GO HOME
// ============================================================

void goHome() {

  currentScreen =
      SCR_HOME;

  settingsMenuSelection =
      -1;

  settingsMenuOffset =
      0;

  settingsMenuSelectionActive =
      false;

  menuSelection = -1;
  menuSelectionActive = false;
  menuRowOffset = 0;

  reminderSelection = 0;
  reminderListOffset = 0;
  reminderSelectionActive = false;

  alarmListSelection = 0;
  alarmListOffset = 0;
  alarmListSelectionActive = false;

  requestRedraw();
}

// ============================================================
// SET SCREEN
// ============================================================

void setScreen(
    DeviceScreen s
) {

  currentScreen =
      s;

  if (
      s == SCR_HR_HISTORY ||
      s == SCR_SPO2_HISTORY
  ) {
    healthHistoryOffset = 0;
  }

  if (
      s != SCR_CLOCK
  ) {

    timerEditMode =
        false;

    timerEditAction =
        0;
  }

  if (
      s == SCR_SETTINGS
  ) {

    settingsMenuSelection =
        0;

    settingsMenuOffset =
        0;

    settingsMenuSelectionActive =
        true;
  }

  if (s == SCR_MENU) {

    menuSelection = -1;
    menuSelectionActive = false;
    menuRowOffset = 0;
  }

  if (s == SCR_ALARM_LIST) {

    alarmListSelection = 0;
    alarmListOffset = 0;
    alarmListSelectionActive = true;
  }
  else {

    alarmListSelectionActive = false;
  }

  if (s == SCR_REMINDERS) {

    reminderSelection = 0;
    reminderListOffset = 0;
    reminderSelectionActive = false;
  }
  else {

    reminderSelectionActive = false;
  }

  requestRedraw();
}

// ============================================================
// GET CURRENT SCREEN
// ============================================================

DeviceScreen getCurrentScreen() {

  return currentScreen;
}

// ============================================================
// NEXT SCREEN
// ============================================================

void nextScreen() {

  switch (
      currentScreen
  ) {

    case SCR_HOME:

      currentScreen =
          SCR_MENU;

      menuSelection = -1;
      menuSelectionActive = false;
      menuRowOffset = 0;

      break;

    case SCR_MENU:

      currentScreen =
          SCR_HEART_RATE;

      break;

    case SCR_HEART_RATE:

      currentScreen =
          SCR_POSTURE;

      break;

    case SCR_POSTURE:

      currentScreen =
          SCR_ACTIVITY;

      break;

    case SCR_ACTIVITY:

      currentScreen =
          SCR_HOME;

      break;

    default:

      currentScreen =
          SCR_HOME;

      break;
  }

  requestRedraw();
}

// ============================================================
// MAIN MENU SELECTION
// ============================================================

void startMenuSelection() {

  if (menuSelectionActive) {
    menuSelection = -1;
    menuSelectionActive = false;
  }
  else {
    menuSelection = 0;
    menuSelectionActive = true;
    menuRowOffset = 0;
  }

  requestRedraw();
}

void nextMenuItem() {

  if (!menuSelectionActive) {
    nextScreen();
    return;
  }

  menuSelection++;

  if (menuSelection >= MENU_ITEM_COUNT) {
    menuSelection = 0;
    menuRowOffset = 0;
  }

  requestRedraw();
}

void activateMenuItem() {

  if (!menuSelectionActive) {
    return;
  }

  if (menuSelection >= 0 && menuSelection < MENU_ITEM_COUNT) {
    // Use setScreen() so entering Settings (and other special
    // screens) also initializes their selection state correctly.
    setScreen(menuScreens[menuSelection]);
  }

  menuSelection = -1;
  menuSelectionActive = false;
  menuRowOffset = 0;

  requestRedraw();
}

void resetMenuSelection() {

  menuSelection = -1;
  menuSelectionActive = false;
  menuRowOffset = 0;

  requestRedraw();
}

void startHealthHistory() {
  healthHistoryOffset = 0;
  requestRedraw();
}

void nextHealthHistoryItem() {
  bool spo2 = (currentScreen == SCR_SPO2_HISTORY);
  int count = spo2
      ? healthHistory::getSpO2Count()
      : healthHistory::getHeartRateCount();

  int maxOffset = count > 4 ? count - 4 : 0;

  if (maxOffset <= 0) {
    healthHistoryOffset = 0;
  }
  else {
    healthHistoryOffset++;
    if (healthHistoryOffset > maxOffset) {
      healthHistoryOffset = 0;
    }
  }

  requestRedraw();
}

void resetHealthHistory() {
  healthHistoryOffset = 0;
  requestRedraw();
}

// ============================================================
// SETTINGS MENU
// ============================================================

void startSettingsSelection() {

  settingsMenuSelection =
      0;

  settingsMenuOffset =
      0;

  settingsMenuSelectionActive =
      true;

  requestRedraw();
}

void nextSettingsItem() {

  // When selection mode is OFF, a single click from MENU
  // continues the normal main-screen navigation.
  if (
      !settingsMenuSelectionActive
  ) {

    nextScreen();

    return;
  }

  settingsMenuSelection++;

  if (
      settingsMenuSelection > 6
  ) {

    settingsMenuSelection =
        0;
  }

  if (settingsMenuSelection < settingsMenuOffset) {
    settingsMenuOffset = settingsMenuSelection;
  }
  else if (settingsMenuSelection >= settingsMenuOffset + 5) {
    settingsMenuOffset = settingsMenuSelection - 4;
  }

  requestRedraw();
}

void activateSettingsItem() {

  if (
      !settingsMenuSelectionActive
  ) {

    return;
  }

  switch (
      settingsMenuSelection
  ) {

    case 0:

      currentScreen =
          SCR_SETTINGS_POSTURE;

      break;

    case 1:

      alarmListSelection =
          0;

      alarmListOffset =
          0;

      alarmListSelectionActive =
          true;

      currentScreen =
          SCR_ALARM_LIST;

      break;

    case 2:

      currentScreen =
          SCR_REMINDERS;

      break;

    case 3:

      currentScreen =
          SCR_SETTINGS_DISPLAY;

      startDisplaySettings();

      break;

    case 4:

      currentScreen =
          SCR_SETTINGS_SOUND;

      startSoundSettings();

      break;


    case 5:

      wifiMenuSelection =
          0;

      currentScreen =
          SCR_SETTINGS_WIFI;

      break;

    case 6:

      currentScreen =
          SCR_SETTINGS_SYSTEM;

      startSystemSelection();

      break;
  }

  // Opening a Menu option exits selection mode.
  settingsMenuSelection =
      -1;

  settingsMenuSelectionActive =
      false;

  requestRedraw();
}

void resetSettingsSelection() {

  settingsMenuSelection =
      -1;

  settingsMenuOffset =
      0;

  settingsMenuSelectionActive =
      false;

  requestRedraw();
}


// ============================================================
// SYSTEM SETTINGS CONTROLS
// ============================================================

void startSystemSelection() {
  systemSelection = 0;
  requestRedraw();
}

void nextSystemItem() {
  systemSelection++;

  if (systemSelection > 4) {
    systemSelection = 0;
  }

  requestRedraw();
}

void resetSystemSelection() {
  systemSelection = 0;
  requestRedraw();
}

void activateSystemItem() {

  switch (systemSelection) {

    case 0:
      // Use the existing clock screen for the current time/date.
      clockMode = 0;
      currentScreen = SCR_CLOCK;
      break;

    case 1:
      // Reset configurable settings only.
      // Alarms, reminders, posture calibration and history are untouched.
      settings::setBrightness(100);
      settings::setScreenTimeoutSec(0);
      settings::setSoundEnabled(true);
      settings::setSoundVolume(70);
      settings::setClickSoundEnabled(true);
      settings::setMeasurementSoundEnabled(true);
      settings::setLedHigh(true);
      settings::setUse24Hour(true);
      settings::setOrientation(0);
      wellness::setDnd(false);
      wifiManager::setEnabled(true);
      currentScreen = SCR_SETTINGS_SYSTEM;
      break;

    case 2:
      currentScreen = SCR_DIAGNOSTICS;
      break;

    case 3:
      settings::setLedHigh(!settings::getLedHigh());
      currentScreen = SCR_SETTINGS_SYSTEM;
      break;

    case 4:
      currentScreen = SCR_ABOUT_SYSTEM;
      break;
  }

  requestRedraw();
}


// ============================================================
// WI-FI SETTINGS CONTROLS
// ============================================================

void startWiFiSelection() {

  wifiMenuSelection =
      0;

  requestRedraw();
}

void nextWiFiItem() {

  wifiMenuSelection++;

  if (wifiMenuSelection >= 3) {
    wifiMenuSelection =
        0;
  }

  requestRedraw();
}

int getWiFiSelection() {

  return wifiMenuSelection;
}

void resetWiFiSelection() {

  wifiMenuSelection =
      0;

  requestRedraw();
}


// ============================================================
// ALARM LIST SELECTION
// ============================================================

void startAlarmListSelection() {

  alarmListSelection =
      0;

  alarmListOffset =
      0;

  alarmListSelectionActive =
      true;

  requestRedraw();
}

void nextAlarmListItem() {

  if (!alarmListSelectionActive) {
    return;
  }

  alarmListSelection++;

  if (alarmListSelection >= MAX_ALARMS) {
    alarmListSelection = 0;
  }

  if (alarmListSelection < alarmListOffset) {
    alarmListOffset = alarmListSelection;
  }
  else if (alarmListSelection >= alarmListOffset + 3) {
    alarmListOffset = alarmListSelection - 2;
  }

  if (alarmListOffset > MAX_ALARMS - 3) {
    alarmListOffset = MAX_ALARMS - 3;
  }

  if (alarmListOffset < 0) {
    alarmListOffset = 0;
  }

  requestRedraw();
}

int getAlarmListSelection() {

  return alarmListSelection;
}

bool isAlarmListSelectionActive() {

  return alarmListSelectionActive;
}

void resetAlarmListSelection() {

  alarmListSelection = 0;
  alarmListOffset = 0;
  alarmListSelectionActive = false;

  requestRedraw();
}

// ============================================================
// ALARM SETUP CONTROLS
// ============================================================

void openAlarmSetup(int index) {

  if (index < 0 || index >= MAX_ALARMS) return;

  // If this slot is empty, create a new default alarm in the first
  // available slot, then open the newly created slot.
  if (!alarms::get(index).used) {
    bool before[MAX_ALARMS];
    for (int i = 0; i < MAX_ALARMS; i++) before[i] = alarms::get(i).used;

    bool days[7] = {true, true, true, true, true, true, true};
    if (alarms::add12Hour(7, 0, false, days)) {
      for (int i = 0; i < MAX_ALARMS; i++) {
        if (!before[i] && alarms::get(i).used) {
          index = i;
          break;
        }
      }
    }
  }

  alarmSetupIndex = index;
  alarmSetupSelection = 0;
  alarmSetupEditMode = false;
  alarmSetupEditType = 0;
  alarmTimeField = 0;
  alarmRepeatChoice = 0;
  alarmCustomDay = 0;

  setScreen(SCR_ALARM_SETUP);
}

void nextAlarmSetupItem() {

  if (alarmSetupEditMode) {
    if (alarmSetupEditType == 1) {
      if (alarmTimeField == 0) {
        alarmEditHour12++;
        if (alarmEditHour12 > 12) alarmEditHour12 = 1;
      }
      else if (alarmTimeField == 1) {
        alarmEditMinute++;
        if (alarmEditMinute > 59) alarmEditMinute = 0;
      }
      else {
        alarmEditPM = !alarmEditPM;
      }
    }
    else if (alarmSetupEditType == 2) {
      alarmRepeatChoice++;
      if (alarmRepeatChoice > 3) alarmRepeatChoice = 0;
    }
    else if (alarmSetupEditType == 3) {
      alarmCustomDays[alarmCustomDay] = !alarmCustomDays[alarmCustomDay];
    }
    requestRedraw();
    return;
  }

  alarmSetupSelection++;
  if (alarmSetupSelection > 3) alarmSetupSelection = 0;
  requestRedraw();
}

void activateAlarmSetupItem() {

  if (alarmSetupIndex < 0 || alarmSetupIndex >= MAX_ALARMS) return;

  const Alarm& a = alarms::get(alarmSetupIndex);

  if (alarmSetupEditMode) {
    if (alarmSetupEditType == 1) {
      if (alarmTimeField < 2) {
        alarmTimeField++;
      }
      else {
        alarms::setTime12(alarmSetupIndex, alarmEditHour12,
                          alarmEditMinute, alarmEditPM);
        alarmSetupEditMode = false;
        alarmSetupEditType = 0;
      }
    }
    else if (alarmSetupEditType == 2) {
      if (alarmRepeatChoice == 0) {
        alarms::setEveryday(alarmSetupIndex);
        alarmSetupEditMode = false;
        alarmSetupEditType = 0;
      }
      else if (alarmRepeatChoice == 1) {
        alarms::setWeekdays(alarmSetupIndex);
        alarmSetupEditMode = false;
        alarmSetupEditType = 0;
      }
      else if (alarmRepeatChoice == 2) {
        alarms::setWeekend(alarmSetupIndex);
        alarmSetupEditMode = false;
        alarmSetupEditType = 0;
      }
      else {
        for (int i = 0; i < 7; i++) alarmCustomDays[i] = a.days[i];
        alarmCustomDay = 0;
        alarmSetupEditType = 3;
      }
    }
    else if (alarmSetupEditType == 3) {
      // Double-click advances through the days.
      // Save only after the final day (Saturday) is confirmed.
      if (alarmCustomDay < 6) {
        alarmCustomDay++;
      }
      else {
        alarms::setDays(alarmSetupIndex, alarmCustomDays);
        alarmSetupEditMode = false;
        alarmSetupEditType = 0;
      }
    }
    requestRedraw();
    return;
  }

  if (!a.used) {
    openAlarmSetup(alarmSetupIndex);
    return;
  }

  if (alarmSetupSelection == 0) {
    alarmEditHour12 = alarms::to12Hour(a.hour);
    alarmEditMinute = a.minute;
    alarmEditPM = alarms::isPM(a.hour);
    alarmTimeField = 0;
    alarmSetupEditType = 1;
    alarmSetupEditMode = true;
  }
  else if (alarmSetupSelection == 1) {
    bool all = true;
    bool wd = true;
    bool weekendOnly = true;
    for (int i = 0; i < 7; i++) {
      if (!a.days[i]) all = false;
      if (i == 0 || i == 6) {
        if (!a.days[i]) weekendOnly = false;
      } else {
        if (!a.days[i]) wd = false;
        if (a.days[i]) weekendOnly = false;
      }
    }
    if (all) alarmRepeatChoice = 0;
    else if (wd && !a.days[0] && !a.days[6]) alarmRepeatChoice = 1;
    else if (weekendOnly) alarmRepeatChoice = 2;
    else alarmRepeatChoice = 3;
    alarmSetupEditType = 2;
    alarmSetupEditMode = true;
  }
  else if (alarmSetupSelection == 2) {
    alarms::setEnabled(alarmSetupIndex, !a.enabled);
  }
  else if (alarmSetupSelection == 3) {
    alarms::remove(alarmSetupIndex);
    setScreen(SCR_ALARM_LIST);
  }

  requestRedraw();
}

void alarmSetupSingleAction() {
  nextAlarmSetupItem();
}

void alarmSetupDoubleAction() {
  activateAlarmSetupItem();
}

void alarmSetupTripleAction() {
  alarmSetupEditMode = false;
  alarmSetupEditType = 0;
  setScreen(SCR_ALARM_LIST);
}

// ============================================================
// REMINDER ON/OFF MENU
// ============================================================

void startReminderSelection() {

  int n =
      reminders::count();

  if (n <= 0) {

    reminderSelection = 0;
    reminderListOffset = 0;
    reminderSelectionActive = false;

    requestRedraw();
    return;
  }

  // Triple click toggles the ON/OFF menu.
  if (reminderSelectionActive) {

    reminderSelectionActive =
        false;

  }
  else {

    if (reminderSelection >= n) {
      reminderSelection = n - 1;
    }

    reminderSelectionActive =
        true;
  }

  reminderListOffset =
      (reminderSelection / 4) * 4;

  requestRedraw();
}

void nextReminderItem() {

  int n =
      reminders::count();

  if (n <= 0) {
    return;
  }

  if (!reminderSelectionActive) {
    return;
  }

  reminderSelection++;

  if (reminderSelection >= n) {
    reminderSelection = 0;
  }

  reminderListOffset =
      (reminderSelection / 4) * 4;

  requestRedraw();
}

void toggleSelectedReminder() {

  if (!reminderSelectionActive) {
    return;
  }

  int rawIndex =
      getReminderRawIndex(
          reminderSelection
      );

  if (rawIndex < 0) {
    return;
  }

  const Reminder& r =
      reminders::get(rawIndex);

  reminders::setEnabled(
      rawIndex,
      !r.enabled
  );

  requestRedraw();
}

bool isReminderSelectionActive() {

  return reminderSelectionActive;
}

void resetReminderSelection() {

  reminderSelection = 0;
  reminderListOffset = 0;
  reminderSelectionActive = false;

  requestRedraw();
}

// ============================================================
// NEXT CLOCK MODE
// ============================================================

void nextClockMode() {

  clockMode++;

  if (
      clockMode > 3
  ) {

    clockMode =
        0;
  }

  requestRedraw();
}

// ============================================================
// GET CLOCK MODE
// ============================================================

int getClockMode() {

  return clockMode;
}

// ============================================================
// STOPWATCH TOGGLE
// ============================================================

void toggleStopwatch() {

  if (
      stopwatchRunning
  ) {

    stopwatchElapsedMs +=
        millis() -
        stopwatchStartMs;

    stopwatchRunning =
        false;
  }

  else {

    stopwatchStartMs =
        millis();

    stopwatchRunning =
        true;
  }

  requestRedraw();
}

// ============================================================
// STOPWATCH RESET
// ============================================================

void resetStopwatch() {

  stopwatchRunning =
      false;

  stopwatchStartMs =
      0;

  stopwatchElapsedMs =
      0;

  requestRedraw();
}

// ============================================================
// TIMER EDIT DISPLAY STATE
// ============================================================

void setTimerEditState(
    bool active,
    unsigned int hours,
    unsigned int minutes,
    unsigned int seconds,
    int field,
    int action
) {

  timerEditMode =
      active;

  timerEditHours =
      hours;

  timerEditMinutes =
      minutes;

  timerEditSeconds =
      seconds;

  if (
      field < 0
  ) {

    timerEditField =
        0;
  }

  else if (
      field > 2
  ) {

    timerEditField =
        2;
  }

  else {

    timerEditField =
        field;
  }

  if (
      action < 0
  ) {

    timerEditAction =
        0;
  }

  else if (
      action > 3
  ) {

    timerEditAction =
        3;
  }

  else {

    timerEditAction =
        action;
  }

  requestRedraw();
}

// ============================================================
// DISPLAY SETTINGS
// ============================================================

void startDisplaySettings() {
  displaySettingsSelection = 0;
  displaySettingsEditMode = false;
  requestRedraw();
}

int getDisplaySettingsSelection() {
  return displaySettingsSelection;
}

bool isDisplaySettingsEditMode() {
  return displaySettingsEditMode;
}

static void adjustDisplaySetting(int direction) {

  if (displaySettingsSelection == 0) {
    const int values[] = {0, 5, 10, 15, 30, 60, 120};
    const int count = sizeof(values) / sizeof(values[0]);
    int current = settings::getScreenTimeoutSec();
    int idx = 0;

    for (int i = 0; i < count; i++) {
      if (values[i] == current) {
        idx = i;
        break;
      }
    }

    idx += direction;

    if (idx >= count) idx = 0;
    if (idx < 0) idx = count - 1;

    settings::setScreenTimeoutSec(values[idx]);
    lastDisplayActivityMs = millis();
  }
  else if (displaySettingsSelection == 1) {
    // Always On is represented by a zero-second timeout.
    settings::setScreenTimeoutSec(
        settings::getScreenTimeoutSec() == 0 ? 30 : 0
    );
    lastDisplayActivityMs = millis();
  }
  else if (displaySettingsSelection == 2) {
    int rotation = settings::getOrientation() == 2 ? 0 : 2;
    setOrientation(rotation);
  }
}

void displaySettingsSingleAction() {

  if (displaySettingsEditMode) {
    adjustDisplaySetting(1);
    lastDisplayActivityMs = millis();
    requestRedraw();
    return;
  }

  displaySettingsSelection++;
  if (displaySettingsSelection > 2) displaySettingsSelection = 0;
  lastDisplayActivityMs = millis();
  requestRedraw();
}

void displaySettingsHoldRepeat() {
  if (!displaySettingsEditMode) return;
  adjustDisplaySetting(1);
  lastDisplayActivityMs = millis();
  requestRedraw();
}

void displaySettingsDoubleAction() {

  if (displaySettingsEditMode) {
    displaySettingsEditMode = false;
    lastDisplayActivityMs = millis();
    requestRedraw();
    return;
  }

  displaySettingsEditMode = true;
  lastDisplayActivityMs = millis();
  requestRedraw();
}

void displaySettingsTripleAction() {
  displaySettingsEditMode = false;
  currentScreen = SCR_SETTINGS;
  requestRedraw();
}

// ============================================================
// SOUND SETTINGS CONTROLS
// ============================================================

void startSoundSettings() {
  soundSettingsSelection = 0;
  soundSettingsEditMode = false;
  requestRedraw();
}

int getSoundSettingsSelection() {
  return soundSettingsSelection;
}

bool isSoundSettingsEditMode() {
  return soundSettingsEditMode;
}

static void adjustSoundSetting(int direction) {

  if (soundSettingsSelection == 0) {
    settings::setSoundEnabled(!settings::getSoundEnabled());
    if (!settings::getSoundEnabled()) {
      alerts::buzzerStop();
    }
  }
  else if (soundSettingsSelection == 1) {
    int volume = settings::getSoundVolume();
    volume += direction * 10;
    if (volume > 100) volume = 0;
    if (volume < 0) volume = 100;
    settings::setSoundVolume(volume);
    if (volume == 0) {
      alerts::buzzerStop();
    }
  }
  else if (soundSettingsSelection == 2) {
    // DND suppresses non-critical notifications only.
    // Important alarms and safety alerts remain unaffected.
    wellness::toggleDnd();
  }
  else if (soundSettingsSelection == 3) {
    settings::setClickSoundEnabled(!settings::getClickSoundEnabled());
  }
}

void soundSettingsSingleAction() {

  if (soundSettingsEditMode) {
    adjustSoundSetting(1);
    requestRedraw();
    return;
  }

  soundSettingsSelection++;
  if (soundSettingsSelection > 3) soundSettingsSelection = 0;
  requestRedraw();
}

void soundSettingsHoldRepeat() {
  if (!soundSettingsEditMode || soundSettingsSelection != 1) return;
  adjustSoundSetting(1);
  requestRedraw();
}

void soundSettingsDoubleAction() {

  if (soundSettingsEditMode) {
    soundSettingsEditMode = false;
    requestRedraw();
    return;
  }

  soundSettingsEditMode = true;
  requestRedraw();
}

void soundSettingsTripleAction() {
  soundSettingsEditMode = false;
  currentScreen = SCR_SETTINGS;
  requestRedraw();
}

// ============================================================
// DISPLAY ACTIVITY / TIMEOUT
// ============================================================

void noteActivity() {
  lastDisplayActivityMs = millis();
  if (asleep) wake();
}

void updateTimeout() {

  if (!oledFound || asleep) return;

  int timeoutSec = settings::getScreenTimeoutSec();
  if (timeoutSec <= 0) return;

  // Keep critical/interactive screens awake.
  if (
      currentScreen == SCR_ALARM_SETUP ||
      currentScreen == SCR_ALERT_ALARM ||
      currentScreen == SCR_ALERT_REMINDER ||
      currentScreen == SCR_ALERT_TIMER_DONE ||
      currentScreen == SCR_ALERT_FALL ||
      currentScreen == SCR_ALERT_POSTURE
  ) {
    return;
  }

  if (millis() - lastDisplayActivityMs >= (unsigned long)timeoutSec * 1000UL) {
    sleep();
  }
}

// ============================================================
// IS ASLEEP
// ============================================================

bool isAsleep() {

  return asleep;
}

// ============================================================
// SLEEP
// ============================================================

void sleep() {

  if (
      !oledFound
  ) {

    return;
  }

  oled.clearDisplay();

  oled.display();

  oled.ssd1306_command(
      SSD1306_DISPLAYOFF
  );

  asleep =
      true;
}

// ============================================================
// WAKE
// ============================================================

void wake() {

  if (
      !oledFound
  ) {

    return;
  }

  oled.ssd1306_command(
      SSD1306_DISPLAYON
  );

  asleep =
      false;

  requestRedraw();
}

// ============================================================
// REQUEST REDRAW
// ============================================================


void setOrientation(int rot) {
  int r = (rot == 2) ? 2 : 0;
  settings::setOrientation(r);
  oled.setRotation(r);
  requestRedraw();
}

void requestRedraw() {

  redrawNeeded =
      true;
}

// ============================================================
// RENDER
// ============================================================

void render() {

  if (
      !oledFound ||
      asleep
  ) {

    return;
  }

  unsigned long now =
      millis();

  bool timeToAnimate =
      (
          currentScreen ==
          SCR_HOME
      )
      ||
      (
          currentScreen ==
          SCR_HEART_RATE
      )
      ||
      (
          currentScreen ==
          SCR_POSTURE
      )
      ||
      (
          currentScreen ==
          SCR_POSTURE_CALIBRATING
      )
      ||
      (
          currentScreen ==
          SCR_ACTIVITY
      )
      ||
      (
          currentScreen ==
          SCR_WELLNESS
      )
      ||
      (
          currentScreen ==
          SCR_BREATHING
      )
      ||
      (
          currentScreen ==
          SCR_GOALS
      )
      ||
      (
          currentScreen ==
          SCR_CLOCK &&

          clockMode ==
          2 &&

          stopwatchRunning
      );

  if (
      !redrawNeeded &&
      !timeToAnimate
  ) {

    return;
  }

  if (
      now -
      lastRenderMs <
      RENDER_INTERVAL_MS
  ) {

    return;
  }

  lastRenderMs =
      now;

  redrawNeeded =
      false;

  switch (
      currentScreen
  ) {

    case SCR_STARTUP:

      drawStartup();

      break;

    case SCR_HOME:

      drawHome();

      break;

    case SCR_MENU:

      drawMenu();

      break;

    case SCR_HEART_RATE:

      if (
          hrSensor::isRealtimeMode()
      ) {

        drawHeartRateRealtime();
      }

      else if (
          hrSensor::hasResult()
      ) {

        drawHeartRateResult();
      }

      else if (
          hrSensor::scanFailed()
      ) {

        drawHeartRateFailed();
      }

      else if (
          hrSensor::isScanning()
      ) {

        drawHeartRateScanning();
      }

      else {

        drawHeartRateIdle();
      }

      break;

    case SCR_POSTURE:

      drawPosture();

      break;

    case SCR_POSTURE_SETUP:

      drawPostureSetup();

      break;

    case SCR_POSTURE_CALIBRATING:

      if (
          posture::isCalibrating()
      ) {

        drawPostureCalibrating();
      }

      else {

        drawPostureCalibrated();
      }

      break;

    case SCR_ACTIVITY:

      drawActivity();

      break;

    case SCR_WELLNESS:

      drawWellness();

      break;

    case SCR_BREATHING:

      drawBreathing();

      break;

    case SCR_GOALS:

      drawGoals();

      break;

    case SCR_CLOCK:

      if (
          clockMode ==
          0
      ) {

        drawClock();
      }

      else if (
          clockMode ==
          1
      ) {

        drawClockTimer();
      }

      else if (
          clockMode ==
          2
      ) {

        drawClockStopwatch();
      }

      else {

        drawClockAlarm();
      }

      break;

    case SCR_HR_HISTORY:

      drawHRHistory();

      break;

    case SCR_SPO2_HISTORY:

      drawSpO2History();

      break;

    case SCR_BATTERY:

      drawBattery();

      break;

    case SCR_REMINDERS:

      drawReminders();

      break;

    case SCR_SETTINGS:

      drawSettingsMenu();

      break;

    case SCR_ALARM_LIST:

      drawAlarmList();

      break;

    case SCR_ALARM_SETUP:

      drawAlarmSetup();

      break;

    case SCR_SETTINGS_WIFI:

      drawSettingsWiFi();

      break;

    case SCR_SETTINGS_POSTURE:

      drawSettingsPosture();

      break;

    case SCR_SETTINGS_DISPLAY:

      drawSettingsDisplay();

      break;

    case SCR_SETTINGS_SOUND:

      drawSettingsSound();

      break;

    case SCR_SETTINGS_SYSTEM:

      drawSettingsSystem();

      break;

    case SCR_DIAGNOSTICS:

      drawDiagnostics();

      break;

    case SCR_ABOUT_SYSTEM:

      drawAboutSystem();

      break;

    case SCR_ALERT_ALARM:

      drawAlarmAlert();

      break;

    case SCR_ALERT_REMINDER:

      drawReminderAlert();

      break;

    case SCR_ALERT_TIMER_DONE:

      drawTimerDone();

      break;

    case SCR_ALERT_FALL:

      drawFallAlert();

      break;

    case SCR_ALERT_POSTURE:

      drawPostureAlert();

      break;

    case SCR_LOW_POWER:

      drawLowPower();

      break;

    default:

      drawHome();

      break;
  }
}

} // namespace display
