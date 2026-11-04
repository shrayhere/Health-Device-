#include "ble_manager.h"

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#include "settings.h"
#include "battery.h"
#include "sensors.h"
#include "posture.h"
#include "activity.h"
#include "wifi_manager.h"
#include "alarms.h"
#include "reminders.h"
#include "history.h"
#include "display.h"
#include "config.h"
#include "alerts.h"
#include "time_manager.h"

// ============================================================
// BLE CONFIG
// ============================================================

static const char* DEVICE_NAME =
    "HealthDevice";

static const char* SERVICE_UUID =
    "12345678-1234-1234-1234-123456789000";

static const char* STATUS_UUID =
    "12345678-1234-1234-1234-123456789003";

static const char* COMMAND_UUID =
    "12345678-1234-1234-1234-123456789004";

static const char* DATA_UUID =
    "12345678-1234-1234-1234-123456789005";

// ============================================================
// BLE OBJECTS
// ============================================================

static BLEServer* bleServer = nullptr;

static BLECharacteristic* statusCharacteristic = nullptr;
static BLECharacteristic* commandCharacteristic = nullptr;
static BLECharacteristic* dataCharacteristic = nullptr;

static bool deviceConnected = false;


// ============================================================
// FORWARD DECLARATIONS
// ============================================================

static void sendState();
static void sendLiveData();


// ============================================================
// BLE SERVER CALLBACKS
// ============================================================

class ServerCallbacks : public BLEServerCallbacks {

  void onConnect(BLEServer* server) override {

    deviceConnected = true;

    // Multi-Device Support: Keep advertising so both laptop and mobile can connect simultaneously!
    BLEDevice::startAdvertising();

    // Short connection status.
    if (statusCharacteristic) {
      statusCharacteristic->setValue("CONNECTED");
      statusCharacteristic->notify();
    }
  }

  void onDisconnect(BLEServer* server) override {

    if (server && server->getConnectedCount() == 0) {
      deviceConnected = false;
    }

    BLEDevice::startAdvertising();
  }
};


// ============================================================
// CHUNKED NOTIFICATION
//
// Default BLE payload can be only ~20 bytes.
// Therefore long JSON is split into multiple notifications.
//
// Format:
// @S0/5:{....
// @S1/5:....
// @S2/5:....
// ...
//
// The Flutter app can reconstruct the original JSON by joining
// the chunk data in sequence order.
// ============================================================

static void sendChunked(
    BLECharacteristic* characteristic,
    const String& payload
) {
  if (!deviceConnected || !characteristic) {
    return;
  }

  // Direct send for payloads up to 180 bytes or when MTU is negotiated
  if (payload.length() <= 180) {
    characteristic->setValue(payload.c_str());
    characteristic->notify();
    return;
  }

  // For longer payloads (like state dump or history), chunk safely with 25ms pacing
  const int DATA_SIZE = 64;
  int total = (payload.length() + DATA_SIZE - 1) / DATA_SIZE;
  if (total <= 0) total = 1;

  for (int index = 0; index < total; index++) {
    int start = index * DATA_SIZE;
    String chunk = payload.substring(start, start + DATA_SIZE);
    String packet = "@S" + String(index) + "/" + String(total) + ":" + chunk;

    characteristic->setValue(packet.c_str());
    characteristic->notify();
    delay(25);
  }
}

// ============================================================
// GET CURRENT DEVICE STATE
// ============================================================

static String buildStateJson() {

  int batteryPercent =
      battery::getPercent();

  String json = "{";

  json += "\"device\":\"HealthDevice\",";
  json += "\"connected\":true,";
  json += "\"battery\":";
  json += batteryPercent;
  json += ",";

  json += "\"sound\":";
  json +=
      settings::getSoundEnabled()
          ? "true"
          : "false";

  json += ",";

  json += "\"volume\":";
  json +=
      settings::getSoundVolume();

  json += ",";

  json += "\"clickSound\":";
  json +=
      settings::getClickSoundEnabled()
          ? "true"
          : "false";

  json += ",\"timeout\":";
  json += settings::getScreenTimeoutSec();

  json += ",\"orientation\":";
  json += settings::getOrientation();

  json += ",\"clock24h\":";
  json += settings::getUse24Hour() ? "true" : "false";

  json += ",\"ledHigh\":";
  json += settings::getLedHigh() ? "true" : "false";

  json += ",\"alarmCount\":";
  json += alarms::count();

  json += ",\"reminderCount\":";
  json += reminders::count();

  // Full Alarms Serialization for 2-way sync
  json += ",\"alarms\":[";
  bool firstAlarm = true;
  for (int i = 0; i < MAX_ALARMS; i++) {
    const Alarm& a = alarms::get(i);
    if (a.used) {
      if (!firstAlarm) json += ",";
      firstAlarm = false;
      json += "{\"id\":";
      json += i;
      json += ",\"h\":";
      json += a.hour;
      json += ",\"m\":";
      json += a.minute;
      json += ",\"en\":";
      json += a.enabled ? "true" : "false";
      json += ",\"days\":\"";
      for (int d = 0; d < 7; d++) {
        json += a.days[d] ? '1' : '0';
      }
      json += "\",\"r\":";
      json += a.r;
      json += ",\"g\":";
      json += a.g;
      json += ",\"b\":";
      json += a.b;
      json += "}";
    }
  }
  json += "]";

  // Full Reminders Serialization for 2-way sync
  json += ",\"reminders\":[";
  bool firstRem = true;
  for (int i = 0; i < MAX_REMINDERS; i++) {
    const Reminder& r = reminders::get(i);
    if (r.used) {
      if (!firstRem) json += ",";
      firstRem = false;
      json += "{\"id\":";
      json += i;
      json += ",\"h\":";
      json += r.hour;
      json += ",\"m\":";
      json += r.minute;
      json += ",\"en\":";
      json += r.enabled ? "true" : "false";
      json += ",\"daily\":";
      json += r.repeatDaily ? "true" : "false";
      json += ",\"name\":\"";
      json += r.name;
      json += "\"}";
    }
  }
  json += "]";

  // Optical vitals
  int hr = hrSensor::getResultBPM();
  if (hr <= 0) {
    hr = hrSensor::getRealtimeBPM();
  }
  if (hr > 0) {
    json += ",\"hr\":";
    json += hr;
  }

  int spo2 = hrSensor::getSpO2();
  if (spo2 > 0) {
    json += ",\"spo2\":";
    json += spo2;
  }

  // Motion and activity
  unsigned long steps = activity::getSteps();
  if (steps == 0) {
    steps = motionSensor::getStepCount();
  }
  json += ",\"steps\":";
  json += steps;

  json += ",\"distance\":";
  json += String(activity::getDistanceKm(), 2);

  json += ",\"calories\":";
  json += activity::getCalories();

  json += ",\"activeMin\":";
  json += activity::getActiveMinutes();

  // Posture
  json += ",\"posture_good\":";
  json += posture::isGood() ? "true" : "false";

  json += ",\"posture_tilt\":";
  json += String(posture::getDeviationDeg(), 1);

  json += ",\"posture_calibrated\":";
  json += posture::hasBaseline() ? "true" : "false";

  // Wi-Fi
  json += ",\"wifi_connected\":";
  json += wifiManager::isConnected() ? "true" : "false";

  json += ",\"wifi_ssid\":\"";
  json += wifiManager::getSSID();
  json += "\"";

  json += ",\"wifi_saved_count\":";
  json += wifiManager::getSavedNetworkCount();

  json += "}";

  return json;
}


// ============================================================
// SEND DEVICE STATE
//
// State is sent through DATA_UUID (...9005).
// It is NOT sent through the heartbeat/status characteristic.
// ============================================================

static void sendState() {

  if (!deviceConnected ||
      !dataCharacteristic) {
    return;
  }

  String json =
      buildStateJson();

  sendChunked(
      dataCharacteristic,
      json
  );
}


// ============================================================
// SEND LIVE DATA
//
// Currently we expose battery because that is an actual
// verified API in the current firmware.
//
// More live metrics can be added later after their exact
// firmware APIs are verified.
// ============================================================

static void sendLiveData() {
  if (!deviceConnected || !dataCharacteristic) {
    return;
  }

  int hr = hrSensor::getResultBPM();
  if (hr <= 0) {
    hr = hrSensor::getRealtimeBPM();
  }

  int spo2 = hrSensor::getSpO2();

  unsigned long steps = activity::getSteps();
  if (steps == 0) {
    steps = motionSensor::getStepCount();
  }

  int bat = battery::getPercent();

  String json = "{";
  json += "\"device\":\"HealthDevice\",";
  json += "\"connected\":true,";
  json += "\"battery\":";
  json += bat;

  if (hr > 0) {
    json += ",\"hr\":";
    json += hr;
  }

  if (spo2 > 0) {
    json += ",\"spo2\":";
    json += spo2;
  }

  json += ",\"steps\":";
  json += steps;

  json += ",\"distance\":";
  json += String(activity::getDistanceKm(), 2);

  json += ",\"calories\":";
  json += activity::getCalories();

  json += ",\"activeMin\":";
  json += activity::getActiveMinutes();

  json += ",\"posture_good\":";
  json += posture::isGood() ? "true" : "false";

  json += ",\"posture_tilt\":";
  json += String(posture::getDeviationDeg(), 1);

  json += ",\"posture_calibrated\":";
  json += posture::hasBaseline() ? "true" : "false";

  json += ",\"wifi_connected\":";
  json += wifiManager::isConnected() ? "true" : "false";

  json += "}";

  // This is ~150-180 bytes, so sendChunked will deliver it directly as a single packet!
  sendChunked(dataCharacteristic, json);
}

// ============================================================
// JSON HELPERS
// ============================================================

static bool extractBool(
    const String& json,
    const char* key,
    bool& value
) {

  String search =
      "\"" +
      String(key) +
      "\"";

  int keyPos =
      json.indexOf(search);

  if (keyPos < 0) {
    return false;
  }

  int colon =
      json.indexOf(
          ':',
          keyPos
      );

  if (colon < 0) {
    return false;
  }

  String v =
      json.substring(
          colon + 1
      );

  v.trim();

  if (v.startsWith("true")) {

    value = true;

    return true;
  }

  if (v.startsWith("false")) {

    value = false;

    return true;
  }

  return false;
}


static bool extractInt(
    const String& json,
    const char* key,
    int& value
) {

  String search =
      "\"" +
      String(key) +
      "\"";

  int keyPos =
      json.indexOf(search);

  if (keyPos < 0) {
    return false;
  }

  int colon =
      json.indexOf(
          ':',
          keyPos
      );

  if (colon < 0) {
    return false;
  }

  String v =
      json.substring(
          colon + 1
      );

  v.trim();

  int end =
      v.indexOf(',');

  if (end < 0) {

    end =
        v.indexOf('}');
  }

  if (end >= 0) {

    v =
        v.substring(
            0,
            end
        );
  }

  v.trim();

  if (v.length() == 0) {
    return false;
  }

  value =
      v.toInt();

  return true;
}


// ============================================================
// COMMAND HANDLER
// ============================================================

class CommandCallbacks :
    public BLECharacteristicCallbacks {

  void onWrite(
      BLECharacteristic* characteristic
  ) override {

    String command =
        characteristic->getValue().c_str();

    if (command.length() == 0) {
      return;
    }


    // --------------------------------------------------------
    // GET STATE / PING
    // --------------------------------------------------------

    if (command == "GET_STATE" || command == "PING") {
      sendState();
      return;
    }


    // --------------------------------------------------------
    // SOUND SETTINGS (FAST COMPACT COMMANDS & JSON FALLBACK)
    // --------------------------------------------------------

    // BLE DATE & TIME SYNCHRONIZATION (No Wi-Fi needed)
    if (command.startsWith("SET_TIME:") || command.startsWith("SYNC_TIME:")) {
      int colon = command.indexOf(':');
      String s = command.substring(colon + 1);
      int p1 = s.indexOf(',');
      int p2 = s.indexOf(',', p1 + 1);
      int p3 = s.indexOf(',', p2 + 1);
      int p4 = s.indexOf(',', p3 + 1);
      int p5 = s.indexOf(',', p4 + 1);
      if (p1 > 0 && p2 > p1 && p3 > p2 && p4 > p3 && p5 > p4) {
        int yr = s.substring(0, p1).toInt();
        int mo = s.substring(p1 + 1, p2).toInt();
        int dy = s.substring(p2 + 1, p3).toInt();
        int hr = s.substring(p3 + 1, p4).toInt();
        int mn = s.substring(p4 + 1, p5).toInt();
        int sc = s.substring(p5 + 1).toInt();
        timeManager::setTime(yr, mo, dy, hr, mn, sc);
        display::requestRedraw();
        sendState();
        return;
      }
    }

    // Compact text commands (always < 18 bytes to guarantee zero MTU truncation)
    if (command.startsWith("SET_SOUND:")) {
      settings::setSoundEnabled(command.substring(10).toInt() != 0);
      sendState();
      return;
    }
    if (command.startsWith("SET_CLICK:")) {
      settings::setClickSoundEnabled(command.substring(10).toInt() != 0);
      sendState();
      return;
    }
    if (command.startsWith("SET_MEASURE:")) {
      settings::setMeasurementSoundEnabled(command.substring(12).toInt() != 0);
      sendState();
      return;
    }
    if (command.startsWith("SET_VOL:")) {
      int v = constrain(command.substring(8).toInt(), 0, 100);
      settings::setSoundVolume(v);
      if (settings::getSoundEnabled() && v > 0) {
        int duty = map(v, 0, 100, 0, 255);
        analogWrite(PIN_BUZZER, duty);
        delay(35);
        analogWrite(PIN_BUZZER, 0);
      }
      sendState();
      return;
    }

    bool soundChanged = false;
    bool boolVal = false;
    int intVal = 0;

    if (extractBool(command, "set_sound", boolVal)) {
      settings::setSoundEnabled(boolVal);
      soundChanged = true;
    }

    if (extractBool(command, "set_click_sound", boolVal)) {
      settings::setClickSoundEnabled(boolVal);
      soundChanged = true;
    }

    if (extractBool(command, "set_measure_sound", boolVal)) {
      settings::setMeasurementSoundEnabled(boolVal);
      soundChanged = true;
    }

    if (extractInt(command, "set_volume", intVal)) {
      intVal = constrain(intVal, 0, 100);
      settings::setSoundVolume(intVal);
      soundChanged = true;
      // Play a quick physical confirmation chirp if sound enabled
      if (settings::getSoundEnabled() && intVal > 0) {
        int duty = map(intVal, 0, 100, 0, 255);
        analogWrite(PIN_BUZZER, duty);
        delay(35);
        analogWrite(PIN_BUZZER, 0);
      }
    }

    if (soundChanged) {
      sendState();
      return;
    }


    // --------------------------------------------------------
    // DISPLAY SETTINGS (TIMEOUT, ROTATION, 24H)
    // --------------------------------------------------------

    if (command.startsWith("SET_ROTATION:") || command.startsWith("SET_ORIENTATION:")) {
      int colon = command.indexOf(':');
      int rot = (command.substring(colon + 1).toInt() == 2) ? 2 : 0;
      display::setOrientation(rot);
      display::noteActivity();
      sendState();
      return;
    }

    bool dispChanged = false;

    if (extractInt(command, "set_timeout", intVal)) {
      settings::setScreenTimeoutSec(intVal);
      display::noteActivity();
      dispChanged = true;
    }

    if (extractInt(command, "set_orientation", intVal)) {
      int rot = (intVal == 2) ? 2 : 0;
      display::setOrientation(rot);
      display::noteActivity();
      dispChanged = true;
    }

    if (extractBool(command, "set_clock_24h", boolVal)) {
      settings::setUse24Hour(boolVal);
      display::requestRedraw();
      dispChanged = true;
    }

    if (dispChanged) {
      sendState();
      return;
    }


    // --------------------------------------------------------
    // LED SETTINGS & IMMEDIATE TEST
    // --------------------------------------------------------

    if (extractBool(command, "set_led_high", boolVal) || extractBool(command, "set_led_enabled", boolVal)) {
      settings::setLedHigh(boolVal);
      sendState();
      return;
    }

    if (command.startsWith("TEST_LED:") || command.startsWith("SET_LED:")) {
      // Format: TEST_LED:R,G,B (e.g. TEST_LED:255,0,0)
      int colon = command.indexOf(':');
      String vals = command.substring(colon + 1);
      int c1 = vals.indexOf(',');
      int c2 = vals.lastIndexOf(',');
      if (c1 > 0 && c2 > c1) {
        int r = constrain(vals.substring(0, c1).toInt(), 0, 255);
        int g = constrain(vals.substring(c1 + 1, c2).toInt(), 0, 255);
        int b = constrain(vals.substring(c2 + 1).toInt(), 0, 255);

        // Non-blocking 3-second hardware override protected from updateStatusLed()
        alerts::overrideRGB(r, g, b, 3000);
      }
      sendState();
      return;
    }


    // --------------------------------------------------------
    // ALARMS HARDWARE SYNC
    // --------------------------------------------------------

    if (command == "CLEAR_ALARMS") {
      for (int i = 0; i < MAX_ALARMS; i++) {
        alarms::remove(i);
      }
      sendState();
      return;
    }

    if (command.startsWith("ADD_ALARM:")) {
      // Format: ADD_ALARM:H,M,EN,DAYS,R,G,B (e.g. ADD_ALARM:7,30,1,1111100,0,255,255)
      String data = command.substring(10);
      int p1 = data.indexOf(',');
      int p2 = data.indexOf(',', p1 + 1);
      int p3 = data.indexOf(',', p2 + 1);
      if (p1 > 0 && p2 > p1) {
        int h = data.substring(0, p1).toInt();
        int m = data.substring(p1 + 1, p2).toInt();
        bool en = (p3 > 0) ? (data.substring(p2 + 1, p3).toInt() == 1) : true;

        int p4 = (p3 > 0) ? data.indexOf(',', p3 + 1) : -1;
        String daysStr = (p3 > 0) ? ((p4 > 0) ? data.substring(p3 + 1, p4) : data.substring(p3 + 1)) : "1111111";

        uint8_t r = 255, g = 0, b = 0;
        if (p4 > 0) {
          int p5 = data.indexOf(',', p4 + 1);
          int p6 = (p5 > 0) ? data.indexOf(',', p5 + 1) : -1;
          if (p5 > 0 && p6 > 0) {
            r = constrain(data.substring(p4 + 1, p5).toInt(), 0, 255);
            g = constrain(data.substring(p5 + 1, p6).toInt(), 0, 255);
            b = constrain(data.substring(p6 + 1).toInt(), 0, 255);
          }
        }

        bool daysMask[7];
        for (int d = 0; d < 7; d++) {
          daysMask[d] = (d < daysStr.length()) ? (daysStr.charAt(d) == '1') : true;
        }

        if (alarms::count() < MAX_ALARMS) {
          alarms::add(h, m, daysMask, r, g, b);
          for (int i = 0; i < MAX_ALARMS; i++) {
            const Alarm& a = alarms::get(i);
            if (a.used && a.hour == h && a.minute == m) {
              alarms::setEnabled(i, en);
              alarms::setColor(i, r, g, b);
              break;
            }
          }
        }
      }
      sendState();
      return;
    }


    // --------------------------------------------------------
    // REMINDERS HARDWARE SYNC
    // --------------------------------------------------------

    if (command == "CLEAR_REMINDERS") {
      for (int i = 0; i < MAX_REMINDERS; i++) {
        reminders::remove(i);
      }
      sendState();
      return;
    }

    if (command.startsWith("ADD_REMINDER:")) {
      // Format: ADD_REMINDER:H,M,EN,DAILY,NAME
      String data = command.substring(13);
      int p1 = data.indexOf(',');
      int p2 = data.indexOf(',', p1 + 1);
      int p3 = data.indexOf(',', p2 + 1);
      int p4 = data.indexOf(',', p3 + 1);
      if (p1 > 0 && p2 > p1 && p3 > p2 && p4 > p3) {
        int h = data.substring(0, p1).toInt();
        int m = data.substring(p1 + 1, p2).toInt();
        bool en = (data.substring(p2 + 1, p3).toInt() == 1);
        bool daily = (data.substring(p3 + 1, p4).toInt() == 1);
        String name = data.substring(p4 + 1);
        name.trim();

        if (reminders::count() < MAX_REMINDERS) {
          reminders::add(name.c_str(), h, m, daily);
          for (int i = 0; i < MAX_REMINDERS; i++) {
            const Reminder& r = reminders::get(i);
            if (r.used && r.hour == h && r.minute == m) {
              reminders::setEnabled(i, en);
              break;
            }
          }
        }
      }
      sendState();
      return;
    }


    // --------------------------------------------------------
    // START MEASUREMENT / SCAN
    // --------------------------------------------------------

    if (command == "START_MEASUREMENT" || command == "START_HR_SCAN" || command == "START_SPO2_SCAN") {
      hrSensor::startScan();
      sendState();
      return;
    }


    // --------------------------------------------------------
    // CALIBRATE POSTURE
    // --------------------------------------------------------

    if (command == "CALIBRATE_POSTURE") {
      posture::startCalibration();
      sendState();
      return;
    }


    // --------------------------------------------------------
    // RESET STEPS
    // --------------------------------------------------------

    if (command == "RESET_STEPS") {
      motionSensor::resetStepCount();
      activity::resetToday();
      sendState();
      return;
    }

    // --------------------------------------------------------
    // WI-FI HARDWARE SYNC (MULTIPLE NETWORKS)
    // --------------------------------------------------------

    if (command.startsWith("ADD_WIFI:") || command.startsWith("SET_WIFI:")) {
      int colon = command.indexOf(':');
      String data = command.substring(colon + 1);
      int p1 = data.indexOf(',');
      if (p1 > 0) {
        String ssid = data.substring(0, p1);
        ssid.trim();
        int p2 = data.indexOf(',', p1 + 1);
        String pass;
        int prio = 1;
        if (p2 > p1) {
          pass = data.substring(p1 + 1, p2);
          prio = data.substring(p2 + 1).toInt();
          if (prio < 1) prio = 1;
        } else {
          pass = data.substring(p1 + 1);
        }
        pass.trim();

        if (ssid.length() > 0) {
          wifiManager::addOrUpdateNetwork(ssid, pass, prio);
          Serial.print("BLE: Saved Wi-Fi to hardware: ");
          Serial.println(ssid);
        }
      }
      sendState();
      return;
    }

    if (command.startsWith("REMOVE_WIFI:") || command.startsWith("DEL_WIFI:")) {
      int colon = command.indexOf(':');
      String ssid = command.substring(colon + 1);
      ssid.trim();
      if (ssid.length() > 0) {
        wifiManager::removeNetwork(ssid);
      }
      sendState();
      return;
    }

    if (command == "CLEAR_WIFI") {
      wifiManager::clearAllNetworks();
      sendState();
      return;
    }


    // --------------------------------------------------------
    // GET_HISTORY — sends HR + SpO2 history as JSON
    // --------------------------------------------------------

    if (command == "GET_HISTORY") {
      healthHistory::Record hrRecs[healthHistory::MAX_RECORDS];
      healthHistory::Record spRecs[healthHistory::MAX_RECORDS];
      int hrCount  = healthHistory::getHeartRate(hrRecs, healthHistory::MAX_RECORDS);
      int spCount  = healthHistory::getSpO2(spRecs, healthHistory::MAX_RECORDS);

      String json = "{\"history\":{\"hr\":[";
      for (int i = 0; i < hrCount; i++) {
        if (i > 0) json += ",";
        json += "{\"v\":";
        json += hrRecs[i].value;
        json += ",\"ts\":\"";
        char buf[20];
        snprintf(buf, sizeof(buf), "%04d-%02d-%02dT%02d:%02d",
                 hrRecs[i].year, hrRecs[i].month, hrRecs[i].day,
                 hrRecs[i].hour, hrRecs[i].minute);
        json += buf;
        json += "\"}";
      }
      json += "],\"spo2\":[";
      for (int i = 0; i < spCount; i++) {
        if (i > 0) json += ",";
        json += "{\"v\":";
        json += spRecs[i].value;
        json += ",\"ts\":\"";
        char buf[20];
        snprintf(buf, sizeof(buf), "%04d-%02d-%02dT%02d:%02d",
                 spRecs[i].year, spRecs[i].month, spRecs[i].day,
                 spRecs[i].hour, spRecs[i].minute);
        json += buf;
        json += "\"}";
      }
      json += "]}}";

      sendChunked(dataCharacteristic, json);
      return;
    }
    if (command == "RECONNECT_WIFI") {
      wifiManager::reconnectBest();
      sendState();
      return;
    }
  }
};


// ============================================================
// BLE BEGIN
// ============================================================

void bleBegin() {

  BLEDevice::init(
      DEVICE_NAME
  );
  BLEDevice::setMTU(517);


  // ----------------------------------------------------------
  // SERVER
  // ----------------------------------------------------------

  bleServer =
      BLEDevice::createServer();

  bleServer->setCallbacks(
      new ServerCallbacks()
  );


  // ----------------------------------------------------------
  // SERVICE
  // ----------------------------------------------------------

  BLEService* service =
      bleServer->createService(
          SERVICE_UUID
      );


  // ----------------------------------------------------------
  // STATUS
  // 9003
  // ----------------------------------------------------------

  statusCharacteristic =
      service->createCharacteristic(
          STATUS_UUID,
          BLECharacteristic::PROPERTY_READ |
          BLECharacteristic::PROPERTY_NOTIFY
      );

  statusCharacteristic->addDescriptor(
      new BLE2902()
  );

  statusCharacteristic->setValue(
      "READY"
  );


  // ----------------------------------------------------------
  // COMMAND
  // 9004
  // ----------------------------------------------------------

  commandCharacteristic =
      service->createCharacteristic(
          COMMAND_UUID,
          BLECharacteristic::PROPERTY_WRITE |
          BLECharacteristic::PROPERTY_WRITE_NR
      );

  commandCharacteristic->setCallbacks(
      new CommandCallbacks()
  );


  // ----------------------------------------------------------
  // DATA
  // 9005
  // ----------------------------------------------------------

  dataCharacteristic =
      service->createCharacteristic(
          DATA_UUID,
          BLECharacteristic::PROPERTY_READ |
          BLECharacteristic::PROPERTY_NOTIFY
      );

  dataCharacteristic->addDescriptor(
      new BLE2902()
  );


  // ----------------------------------------------------------
  // START SERVICE
  // ----------------------------------------------------------

  service->start();


  // ----------------------------------------------------------
  // ADVERTISING
  // ----------------------------------------------------------

  BLEAdvertising* advertising =
      BLEDevice::getAdvertising();

  advertising->addServiceUUID(
      SERVICE_UUID
  );

  advertising->setScanResponse(
      true
  );

  BLEDevice::startAdvertising();
}


// ============================================================
// BLE UPDATE
// ============================================================

void bleUpdate() {
  if (!deviceConnected) {
    return;
  }

  static unsigned long lastLiveUpdate = 0;
  static unsigned long lastStateUpdate = 0;
  unsigned long now = millis();

  // Fast live stream for Battery, SpO2, Heart Rate, Steps, Posture (every 1.5s)
  if (now - lastLiveUpdate >= 1500) {
    lastLiveUpdate = now;
    sendLiveData();
  }

  // Periodic full state sync for alarms, reminders, settings (every 15s)
  if (now - lastStateUpdate >= 15000) {
    lastStateUpdate = now;
    sendState();
  }
}