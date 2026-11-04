import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/health_metrics.dart';

/// Exact BLE contract configuration for ESP32-C3 HealthDevice test firmware.
class BleContract {
  BleContract._();

  static const String deviceName = 'HealthDevice';
  static const String serviceUuid = '12345678-1234-1234-1234-123456789000';
  static const String statusCharacteristicUuid =
      '12345678-1234-1234-1234-123456789003';
  static const String commandCharacteristicUuid =
      '12345678-1234-1234-1234-123456789004';
  static const String dataCharacteristicUuid =
      '12345678-1234-1234-1234-123456789005';
}

/// Real BLE connection states reflecting actual hardware status.
enum BleDeviceState {
  disconnected,
  scanning,
  connecting,
  discoveringServices,
  connected,
  bluetoothDisabled,
  unsupported,
  connectionFailed,
}

/// Capability flags identifying which BLE characteristics actually exist on connected hardware.
enum BleCapability {
  firmwareStatus,
  batteryLevel,
  telemetryStream,
  wifiProvisioning,
  alarmSync,
  reminderSync,
  ledConfig,
  soundConfig,
  displayConfig,
}

/// Discovered BLE device model with stable identity based on remoteId.
class DiscoveredBleDevice {
  final BluetoothDevice device;
  final String name;
  final int rssi;
  final String remoteId;
  final DateTime lastSeen;

  const DiscoveredBleDevice({
    required this.device,
    required this.name,
    required this.rssi,
    required this.remoteId,
    required this.lastSeen,
  });

  bool get isHealthDevice =>
      name == BleContract.deviceName ||
      name.toLowerCase().contains('healthdevice') ||
      name.toLowerCase().contains('esp32') ||
      device.platformName == BleContract.deviceName ||
      device.platformName.toLowerCase().contains('healthdevice') ||
      device.platformName.toLowerCase().contains('esp32');
}

/// Central real BLE Device Manager for the HealthDevice ESP32-C3.
///
/// Owns:
/// - Bluetooth adapter state
/// - Scanning state
/// - Discovered devices (filtered to only HealthDevice / ESP32, persistent across reconnects)
/// - Connected device
/// - Connection state
/// - Discovered GATT services
/// - Discovered GATT characteristics (status 9003, command 9004, data 9005)
/// - Status and data notification subscriptions
/// - Automatic direct connection upon discovery
class BleDeviceManager {
  static final BleDeviceManager _instance = BleDeviceManager._internal();
  factory BleDeviceManager() => _instance;
  BleDeviceManager._internal();

  // Reactive state notifiers
  final ValueNotifier<BluetoothAdapterState> adapterState =
      ValueNotifier<BluetoothAdapterState>(BluetoothAdapterState.unknown);

  final ValueNotifier<bool> isScanning = ValueNotifier<bool>(false);

  final ValueNotifier<BleDeviceState> connectionState =
      ValueNotifier<BleDeviceState>(BleDeviceState.disconnected);

  final ValueNotifier<BluetoothDevice?> connectedDevice =
      ValueNotifier<BluetoothDevice?>(null);

  final ValueNotifier<List<DiscoveredBleDevice>> discoveredDevices =
      ValueNotifier<List<DiscoveredBleDevice>>([]);

  final ValueNotifier<List<BluetoothService>> deviceServices =
      ValueNotifier<List<BluetoothService>>([]);

  final ValueNotifier<List<BluetoothCharacteristic>> deviceCharacteristics =
      ValueNotifier<List<BluetoothCharacteristic>>([]);

  final ValueNotifier<String?> firmwareStatus = ValueNotifier<String?>(null);

  final ValueNotifier<Set<BleCapability>> supportedCapabilities =
      ValueNotifier<Set<BleCapability>>({});

  final ValueNotifier<int?> liveRssi = ValueNotifier<int?>(null);

  final ValueNotifier<BatteryData> batteryData = ValueNotifier<BatteryData>(
    BatteryData.unavailable(),
  );

  final ValueNotifier<DeviceInfo> deviceInfo = ValueNotifier<DeviceInfo>(
    DeviceInfo(
      name: 'HealthDevice',
      model: 'ESP32-C3',
      hardwareRevision: 'Unavailable',
      firmwareVersion: 'Awaiting BLE Sync',
      macAddress: 'Unavailable',
      isCalibrated: false,
      pairedAt: null,
    ),
  );

  /// Live state parsed from ESP32 data stream (data characteristic 9005).
  final ValueNotifier<Map<String, dynamic>?> liveHardwareState =
      ValueNotifier<Map<String, dynamic>?>(null);

  // Internal state tracking
  final Map<String, DiscoveredBleDevice> _scannedMap = {};
  BluetoothCharacteristic? _statusCharacteristic;
  BluetoothCharacteristic? _commandCharacteristic;
  BluetoothCharacteristic? _dataCharacteristic;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;
  StreamSubscription<List<int>>? _charNotifySub;
  StreamSubscription<List<int>>? _dataNotifySub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;

  final StringBuffer _chunkBuffer = StringBuffer();
  int _lastChunkIndex = -1;
  bool _isConnecting = false;

  BluetoothCharacteristic? get statusCharacteristic => _statusCharacteristic;
  BluetoothCharacteristic? get commandCharacteristic => _commandCharacteristic;
  BluetoothCharacteristic? get dataCharacteristic => _dataCharacteristic;
  bool get isConnected => connectionState.value == BleDeviceState.connected;

  /// Initializes adapter listener and auto-scan capability.
  Future<void> init() async {
    try {
      _adapterSub?.cancel();
      _adapterSub = FlutterBluePlus.adapterState.listen((state) {
        adapterState.value = state;
        if (state == BluetoothAdapterState.on) {
          if (connectionState.value == BleDeviceState.bluetoothDisabled ||
              connectionState.value == BleDeviceState.unsupported) {
            connectionState.value = connectedDevice.value != null
                ? BleDeviceState.connected
                : BleDeviceState.disconnected;
          }
          // Automatically start scanning if disconnected and not currently connecting
          if (!isConnected &&
              !_isConnecting &&
              connectionState.value != BleDeviceState.connecting &&
              connectionState.value != BleDeviceState.discoveringServices &&
              !isScanning.value) {
            startScan();
          }
        } else if (state == BluetoothAdapterState.off) {
          connectionState.value = BleDeviceState.bluetoothDisabled;
        } else if (state == BluetoothAdapterState.unavailable) {
          connectionState.value = BleDeviceState.unsupported;
        }
      });

      final current = await FlutterBluePlus.adapterState.first;
      adapterState.value = current;
      if (current == BluetoothAdapterState.on && !isConnected) {
        startScan();
      }
    } catch (e) {
      debugPrint('[BleDeviceManager] Adapter init error: $e');
    }
  }

  /// Scans for nearby BLE devices.
  ///
  /// CRITICAL: Filters out unrelated Bluetooth devices (headphones, TVs, random beacons).
  /// ONLY registers HealthDevice / ESP32-C3 and directly initiates connection when discovered!
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
    bool clearPrevious = false,
  }) async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        connectionState.value = BleDeviceState.unsupported;
        return;
      }

      var adapter = await FlutterBluePlus.adapterState.first;
      adapterState.value = adapter;
      if (adapter != BluetoothAdapterState.on) {
        if (!kIsWeb && Platform.isAndroid) {
          try {
            await FlutterBluePlus.turnOn();
          } catch (_) {}
        }
        try {
          adapter = await FlutterBluePlus.adapterState
              .where((s) => s == BluetoothAdapterState.on)
              .first
              .timeout(const Duration(seconds: 4));
          adapterState.value = adapter;
        } catch (_) {
          connectionState.value = BleDeviceState.bluetoothDisabled;
          return;
        }
      }

      if (clearPrevious) {
        _scannedMap.clear();
        discoveredDevices.value = [];
      }

      isScanning.value = true;
      if (connectionState.value != BleDeviceState.connected) {
        connectionState.value = BleDeviceState.scanning;
      }

      _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final remoteId = r.device.remoteId.str;
          final advName = r.advertisementData.advName;
          final platformName = r.device.platformName;

          final cleanAdv = advName.trim().replaceAll('\x00', '');
          final cleanPlatform = platformName.trim().replaceAll('\x00', '');
          final normAdv =
              cleanAdv.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
          final normPlatform =
              cleanPlatform.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');

          final targetUuidNorm =
              BleContract.serviceUuid.toLowerCase().replaceAll('-', '');
          final hasMatchingUuid = r.advertisementData.serviceUuids.any((u) {
            final uStr = u.str128.toLowerCase().replaceAll('-', '');
            return uStr == targetUuidNorm;
          });

          // Match HealthDevice or ESP32 by name or service UUID
          final isTarget = normAdv.contains('healthdevice') ||
              normAdv.contains('esp32') ||
              normPlatform.contains('healthdevice') ||
              normPlatform.contains('esp32') ||
              hasMatchingUuid;

          if (!isTarget) {
            continue; // Filter out unrelated devices
          }

          final displayName = cleanAdv.isNotEmpty
              ? cleanAdv
              : (cleanPlatform.isNotEmpty ? cleanPlatform : 'HealthDevice');

          final discovered = DiscoveredBleDevice(
            device: r.device,
            name: displayName,
            rssi: r.rssi,
            remoteId: remoteId,
            lastSeen: DateTime.now(),
          );
          _scannedMap[remoteId] = discovered;

          // Directly auto-connect to main HealthDevice when detected
          if (!isConnected &&
              !_isConnecting &&
              connectionState.value != BleDeviceState.connecting &&
              connectionState.value != BleDeviceState.discoveringServices) {
            _isConnecting = true;
            debugPrint(
              '[BleDeviceManager] Target HealthDevice discovered ($displayName, $remoteId). Stopping scan and connecting...',
            );
            stopScan().then((_) {
              connectToDevice(r.device);
            });
          }
        }

        final sorted = _scannedMap.values.toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));

        discoveredDevices.value = sorted;
      });

      await FlutterBluePlus.startScan(
        timeout: timeout,
        androidCheckLocationServices: false,
        androidUsesFineLocation: false,
      );
      isScanning.value = false;
      if (connectionState.value == BleDeviceState.scanning) {
        connectionState.value = connectedDevice.value != null
            ? BleDeviceState.connected
            : BleDeviceState.disconnected;
      }
    } catch (e) {
      debugPrint('[BleDeviceManager] Scan error: $e');
    }
  }

  /// Stops an active BLE scan without clearing discovered devices.
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('[BleDeviceManager] Stop scan error: $e');
    } finally {
      _scanSub?.cancel();
      _scanSub = null;
      isScanning.value = false;
      if (connectionState.value == BleDeviceState.scanning) {
        connectionState.value = connectedDevice.value != null
            ? BleDeviceState.connected
            : BleDeviceState.disconnected;
      }
    }
  }

  /// Explicitly clears discovered devices list if requested by user.
  void clearScannedDevices() {
    _scannedMap.clear();
    discoveredDevices.value = [];
  }

  /// Connects to selected BluetoothDevice and establishes real GATT contract with ESP32-C3.
  ///
  /// CRITICAL: Connecting to HealthDevice preserves [discoveredDevices].
  Future<bool> connectToDevice(BluetoothDevice device) async {
    _isConnecting = true;
    try {
      // 1. Stop active BLE scan
      await stopScan();

      // 2. Set connecting state
      connectionState.value = BleDeviceState.connecting;
      connectedDevice.value = device;

      // 3. Listen to connection state
      _connStateSub?.cancel();
      _connStateSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });

      // 4. Connect to device
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 20),
        autoConnect: false,
      );

      // Brief settling delay on Android before discovering services
      if (!kIsWeb && Platform.isAndroid) {
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // 5. Discover services
      connectionState.value = BleDeviceState.discoveringServices;
      final services = await device.discoverServices();
      deviceServices.value = services;

      final allChars = <BluetoothCharacteristic>[];
      for (final s in services) {
        allChars.addAll(s.characteristics);
      }
      deviceCharacteristics.value = allChars;

      // 6. Locate HealthDevice service
      BluetoothService? targetService;
      for (final s in services) {
        if (s.uuid.str128.toLowerCase() ==
            BleContract.serviceUuid.toLowerCase()) {
          targetService = s;
          break;
        }
      }

      if (targetService == null) {
        debugPrint(
          '[BleDeviceManager] Configured service ${BleContract.serviceUuid} not found',
        );
        firmwareStatus.value = 'Configured GATT service not found';
        connectionState.value = BleDeviceState.connected;
        _updateCapabilitiesAndDeviceInfo(device, null);
        return true;
      }

      // 7. Locate status, command, and data characteristics
      BluetoothCharacteristic? statusChar;
      BluetoothCharacteristic? commandChar;
      BluetoothCharacteristic? dataChar;

      for (final c in targetService.characteristics) {
        final uuidStr = c.uuid.str128.toLowerCase();
        if (uuidStr == BleContract.statusCharacteristicUuid.toLowerCase()) {
          statusChar = c;
        } else if (uuidStr ==
            BleContract.commandCharacteristicUuid.toLowerCase()) {
          commandChar = c;
        } else if (uuidStr ==
            BleContract.dataCharacteristicUuid.toLowerCase()) {
          dataChar = c;
        }
      }

      _statusCharacteristic = statusChar;
      _commandCharacteristic = commandChar;
      _dataCharacteristic = dataChar;

      // 8. Initial READ & subscribe on status characteristic
      if (statusChar != null) {
        if (statusChar.properties.read) {
          try {
            final raw = await statusChar.read();
            final text = utf8.decode(raw, allowMalformed: true);
            firmwareStatus.value = text;
            debugPrint('[BleDeviceManager] Read initial status: $text');
          } catch (e) {
            debugPrint('[BleDeviceManager] Initial read error: $e');
          }
        }

        if (statusChar.properties.notify) {
          try {
            await statusChar.setNotifyValue(true);
            _charNotifySub?.cancel();
            _charNotifySub = statusChar.onValueReceived.listen((data) {
              final msg = utf8.decode(data, allowMalformed: true);
              firmwareStatus.value = msg;
              debugPrint('[BleDeviceManager] Notify message: $msg');
            });
          } catch (e) {
            debugPrint('[BleDeviceManager] Status subscribe error: $e');
          }
        }
      }

      // Small delay between descriptor writes for Android GATT queue
      if (!kIsWeb && Platform.isAndroid) {
        await Future.delayed(const Duration(milliseconds: 150));
      }

      // 9. Subscribe to DATA characteristic notifications (stream vitals, state, battery)
      if (dataChar != null && dataChar.properties.notify) {
        try {
          await dataChar.setNotifyValue(true);
          _dataNotifySub?.cancel();
          _dataNotifySub = dataChar.onValueReceived.listen((data) {
            _handleIncomingDataPayload(data);
          });
          debugPrint('[BleDeviceManager] Subscribed to data characteristic 9005 notifications');
        } catch (e) {
          debugPrint('[BleDeviceManager] Error subscribing to data characteristic: $e');
        }
      }

      // 10. Update capabilities and truthful device info
      _updateCapabilitiesAndDeviceInfo(device, statusChar);
      connectionState.value = BleDeviceState.connected;

      // 11. Initial hardware time synchronization and state request
      _performInitialSync();

      return true;
    } catch (e) {
      debugPrint('[BleDeviceManager] Connect failed: $e');
      connectionState.value = BleDeviceState.connectionFailed;
      _handleDisconnection();
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> _performInitialSync() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      // Set date & time on device without requiring Wi-Fi
      final now = DateTime.now();
      final timeCmd =
          'SYNC_TIME:${now.year},${now.month},${now.day},${now.hour},${now.minute},${now.second}';
      await _writeCommandDirect(timeCmd);

      await Future.delayed(const Duration(milliseconds: 150));
      // Request complete state dump from ESP32
      await _writeCommandDirect('GET_STATE');
    } catch (e) {
      debugPrint('[BleDeviceManager] Initial sync error: $e');
    }
  }

  Future<bool> _writeCommandDirect(String cmd) async {
    if (_commandCharacteristic == null) return false;
    try {
      final bytes = utf8.encode(cmd);
      final withoutResp = _commandCharacteristic!.properties.writeWithoutResponse;
      await _commandCharacteristic!.write(bytes, withoutResponse: withoutResp);
      debugPrint('[BleDeviceManager] Wrote initial command: $cmd');
      return true;
    } catch (e) {
      debugPrint('[BleDeviceManager] Direct write failed: $e');
      return false;
    }
  }

  void _handleIncomingDataPayload(List<int> bytes) {
    try {
      final text = utf8.decode(bytes, allowMalformed: true).trim();
      if (text.isEmpty) return;

      if (text.startsWith('@S')) {
        // Chunk format: @S<idx>/<total>:<content>
        final colonIdx = text.indexOf(':');
        if (colonIdx > 2) {
          final header = text.substring(2, colonIdx);
          final parts = header.split('/');
          if (parts.length == 2) {
            final idx = int.tryParse(parts[0]) ?? 0;
            final total = int.tryParse(parts[1]) ?? 1;
            final chunkContent = text.substring(colonIdx + 1);

            if (idx == 0) {
              _chunkBuffer.clear();
              _lastChunkIndex = -1;
            }

            if (idx == _lastChunkIndex + 1) {
              _chunkBuffer.write(chunkContent);
              _lastChunkIndex = idx;
            }

            if (idx == total - 1) {
              final fullJson = _chunkBuffer.toString();
              _chunkBuffer.clear();
              _parseAndApplyDeviceStateJson(fullJson);
            }
            return;
          }
        }
      }

      // Direct JSON payload
      if (text.startsWith('{') && text.endsWith('}')) {
        _parseAndApplyDeviceStateJson(text);
      }
    } catch (e) {
      debugPrint('[BleDeviceManager] Error handling data payload: $e');
    }
  }

  void _parseAndApplyDeviceStateJson(String jsonStr) {
    try {
      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) return;

      liveHardwareState.value = decoded;

      // Update battery if present
      if (decoded.containsKey('battery')) {
        final bat = decoded['battery'];
        if (bat is num && bat > 0) {
          batteryData.value = BatteryData(
            percentage: bat.toInt(),
            isCharging: false,
            isAvailable: true,
            estimatedRemaining: '~${((bat / 100) * 18).toStringAsFixed(1)} hrs',
          );
        }
      }
    } catch (e) {
      debugPrint('[BleDeviceManager] JSON parse error: $e');
    }
  }

  /// Disconnects from current connected device.
  Future<void> disconnect() async {
    try {
      _charNotifySub?.cancel();
      _charNotifySub = null;
      _dataNotifySub?.cancel();
      _dataNotifySub = null;
      if (connectedDevice.value != null) {
        await connectedDevice.value!.disconnect();
      }
    } catch (e) {
      debugPrint('[BleDeviceManager] Disconnect error: $e');
    } finally {
      _handleDisconnection();
    }
  }

  void _handleDisconnection() {
    _statusCharacteristic = null;
    _commandCharacteristic = null;
    _dataCharacteristic = null;
    _charNotifySub?.cancel();
    _charNotifySub = null;
    _dataNotifySub?.cancel();
    _dataNotifySub = null;
    _connStateSub?.cancel();
    _connStateSub = null;
    connectedDevice.value = null;
    deviceServices.value = [];
    deviceCharacteristics.value = [];
    firmwareStatus.value = null;
    liveRssi.value = null;
    connectionState.value = BleDeviceState.disconnected;
    supportedCapabilities.value = {};
    batteryData.value = BatteryData.unavailable();
    liveHardwareState.value = null;
    deviceInfo.value = DeviceInfo(
      name: 'HealthDevice',
      model: 'ESP32-C3',
      hardwareRevision: 'Unavailable',
      firmwareVersion: 'Awaiting BLE Sync',
      macAddress: 'Unavailable',
      isCalibrated: false,
      pairedAt: null,
    );
    // CRITICAL: Discovered devices are kept completely independent!
  }

  void _updateCapabilitiesAndDeviceInfo(
    BluetoothDevice device,
    BluetoothCharacteristic? statusChar,
  ) {
    final caps = <BleCapability>{};
    if (statusChar != null) {
      caps.add(BleCapability.firmwareStatus);
    }

    // Check if standard Battery Service (0x180F) is present
    for (final s in deviceServices.value) {
      if (s.uuid.str128.toLowerCase().contains('180f')) {
        caps.add(BleCapability.batteryLevel);
      }
    }

    supportedCapabilities.value = caps;

    final devName = device.platformName.isNotEmpty
        ? device.platformName
        : BleContract.deviceName;

    deviceInfo.value = DeviceInfo(
      name: devName,
      model: 'ESP32-C3',
      hardwareRevision: 'Unavailable (Firmware v1.0.0)',
      firmwareVersion: firmwareStatus.value ?? 'HealthDevice Connected',
      macAddress: device.remoteId.str,
      isCalibrated: false,
      pairedAt: DateTime.now(),
    );
  }

  /// Locates a characteristic by UUID string.
  BluetoothCharacteristic? findCharacteristic(String uuid) {
    final target = uuid.toLowerCase();
    for (final c in deviceCharacteristics.value) {
      if (c.uuid.str128.toLowerCase() == target) {
        return c;
      }
    }
    return null;
  }

  /// Locates a service by UUID string.
  BluetoothService? findService(String uuid) {
    final target = uuid.toLowerCase();
    for (final s in deviceServices.value) {
      if (s.uuid.str128.toLowerCase() == target) {
        return s;
      }
    }
    return null;
  }

  void dispose() {
    _adapterSub?.cancel();
    _scanSub?.cancel();
    _connStateSub?.cancel();
    _charNotifySub?.cancel();
    _dataNotifySub?.cancel();
  }
}
