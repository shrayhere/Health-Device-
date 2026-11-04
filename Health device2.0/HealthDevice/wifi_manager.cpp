#include "wifi_manager.h"

#include <WiFi.h>
#include <Preferences.h>
#include <time.h>

// ======================================================
// USER WIFI CONFIGURATION & NVS STORAGE
// ======================================================

namespace {

  struct SavedNetwork {
    char ssid[33];
    char password[65];
    int priority;
  };

  SavedNetwork savedNetworks[wifiManager::MAX_SAVED_NETWORKS];
  int savedNetworkCount = 0;
  int currentNetworkIndex = 0;

  Preferences wifiPrefs;
  const char* PREFS_NS = "hd_wifi";

  // ====================================================
  // NTP CONFIGURATION
  // ====================================================

  const long GMT_OFFSET_SECONDS = 19800; // +5:30 IST
  const int DAYLIGHT_OFFSET_SECONDS = 0;

  const char* NTP_SERVER_1 = "pool.ntp.org";
  const char* NTP_SERVER_2 = "time.nist.gov";
  const char* NTP_SERVER_3 = "time.google.com";

  // ====================================================
  // INTERNAL STATE
  // ====================================================

  bool wifiEnabled = true;

  wifiManager::Status wifiStatus = wifiManager::WIFI_DISCONNECTED;

  unsigned long lastConnectionAttempt = 0;
  const unsigned long RECONNECT_INTERVAL = 10000UL;

  bool ntpStarted = false;
  bool timeSynced = false;
  bool firstStatusPrint = true;

  void loadNetworksFromNVS() {
    wifiPrefs.begin(PREFS_NS, false);
    savedNetworkCount = wifiPrefs.getInt("count", 0);
    if (savedNetworkCount < 0) savedNetworkCount = 0;
    if (savedNetworkCount > wifiManager::MAX_SAVED_NETWORKS) {
      savedNetworkCount = wifiManager::MAX_SAVED_NETWORKS;
    }

    for (int i = 0; i < savedNetworkCount; i++) {
      String keyS = "s_" + String(i);
      String keyP = "p_" + String(i);
      String keyPr = "pr_" + String(i);
      String s = wifiPrefs.getString(keyS.c_str(), "");
      String p = wifiPrefs.getString(keyP.c_str(), "");
      int pr = wifiPrefs.getInt(keyPr.c_str(), 1);

      strncpy(savedNetworks[i].ssid, s.c_str(), sizeof(savedNetworks[i].ssid) - 1);
      savedNetworks[i].ssid[sizeof(savedNetworks[i].ssid) - 1] = '\0';
      strncpy(savedNetworks[i].password, p.c_str(), sizeof(savedNetworks[i].password) - 1);
      savedNetworks[i].password[sizeof(savedNetworks[i].password) - 1] = '\0';
      savedNetworks[i].priority = pr;
    }

    // Default fallback if nothing saved in flash yet
    if (savedNetworkCount == 0) {
      strncpy(savedNetworks[0].ssid, "ESPTEST", sizeof(savedNetworks[0].ssid) - 1);
      savedNetworks[0].ssid[sizeof(savedNetworks[0].ssid) - 1] = '\0';
      strncpy(savedNetworks[0].password, "12345678", sizeof(savedNetworks[0].password) - 1);
      savedNetworks[0].password[sizeof(savedNetworks[0].password) - 1] = '\0';
      savedNetworks[0].priority = 1;
      savedNetworkCount = 1;
    }

    wifiPrefs.end();

    Serial.print("WiFi: Loaded ");
    Serial.print(savedNetworkCount);
    Serial.println(" saved networks from flash storage.");
  }

  void saveNetworksToNVS() {
    wifiPrefs.begin(PREFS_NS, false);
    wifiPrefs.clear();
    wifiPrefs.putInt("count", savedNetworkCount);
    for (int i = 0; i < savedNetworkCount; i++) {
      String keyS = "s_" + String(i);
      String keyP = "p_" + String(i);
      String keyPr = "pr_" + String(i);
      wifiPrefs.putString(keyS.c_str(), savedNetworks[i].ssid);
      wifiPrefs.putString(keyP.c_str(), savedNetworks[i].password);
      wifiPrefs.putInt(keyPr.c_str(), savedNetworks[i].priority);
    }
    wifiPrefs.end();

    Serial.print("WiFi: Saved ");
    Serial.print(savedNetworkCount);
    Serial.println(" networks to flash storage.");
  }

}

// ======================================================
// DISCONNECT REASON
// ======================================================

static const char* getDisconnectReason(uint8_t reason) {
  switch (reason) {
    case 1:   return "UNSPECIFIED";
    case 2:   return "AUTH_EXPIRE";
    case 3:   return "AUTH_LEAVE";
    case 4:   return "ASSOC_EXPIRE";
    case 5:   return "ASSOC_TOOMANY";
    case 6:   return "NOT_AUTHED";
    case 7:   return "NOT_ASSOCED";
    case 8:   return "ASSOC_LEAVE";
    case 9:   return "ASSOC_NOT_AUTHED";
    case 200: return "BEACON_TIMEOUT";
    case 201: return "NO_AP_FOUND";
    case 202: return "AUTH_FAIL";
    case 203: return "ASSOC_FAIL";
    case 204: return "HANDSHAKE_TIMEOUT";
    default:  return "UNKNOWN";
  }
}

// ======================================================
// WIFI EVENT HANDLER
// ======================================================

static void WiFiEvent(WiFiEvent_t event, WiFiEventInfo_t info) {
  switch (event) {
    case ARDUINO_EVENT_WIFI_STA_START:
      Serial.println("WiFi: Station started");
      break;

    case ARDUINO_EVENT_WIFI_STA_CONNECTED:
      Serial.println("WiFi: Connected to Access Point");
      break;

    case ARDUINO_EVENT_WIFI_STA_GOT_IP:
      Serial.print("WiFi: Got IP: ");
      Serial.println(WiFi.localIP());
      break;

    case ARDUINO_EVENT_WIFI_STA_DISCONNECTED:
      Serial.print("WiFi: Disconnected, Reason: ");
      Serial.println(getDisconnectReason(info.wifi_sta_disconnected.reason));
      break;

    default:
      break;
  }
}

// ======================================================
// SERIAL STATUS
// ======================================================

static void printWiFiStatus(wifiManager::Status status) {
  if (!firstStatusPrint && status == wifiStatus) {
    return;
  }
  firstStatusPrint = false;

  Serial.print("WiFi: ");
  switch (status) {
    case wifiManager::WIFI_DISABLED:
      Serial.println("OFF");
      break;

    case wifiManager::WIFI_CONNECTING:
      Serial.print("Connecting to ");
      if (savedNetworkCount > 0 && currentNetworkIndex < savedNetworkCount) {
        Serial.println(savedNetworks[currentNetworkIndex].ssid);
      } else {
        Serial.println("...");
      }
      break;

    case wifiManager::WIFI_CONNECTED:
      Serial.println("Connected");
      Serial.print("WiFi IP: ");
      Serial.println(WiFi.localIP());
      Serial.print("WiFi RSSI: ");
      Serial.print(WiFi.RSSI());
      Serial.println(" dBm");
      break;

    case wifiManager::WIFI_DISCONNECTED:
      Serial.println("Disconnected");
      break;
  }
}

// ======================================================
// PUBLIC API IMPLEMENTATION
// ======================================================

void wifiManager::begin() {
  wifiEnabled = true;
  ntpStarted = false;
  timeSynced = false;
  lastConnectionAttempt = 0;
  firstStatusPrint = true;
  currentNetworkIndex = 0;

  loadNetworksFromNVS();

  WiFi.onEvent(WiFiEvent);
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.persistent(false);

  // Start connection to the primary saved network immediately (non-blocking)
  wifiStatus = wifiManager::WIFI_CONNECTING;
  WiFi.begin(savedNetworks[currentNetworkIndex].ssid, savedNetworks[currentNetworkIndex].password);
  lastConnectionAttempt = millis();

  printWiFiStatus(wifiStatus);
}

void wifiManager::update() {
  // Wi-Fi disabled
  if (!wifiEnabled) {
    if (WiFi.status() != WL_DISCONNECTED) {
      WiFi.disconnect(true);
    }
    wifiStatus = wifiManager::WIFI_DISABLED;
    printWiFiStatus(wifiStatus);
    return;
  }

  // Connected state
  if (WiFi.status() == WL_CONNECTED) {
    if (wifiStatus != wifiManager::WIFI_CONNECTED) {
      wifiStatus = wifiManager::WIFI_CONNECTED;
      printWiFiStatus(wifiStatus);
    }

    if (!ntpStarted) {
      Serial.println("WiFi: Starting NTP sync...");
      configTime(
        GMT_OFFSET_SECONDS,
        DAYLIGHT_OFFSET_SECONDS,
        NTP_SERVER_1,
        NTP_SERVER_2,
        NTP_SERVER_3
      );
      ntpStarted = true;
      timeSynced = false;
    }

    struct tm timeInfo;
    if (!timeSynced && getLocalTime(&timeInfo, 10)) {
      timeSynced = true;
      Serial.println("WiFi: NTP time successfully synchronized.");
    }
    return;
  }

  // Not connected - handle reconnection
  timeSynced = false;
  unsigned long now = millis();

  if (now - lastConnectionAttempt >= RECONNECT_INTERVAL) {
    lastConnectionAttempt = now;

    // If multiple networks, cycle to the next saved network
    if (savedNetworkCount > 1) {
      currentNetworkIndex = (currentNetworkIndex + 1) % savedNetworkCount;
    }

    Serial.print("WiFi: Reconnecting to '");
    Serial.print(savedNetworks[currentNetworkIndex].ssid);
    Serial.println("'...");

    WiFi.disconnect(false);
    WiFi.begin(savedNetworks[currentNetworkIndex].ssid, savedNetworks[currentNetworkIndex].password);
    wifiStatus = wifiManager::WIFI_CONNECTING;
    ntpStarted = false;
    printWiFiStatus(wifiStatus);
  }

  // State update matching original robust behavior:
  // If in idle status or actively attempting connection in the first 5 seconds, status is CONNECTING (blinking).
  // Once that attempt window finishes without connection, status becomes DISCONNECTED so display is STEADY (NO non-stop blinking!).
  if (WiFi.status() == WL_IDLE_STATUS || (wifiStatus == wifiManager::WIFI_CONNECTING && (now - lastConnectionAttempt < 5000UL))) {
    wifiStatus = wifiManager::WIFI_CONNECTING;
  } else {
    wifiStatus = wifiManager::WIFI_DISCONNECTED;
  }

  printWiFiStatus(wifiStatus);
}

void wifiManager::setEnabled(bool enabled) {
  wifiEnabled = enabled;
  if (!wifiEnabled) {
    WiFi.disconnect(true);
    wifiStatus = wifiManager::WIFI_DISABLED;
    ntpStarted = false;
    timeSynced = false;
    printWiFiStatus(wifiStatus);
  } else {
    WiFi.mode(WIFI_STA);
    WiFi.setAutoReconnect(true);
    WiFi.persistent(false);
    WiFi.begin(savedNetworks[currentNetworkIndex].ssid, savedNetworks[currentNetworkIndex].password);
    wifiStatus = wifiManager::WIFI_CONNECTING;
    lastConnectionAttempt = millis();
    ntpStarted = false;
    timeSynced = false;
    printWiFiStatus(wifiStatus);
  }
}

bool wifiManager::isEnabled() {
  return wifiEnabled;
}

bool wifiManager::isConnected() {
  return wifiEnabled && (WiFi.status() == WL_CONNECTED);
}

bool wifiManager::isConnecting() {
  if (!wifiEnabled) return false;
  return wifiStatus == wifiManager::WIFI_CONNECTING;
}

bool wifiManager::isDisconnected() {
  if (!wifiEnabled) return false;
  return wifiStatus == wifiManager::WIFI_DISCONNECTED;
}

wifiManager::Status wifiManager::getStatus() {
  if (!wifiEnabled) return wifiManager::WIFI_DISABLED;
  return wifiStatus;
}

bool wifiManager::isTimeSynced() {
  return timeSynced;
}

bool wifiManager::getNetworkTime(
  int &year,
  int &month,
  int &day,
  int &hour,
  int &minute,
  int &second,
  int &weekday
) {
  if (!timeSynced) return false;
  struct tm timeInfo;
  if (!getLocalTime(&timeInfo, 10)) return false;

  year = timeInfo.tm_year + 1900;
  month = timeInfo.tm_mon + 1;
  day = timeInfo.tm_mday;
  hour = timeInfo.tm_hour;
  minute = timeInfo.tm_min;
  second = timeInfo.tm_sec;
  weekday = timeInfo.tm_wday;
  return true;
}

String wifiManager::getSSID() {
  if (WiFi.status() == WL_CONNECTED) {
    return WiFi.SSID();
  }
  if (savedNetworkCount > 0 && currentNetworkIndex < savedNetworkCount) {
    return String(savedNetworks[currentNetworkIndex].ssid);
  }
  return "";
}

int wifiManager::getRSSI() {
  if (WiFi.status() == WL_CONNECTED) {
    return WiFi.RSSI();
  }
  return 0;
}

// ======================================================
// MULTIPLE NETWORKS MANAGEMENT
// ======================================================

bool wifiManager::addOrUpdateNetwork(const String &ssid, const String &password, int priority) {
  if (ssid.length() == 0 || ssid.length() > 32) return false;

  // If the ONLY network in flash is the default "ESPTEST", replace it with the user's real network
  if (savedNetworkCount == 1 && strcmp(savedNetworks[0].ssid, "ESPTEST") == 0) {
    savedNetworkCount = 0;
  }

  // Check if exists
  int foundIdx = -1;
  for (int i = 0; i < savedNetworkCount; i++) {
    if (ssid.equalsIgnoreCase(String(savedNetworks[i].ssid))) {
      foundIdx = i;
      break;
    }
  }

  if (foundIdx >= 0) {
    // Update in-place
    strncpy(savedNetworks[foundIdx].password, password.c_str(), sizeof(savedNetworks[foundIdx].password) - 1);
    savedNetworks[foundIdx].password[sizeof(savedNetworks[foundIdx].password) - 1] = '\0';
    savedNetworks[foundIdx].priority = priority;
  } else {
    // Add new network
    if (savedNetworkCount >= wifiManager::MAX_SAVED_NETWORKS) {
      foundIdx = savedNetworkCount - 1;
    } else {
      foundIdx = savedNetworkCount;
      savedNetworkCount++;
    }

    strncpy(savedNetworks[foundIdx].ssid, ssid.c_str(), sizeof(savedNetworks[foundIdx].ssid) - 1);
    savedNetworks[foundIdx].ssid[sizeof(savedNetworks[foundIdx].ssid) - 1] = '\0';
    strncpy(savedNetworks[foundIdx].password, password.c_str(), sizeof(savedNetworks[foundIdx].password) - 1);
    savedNetworks[foundIdx].password[sizeof(savedNetworks[foundIdx].password) - 1] = '\0';
    savedNetworks[foundIdx].priority = priority;
  }

  saveNetworksToNVS();

  // Immediately attempt to connect to this new network
  currentNetworkIndex = foundIdx;
  Serial.print("WiFi: Connecting to newly provisioned network '");
  Serial.print(savedNetworks[currentNetworkIndex].ssid);
  Serial.println("'...");

  WiFi.disconnect(false);
  WiFi.begin(savedNetworks[currentNetworkIndex].ssid, savedNetworks[currentNetworkIndex].password);
  wifiStatus = wifiManager::WIFI_CONNECTING;
  lastConnectionAttempt = millis();
  ntpStarted = false;
  printWiFiStatus(wifiStatus);
  return true;
}

bool wifiManager::removeNetwork(const String &ssid) {
  int foundIdx = -1;
  for (int i = 0; i < savedNetworkCount; i++) {
    if (ssid.equalsIgnoreCase(String(savedNetworks[i].ssid))) {
      foundIdx = i;
      break;
    }
  }

  if (foundIdx < 0) return false;

  for (int i = foundIdx; i < savedNetworkCount - 1; i++) {
    savedNetworks[i] = savedNetworks[i + 1];
  }
  savedNetworkCount--;

  if (savedNetworkCount == 0) {
    strncpy(savedNetworks[0].ssid, "ESPTEST", sizeof(savedNetworks[0].ssid) - 1);
    savedNetworks[0].ssid[sizeof(savedNetworks[0].ssid) - 1] = '\0';
    strncpy(savedNetworks[0].password, "12345678", sizeof(savedNetworks[0].password) - 1);
    savedNetworks[0].password[sizeof(savedNetworks[0].password) - 1] = '\0';
    savedNetworks[0].priority = 1;
    savedNetworkCount = 1;
  }

  if (currentNetworkIndex >= savedNetworkCount) {
    currentNetworkIndex = 0;
  }

  saveNetworksToNVS();
  return true;
}

void wifiManager::clearAllNetworks() {
  savedNetworkCount = 0;
  strncpy(savedNetworks[0].ssid, "ESPTEST", sizeof(savedNetworks[0].ssid) - 1);
  savedNetworks[0].ssid[sizeof(savedNetworks[0].ssid) - 1] = '\0';
  strncpy(savedNetworks[0].password, "12345678", sizeof(savedNetworks[0].password) - 1);
  savedNetworks[0].password[sizeof(savedNetworks[0].password) - 1] = '\0';
  savedNetworks[0].priority = 1;
  savedNetworkCount = 1;
  currentNetworkIndex = 0;

  saveNetworksToNVS();
}

int wifiManager::getSavedNetworkCount() {
  return savedNetworkCount;
}

bool wifiManager::getSavedNetworkInfo(int index, String &ssid, int &priority) {
  if (index < 0 || index >= savedNetworkCount) return false;
  ssid = String(savedNetworks[index].ssid);
  priority = savedNetworks[index].priority;
  return true;
}

void wifiManager::reconnectBest() {
  if (savedNetworkCount == 0) return;
  Serial.print("WiFi: Forcing reconnection to '");
  Serial.print(savedNetworks[currentNetworkIndex].ssid);
  Serial.println("'...");

  WiFi.disconnect(false);
  WiFi.begin(savedNetworks[currentNetworkIndex].ssid, savedNetworks[currentNetworkIndex].password);
  wifiStatus = wifiManager::WIFI_CONNECTING;
  lastConnectionAttempt = millis();
  ntpStarted = false;
  printWiFiStatus(wifiStatus);
}

// ============================================================
// CLOUD SYNC — Supabase REST API over WiFi
// ============================================================
// Offline queue stored in NVS (up to 50 readings)

#include <HTTPClient.h>
#include <WiFiClientSecure.h>

namespace {

  static const char* SUPABASE_URL  =
      "https://ssupmhqrfspmezcvmgbv.supabase.co"
      "/rest/v1/health_readings";
  static const char* SUPABASE_KEY  =
      "sb_publishable_xtCDXtgVEAlwtAgjnKnPcA_Ke0WhUyG";

  // Offline queue NVS
  static const char* Q_NS    = "hd_queue";
  static const int   Q_MAX   = 50;

  struct QueueEntry {
    char   type[8];     // "hr" | "spo2" | "steps"
    int    value;
    uint32_t epochTime;
  };

  static bool postReading(const char* type, int value, uint32_t epochTime) {
    if (!wifiManager::isConnected()) return false;

    // Get WiFi MAC as device ID (stable, unique per device)
    String deviceId = WiFi.macAddress();

    // Build ISO-8601 timestamp
    char ts[32];
    time_t t = (time_t)epochTime;
    struct tm* tm_info = gmtime(&t);
    strftime(ts, sizeof(ts), "%Y-%m-%dT%H:%M:%SZ", tm_info);

    String body = "{\"device_id\":\"";
    body += deviceId;
    body += "\",\"type\":\"";
    body += type;
    body += "\",\"value\":";
    body += value;
    body += ",\"recorded_at\":\"";
    body += ts;
    body += "\",\"synced_from\":\"wifi\"}";

    WiFiClientSecure client;
    client.setInsecure(); // Accept any cert (ESP32 has no cert store by default)

    HTTPClient http;
    http.begin(client, SUPABASE_URL);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("apikey", SUPABASE_KEY);
    http.addHeader("Authorization", String("Bearer ") + SUPABASE_KEY);
    http.addHeader("Prefer", "return=minimal");

    int code = http.POST(body);
    http.end();

    Serial.print("[Cloud] POST ");
    Serial.print(type);
    Serial.print("=");
    Serial.print(value);
    Serial.print(" -> HTTP ");
    Serial.println(code);

    return (code >= 200 && code < 300);
  }

  static void saveToQueue(const char* type, int value, uint32_t epochTime) {
    Preferences qPrefs;
    qPrefs.begin(Q_NS, false);
    int count = qPrefs.getInt("count", 0);
    if (count >= Q_MAX) {
      // Drop oldest: shift everything down
      for (int i = 0; i < count - 1; i++) {
        char srcKey[12], dstKey[12];
        snprintf(srcKey, sizeof(srcKey), "q%d", i + 1);
        snprintf(dstKey, sizeof(dstKey), "q%d", i);
        QueueEntry e{};
        if (qPrefs.getBytes(srcKey, &e, sizeof(e)) == sizeof(e))
          qPrefs.putBytes(dstKey, &e, sizeof(e));
      }
      count = Q_MAX - 1;
    }
    QueueEntry entry{};
    strncpy(entry.type, type, sizeof(entry.type) - 1);
    entry.value = value;
    entry.epochTime = epochTime;
    char key[12];
    snprintf(key, sizeof(key), "q%d", count);
    qPrefs.putBytes(key, &entry, sizeof(entry));
    qPrefs.putInt("count", count + 1);
    qPrefs.end();
    Serial.print("[Cloud] Queued offline: ");
    Serial.print(type);
    Serial.print("=");
    Serial.println(value);
  }

  static TaskHandle_t cloudSyncTaskHandle = NULL;

  static void cloudSyncTask(void* param) {
    if (wifiManager::isConnected()) {
      Preferences qPrefs;
      qPrefs.begin(Q_NS, false);
      int count = qPrefs.getInt("count", 0);
      if (count > 0) {
        Serial.print("[Cloud] Background task flushing ");
        Serial.print(count);
        Serial.println(" queued readings...");

        int sent = 0;
        for (int i = 0; i < count; i++) {
          char key[12];
          snprintf(key, sizeof(key), "q%d", i);
          QueueEntry e{};
          if (qPrefs.getBytes(key, &e, sizeof(e)) == sizeof(e)) {
            if (postReading(e.type, e.value, e.epochTime)) sent++;
            else break; // WiFi issue, keep remaining in queue
          }
        }

        if (sent > 0) {
          int remaining = count - sent;
          for (int i = 0; i < remaining; i++) {
            char srcKey[12], dstKey[12];
            snprintf(srcKey, sizeof(srcKey), "q%d", i + sent);
            snprintf(dstKey, sizeof(dstKey), "q%d", i);
            QueueEntry e{};
            if (qPrefs.getBytes(srcKey, &e, sizeof(e)) == sizeof(e))
              qPrefs.putBytes(dstKey, &e, sizeof(e));
          }
          qPrefs.putInt("count", remaining);
          Serial.print("[Cloud] Background task flushed ");
          Serial.print(sent);
          Serial.println(" readings.");
        }
      }
      qPrefs.end();
    }
    cloudSyncTaskHandle = NULL;
    vTaskDelete(NULL);
  }

  static void triggerCloudSync() {
    if (cloudSyncTaskHandle != NULL) return; // Already running
    xTaskCreate(
      cloudSyncTask,
      "cloudSync",
      8192,
      NULL,
      1,
      &cloudSyncTaskHandle
    );
  }

} // namespace

void wifiManager::pushReading(const char* type, int value, uint32_t epochTime) {
  // Always queue to NVS (fast <5ms, non-blocking, loop() keeps running smoothly)
  saveToQueue(type, value, epochTime);
  // Asynchronously upload in FreeRTOS background task so buzzer and LED never freeze!
  if (isConnected()) {
    triggerCloudSync();
  }
}

void wifiManager::flushOfflineQueue() {
  if (!isConnected()) return;
  triggerCloudSync();
}
