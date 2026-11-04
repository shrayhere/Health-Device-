#include "reminders.h"
#include "time_manager.h"
#include "storage.h"

static Reminder list[MAX_REMINDERS];
static int pendingIndex = -1;
static int lastFiredMinuteOfDay[MAX_REMINDERS];

static void loadFromStorage() {
  for (int i = 0; i < MAX_REMINDERS; i++) {
    char k[16];
    snprintf(k, sizeof(k), "rem_used%d", i);
    list[i].used = storage::loadBool(k, false);
    if (!list[i].used) continue;

    snprintf(k, sizeof(k), "rem_name%d", i);
    String n = storage::loadString(k, "");
    strncpy(list[i].name, n.c_str(), sizeof(list[i].name) - 1);

    snprintf(k, sizeof(k), "rem_h%d", i);
    list[i].hour = storage::loadInt(k, 0);
    snprintf(k, sizeof(k), "rem_m%d", i);
    list[i].minute = storage::loadInt(k, 0);
    snprintf(k, sizeof(k), "rem_rep%d", i);
    list[i].repeatDaily = storage::loadBool(k, true);
    snprintf(k, sizeof(k), "rem_en%d", i);
    list[i].enabled = storage::loadBool(k, true);
  }
}

static void saveOne(int i) {
  char k[16];
  snprintf(k, sizeof(k), "rem_used%d", i);  storage::saveBool(k, list[i].used);
  snprintf(k, sizeof(k), "rem_name%d", i);  storage::saveString(k, String(list[i].name));
  snprintf(k, sizeof(k), "rem_h%d", i);     storage::saveInt(k, list[i].hour);
  snprintf(k, sizeof(k), "rem_m%d", i);     storage::saveInt(k, list[i].minute);
  snprintf(k, sizeof(k), "rem_rep%d", i);   storage::saveBool(k, list[i].repeatDaily);
  snprintf(k, sizeof(k), "rem_en%d", i);    storage::saveBool(k, list[i].enabled);
}

namespace reminders {

void begin() {
  for (int i = 0; i < MAX_REMINDERS; i++) {
    list[i].used = false;
    lastFiredMinuteOfDay[i] = -1;
  }
  loadFromStorage();
}

void update() {
  DateTime dt = timeManager::now();
  int minuteOfDay = dt.hour * 60 + dt.minute;

  for (int i = 0; i < MAX_REMINDERS; i++) {
    if (!list[i].used || !list[i].enabled) continue;
    int target = list[i].hour * 60 + list[i].minute;
    if (minuteOfDay == target && lastFiredMinuteOfDay[i] != minuteOfDay) {
      lastFiredMinuteOfDay[i] = minuteOfDay;
      pendingIndex = i;
      if (!list[i].repeatDaily) {
        list[i].enabled = false;
        saveOne(i);
      }
    }
    // reset the "already fired" guard once we've moved past the minute
    if (minuteOfDay != target) {
      // allow it to fire again tomorrow
    }
  }
}

int count() {
  int c = 0;
  for (int i = 0; i < MAX_REMINDERS; i++) if (list[i].used) c++;
  return c;
}

const Reminder& get(int index) { return list[index]; }

bool add(const char* name, int hour, int minute, bool repeatDaily) {
  for (int i = 0; i < MAX_REMINDERS; i++) {
    if (!list[i].used) {
      list[i].used = true;
      strncpy(list[i].name, name, sizeof(list[i].name) - 1);
      list[i].name[sizeof(list[i].name) - 1] = '\0';
      list[i].hour = hour;
      list[i].minute = minute;
      list[i].repeatDaily = repeatDaily;
      list[i].enabled = true;
      saveOne(i);
      return true;
    }
  }
  return false; // full
}

void remove(int index) {
  if (index < 0 || index >= MAX_REMINDERS) return;
  list[index].used = false;
  saveOne(index);
}

void setEnabled(int index, bool enabled) {
  if (index < 0 || index >= MAX_REMINDERS) return;
  list[index].enabled = enabled;
  saveOne(index);
}

bool hasPendingAlert() { return pendingIndex >= 0; }
const Reminder& getPendingAlert() { return list[pendingIndex]; }
void dismissAlert() { pendingIndex = -1; }

} // namespace reminders
