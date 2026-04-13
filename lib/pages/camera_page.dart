import 'dart:async';
import 'package:flutter/material.dart';
import '../features/tracking/tracking_api.g.dart';
// 1. You MUST import the overlay file we created
import '../features/tracking/ball_overlay.dart';

class CameraPage extends StatefulWidget {
  final Future<void> Function(String) onSendCommand;
  final bool isConnected;

  const CameraPage(
      {super.key, required this.onSendCommand, required this.isConnected});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> implements BallDetectionApi {
  final BallTrackerApi _api = BallTrackerApi();
  int? _textureId;
  String? _errorMessage;

  // 2. Add this variable to store the ball's position
  BallDetection? _latestDetection;

  @override
  void initState() {
    super.initState();
    // Tells Pigeon to send native detections to THIS class
    BallDetectionApi.setup(this);
    _startNativeCamera();
  }

  Future<void> _startNativeCamera() async {
    try {
      final config = TrackingConfig(useFrontCamera: false);
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
    _api.stopTracking();
    super.dispose();
  }

  // 3. Update this method to actually handle the data from Swift
  @override
  void onDetection(BallDetection detection) {
    setState(() {
      _latestDetection = detection;
    });
  }

  @override
  void onThermalWarning(ThermalLevel level) {
    print("🔥 Thermal Warning: $level");
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(body: Center(child: Text(_errorMessage!)));
    }

    if (_textureId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Native Tennis Tracker")),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The Camera Feed
          Texture(textureId: _textureId!),

          // The Bounding Box Layer
          // Now that _latestDetection is updated, this will draw the box
          BallOverlay(detection: _latestDetection),

          // Debug Text Overlay
          Positioned(
            top: 20,
            left: 20,
            child: Text(
              _latestDetection == null
                  ? "Searching for Tennis Ball..."
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
        ],
      ),
    );
  }
}
