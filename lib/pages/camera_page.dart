import 'dart:async';
import 'package:flutter/material.dart';
// Import the file Pigeon just generated
import '../features/tracking/tracking_api.g.dart';

class CameraPage extends StatefulWidget {
  final Future<void> Function(String) onSendCommand;
  final bool isConnected;

  const CameraPage(
      {super.key, required this.onSendCommand, required this.isConnected});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

// We implement BallDetectionApi to receive the stream from Swift
class _CameraPageState extends State<CameraPage> implements BallDetectionApi {
  final BallTrackerApi _api = BallTrackerApi();
  int? _textureId;
  String? _errorMessage;
  BallDetection? _latestDetection;

  @override
  void initState() {
    super.initState();
    // 1. Tell Pigeon that THIS class will handle incoming Swift messages
    BallDetectionApi.setup(this);
    // 2. Start the camera
    _startNativeCamera();
  }

  Future<void> _startNativeCamera() async {
    try {
      final config = TrackingConfig(useFrontCamera: false);
      // Calls Swift: startTracking() and waits for the texture ID
      final id = await _api.startTracking(config);
      setState(() {
        _textureId = id;
      });
    } catch (e) {
      setState(() => _errorMessage = "Camera Error: $e");
    }
  }

  @override
  void dispose() {
    // Clean up the native camera when leaving the page
    _api.stopTracking();
    super.dispose();
  }

  // MARK: - Pigeon FlutterApi Callbacks (Swift -> Dart)

  @override
  void onDetection(BallDetection detection) {
    // Swift found the ball! Update the UI.
    setState(() {
      _latestDetection = detection;
    });
  }

  @override
  void onThermalWarning(ThermalLevel level) {
    // We will handle device overheating warnings here later
    print("🔥 Thermal Warning: $level");
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(body: Center(child: Text(_errorMessage!)));
    }

    // Show a loader until Swift gives us the texture ID
    if (_textureId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Native Tennis Tracker")),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 3. The Magic Window: Flutter renders the raw GPU buffer zero-copy
          Texture(textureId: _textureId!),

          // Debug Overlay
          Positioned(
            top: 20,
            left: 20,
            child: Text(
              _latestDetection == null
                  ? "Scanning Native 30fps..."
                  : "BALL FOUND: ${(_latestDetection!.confidence * 100).toStringAsFixed(1)}%",
              style: TextStyle(
                color: _latestDetection == null
                    ? Colors.white
                    : Colors.greenAccent,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                backgroundColor: Colors.black54,
              ),
            ),
          ),

          // TODO: Add CustomPainter here to draw the bounding box using _latestDetection
        ],
      ),
    );
  }
}
