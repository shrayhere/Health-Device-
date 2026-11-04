# HealthDevice: Smart Wearable Health Capsule & AI Posture Ecosystem

An open-architecture wearable health capsule built around the **ESP32-C3 (32-bit RISC-V)**, featuring real-time optical PPG biosensing, 6-axis IMU tilt and step tracking, a 32-screen OLED UI engine, and a cross-platform companion software suite for Android, Windows, and AI desktop webcam posture coaching.

---

## 🌟 Ecosystem Architecture

```
HealthDevice/
├── Health device2.0/            # Embedded C++ Firmware for ESP32-C3 Super Mini
│   └── HealthDevice/            # Arduino/C++ source (.ino, sensors, BLE, alarms, display)
├── healthdeviceapp/             # Flutter Companion Software (Android & Windows 64-bit)
│   ├── lib/                     # Real-time vitals dashboard, BLE UART sync, AI health chat
│   ├── ai_posture_tracker/      # MediaPipe Python Computer Vision webcam ergonomic tracker
│   └── test/                    # 30 Unit, widget, and integration test suites
└── HealthDevice_Software_and_AI_Manual.pdf  # Technical reference manual
```

---

## 🚀 Key Features

### 1. Embedded Wearable Hardware Capsule (ESP32-C3)
- **Optical PPG Biosensing (MAX30102):** Clinical-grade real-time Heart Rate (BPM) and blood oxygen saturation ($\text{SpO}_2$) with intelligent finger detection.
- **6-Axis Motion & Tilt (MPU-6500):** Hardware pedometer, active time calculation, calorie expenditure, and real-time gravity vector posture monitoring.
- **Expansive 32-Screen OLED UI:** Non-blocking menu navigation, live graphs, customizable multi-slot alarms with 24-bit RGB LED illumination.
- **Single-Button Multi-Action FSM:** Click, double-click, long press, and 3-second microamp sleep hold.
- **Connectivity:** BLE 5.0 GATT custom UART service and 2.4 GHz Wi-Fi NTP time synchronization.

### 2. Cross-Platform Flutter Companion App
- **Real-Time Telemetry:** Live vitals streaming over BLE, historical health metrics graphs, and Supabase cloud sync.
- **24-bit RGB Color Wheel:** Custom per-alarm LED illumination configuration with one-tap hardware synchronization.
- **Dual AM/PM Support:** 12-hour and 24-hour time selector for seamless alarm and hydration reminder scheduling.
- **Integrated AI Health Assistant:** Natural language health chat powered by Llama / Groq LLMs.

### 3. Desktop AI Webcam Posture Tracker
- **Computer Vision Ergonomic Coach:** MediaPipe 33-point skeletal landmark detection running at 30+ FPS.
- **Ergonomic Angles:** Real-time neck flexion and shoulder tilt angle calculations with voice-prompt guidance.

---

## 🛠️ Build & Installation

### Firmware (ESP32-C3)
1. Open `Health device2.0/HealthDevice/HealthDevice.ino` in Arduino IDE.
2. Select board: **ESP32C3 Dev Module**.
3. Install required libraries: `Adafruit SSD1306`, `Adafruit GFX`, `SparkFun MAX3010x`.
4. Flash over USB-C.

### Companion App (Flutter)
```bash
cd healthdeviceapp
flutter pub get
flutter test
flutter run -d windows    # For Windows Desktop
flutter run -d <device>   # For Android Phone
```

---

## 📄 License & Attribution
Developed by **Shaurya Gupta**. Distributed under the MIT License.

