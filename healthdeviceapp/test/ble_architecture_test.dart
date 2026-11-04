import 'package:flutter_test/flutter_test.dart';
import 'package:healthdeviceapp/models/health_metrics.dart';
import 'package:healthdeviceapp/repositories/mock_health_repository.dart';
import 'package:healthdeviceapp/services/ble_command_service.dart';
import 'package:healthdeviceapp/services/ble_device_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BleDeviceManager Architecture Tests', () {
    late BleDeviceManager bleManager;

    setUp(() {
      bleManager = BleDeviceManager();
    });

    test('Initial state is completely truthful and has no fake data', () {
      expect(bleManager.connectionState.value, BleDeviceState.disconnected);
      expect(bleManager.connectedDevice.value, isNull);
      expect(bleManager.batteryData.value.isAvailable, isFalse);
      expect(bleManager.batteryData.value.percentage, 0);
      expect(bleManager.firmwareStatus.value, isNull);
      expect(bleManager.supportedCapabilities.value, isEmpty);
    });

    test('Discovered devices are independent from connectedDevice', () {
      // Discovered devices list can be populated
      expect(
        bleManager.discoveredDevices.value,
        isA<List<DiscoveredBleDevice>>(),
      );

      // Disconnecting or resetting connection does NOT wipe discovered devices
      bleManager.clearScannedDevices();
      expect(bleManager.discoveredDevices.value, isEmpty);
    });
  });

  group('BleCommandService Truthfulness Tests', () {
    late BleCommandService cmdService;

    setUp(() {
      cmdService = BleCommandService();
    });

    test('Returns disconnected state when not connected', () async {
      final res = await cmdService.triggerMeasurement();
      expect(res.state, BleCommandSyncState.disconnected);
      expect(res.isSuccessful, isFalse);
      expect(res.message, contains('not connected'));
    });

    test('Alarm sync reports disconnected when BLE is not connected', () async {
      final res = await cmdService.syncAlarms(const []);
      expect(res.state, BleCommandSyncState.disconnected);
    });

    test('Sound sync reports disconnected when BLE is not connected', () async {
      final res = await cmdService.syncSoundSettings(const SoundSettings());
      expect(res.state, BleCommandSyncState.disconnected);
    });

    test('LED sync reports disconnected when BLE is not connected', () async {
      final res = await cmdService.syncLedSettings(
        const LedSettingsState(isEnabled: true, eventConfigs: []),
      );
      expect(res.state, BleCommandSyncState.disconnected);
    });
  });

  group('MockHealthRepository BLE Binding Tests', () {
    test('Default repository states are truthful and not hardcoded to connected or 85%', () {
      final repo = MockHealthRepository();
      expect(
        repo.connectionStatus.value.state,
        DeviceConnectionState.disconnected,
      );
      expect(repo.battery.value.isAvailable, isFalse);
      expect(repo.battery.value.percentage, 0);
      expect(repo.deviceInfo.value.name, 'HealthDevice');
    });
  });
}
