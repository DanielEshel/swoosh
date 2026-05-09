import 'package:flutter/foundation.dart';
import '../features/tracking/tracking_api.g.dart';

class BleService extends ChangeNotifier implements BleStateApi {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;

  final BleCommandApi _commandApi = BleCommandApi();

  // --- Connection State ---
  String connectionState = 'disconnected'; 
  Map<String, String> discoveredDevices = {}; 

  // --- Live Hardware Metrics ---
  double lastKnownDistance = 0.0;
  double cameraFps = 0.0;
  double modelFps = 0.0;

  BleService._internal() {
    // Connects this class to the native Swift/iOS side
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
    notifyListeners(); 
  }

  @override
  void onDeviceDiscovered(String id, String name) {
    discoveredDevices[id] = name;
    notifyListeners();
  }

  /// This is called every 500ms-1000ms by the ESP32.
  @override
  void onSensorDataReceived(String distance) {
    // Convert the string to a number so we can use it for logic or UI
    lastKnownDistance = double.tryParse(distance) ?? 0.0;
    
    // CRITICAL: notifyListeners() ensures your UI actually updates when the data arrives!
    notifyListeners(); 
    
    debugPrint("🎾 Distance from ESP32: $lastKnownDistance cm");
  }

  /// Helper to update FPS metrics from your tracking view model
  void updatePerformanceMetrics(double camFps, double mlFps) {
    cameraFps = camFps;
    modelFps = mlFps;
    notifyListeners();
  }
}