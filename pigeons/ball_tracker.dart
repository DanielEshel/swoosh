import 'package:pigeon/pigeon.dart';

// Generates the Swift and Dart code automatically
@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/features/tracking/tracking_api.g.dart',
  dartOptions: DartOptions(),
  swiftOut: 'ios/Runner/TrackingApi.g.swift',
  swiftOptions: SwiftOptions(),
))
class TrackingConfig {
  bool useFrontCamera;
  // We can add more config later (like camera resolution preferences)

  TrackingConfig({this.useFrontCamera = false});
}

class BallDetection {
  double x;
  double y;
  double width;
  double height;
  double confidence;
  bool isKalmanPrediction;

  BallDetection({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
    required this.isKalmanPrediction,
  });
}

enum ThermalLevel { nominal, fair, serious, critical }

// HostApi: Dart calls these methods in Swift
@HostApi()
abstract class BallTrackerApi {
  @async
  int startTracking(
      TrackingConfig config); // Returns the textureId for the camera feed

  void stopTracking();
}

// FlutterApi: Swift calls these methods to push data to Dart
@FlutterApi()
abstract class BallDetectionApi {
  void onDetection(BallDetection detection);
  void onThermalWarning(ThermalLevel level);
}

@HostApi()
abstract class BleCommandApi {
  void scanForDevices();
  void connectToDevice(String deviceId);
  void disconnectDevice();
}

@FlutterApi()
abstract class BleStateApi {
  void onDeviceDiscovered(String id, String name);
  void onConnectionStateChanged(
      String state); // e.g., "scanning", "connected", "disconnected"
}
