import 'package:flutter/foundation.dart';
// Adjust this import to point to your actual generated pigeon file
import '../features/tracking/tracking_api.g.dart';

class BleService extends ChangeNotifier implements BleStateApi {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;

  final BleCommandApi _commandApi = BleCommandApi();
  int currentDistance = 0;

  String connectionState =
      'disconnected'; // 'disconnected', 'scanning', 'connected'
  Map<String, String> discoveredDevices = {}; // Maps deviceId to Name

  BleService._internal() {
    // Register this class to receive callbacks from the native Swift side
    BleStateApi.setup(this);
  }

  // --- Commands sent to Swift ---

  Future<void> scanForDevices() async {
    discoveredDevices.clear();
    notifyListeners();
    try {
      await _commandApi.scanForDevices();
    } catch (e) {
      debugPrint("Error scanning for devices: $e");
    }
  }

  Future<void> connectToDevice(String deviceId) async {
    try {
      await _commandApi.connectToDevice(deviceId);
    } catch (e) {
      debugPrint("Error connecting: $e");
    }
  }

  Future<void> disconnect() async {
    try {
      await _commandApi.disconnectDevice();
    } catch (e) {
      debugPrint("Error disconnecting: $e");
    }
  }

  // --- Callbacks received from Swift ---

  @override
  void onConnectionStateChanged(String state) {
    connectionState = state;
    notifyListeners(); // Tells the UI to rebuild
  }

  @override
  void onDeviceDiscovered(String id, String name) {
    discoveredDevices[id] = name;
    notifyListeners();

    // Auto-connect for a smoother experience (optional)
    // If you only have one ESP32, you can just instantly connect when found:
    // connectToDevice(id);
  }

  @override
  void onSensorDataReceived(String data) {
    try {
      currentDistance = int.parse(data);
      notifyListeners(); // Update the UI with the new distance
      debugPrint("Proximity Sensor: $currentDistance cm");
    } catch (e) {
      debugPrint("Error parsing sensor data: $e");
    }
  }
}
