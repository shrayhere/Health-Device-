#ifndef WIFI_MANAGER_H
#define WIFI_MANAGER_H

#include <Arduino.h>

namespace wifiManager {

  // --------------------------------------------------
  // Wi-Fi status
  // --------------------------------------------------

  enum Status {
    WIFI_DISABLED,
    WIFI_CONNECTING,
    WIFI_CONNECTED,
    WIFI_DISCONNECTED
  };

  // --------------------------------------------------
  // Setup / background update
  // --------------------------------------------------

  void begin();
  void update();

  // --------------------------------------------------
  // Wi-Fi control
  // --------------------------------------------------

  void setEnabled(bool enabled);
  bool isEnabled();

  bool isConnected();
  bool isConnecting();
  bool isDisconnected();

  Status getStatus();

  // --------------------------------------------------
  // NTP / network time
  // --------------------------------------------------

  bool isTimeSynced();

  bool getNetworkTime(
    int &year,
    int &month,
    int &day,
    int &hour,
    int &minute,
    int &second,
    int &weekday
  );

  // --------------------------------------------------
  // Wi-Fi information
  // --------------------------------------------------

  String getSSID();
  int getRSSI();

  // --------------------------------------------------
  // Multiple saved networks API
  // --------------------------------------------------

  static const int MAX_SAVED_NETWORKS = 8;

  bool addOrUpdateNetwork(const String &ssid, const String &password, int priority = 1);
  bool removeNetwork(const String &ssid);
  void clearAllNetworks();
  int getSavedNetworkCount();
  bool getSavedNetworkInfo(int index, String &ssid, int &priority);
  void reconnectBest();

  // --------------------------------------------------
  // Cloud sync (Supabase REST over WiFi)
  // --------------------------------------------------
  void pushReading(const char* type, int value, uint32_t epochTime);
  void flushOfflineQueue();

} // namespace wifiManager

#endif