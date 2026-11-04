// Re-export central BleDeviceManager types for backward compatibility.
export 'ble_command_service.dart';
export 'ble_device_manager.dart';

import 'ble_device_manager.dart';

/// Legacy alias for [BleDeviceManager].
typedef BleService = BleDeviceManager;
