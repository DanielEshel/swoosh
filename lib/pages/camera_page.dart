import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../features/tracking/tracking_api.g.dart';
import '../features/tracking/ball_overlay.dart';

class CameraPage extends StatefulWidget {
  final bool isConnected; // Restored from original UI requirements

  const CameraPage({super.key, required this.isConnected});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> implements BallDetectionApi {
  final BallTrackerApi _api = BallTrackerApi();
  int? _textureId;
  String? _errorMessage;
  BallDetection? _latestDetection;

  // Recording & Data State
  bool _isRecording = false;
  bool _isUploading = false;
  final List<Map<String, dynamic>> _sessionData = [];

  @override
  void initState() {
    super.initState();
    BallDetectionApi.setup(this);
    _startNativeCamera();
  }

  Future<void> _startNativeCamera() async {
    try {
      final config = TrackingConfig(useFrontCamera: false);
      final id = await _api.startTracking(config);
      setState(() => _textureId = id);
    } catch (e) {
      setState(() => _errorMessage = "Camera Error: $e");
    }
  }

  @override
  void dispose() {
    _api.stopTracking();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (!_isRecording) {
      // Tell Swift to start the AVAssetWriter
      await _api.startRecording();
      setState(() {
        _isRecording = true;
        _sessionData.clear();
      });
    } else {
      setState(() => _isRecording = false);
      // Tell Swift to stop, and it will return the path to the video
      String localPath = await _api.stopRecording();
      _uploadToFirebase(File(localPath));
    }
  }

  Future<void> _uploadToFirebase(File? videoFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);

    try {
      String? videoUrl;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // 1. Upload Video to Storage
      if (videoFile != null && videoFile.existsSync()) {
        final storageRef =
            FirebaseStorage.instance.ref("videos/${user.uid}/$timestamp.mp4");
        await storageRef.putFile(videoFile);
        videoUrl = await storageRef.getDownloadURL();
      }

      // 2. Upload Data to Realtime Database matching gallery.js paths
      final dbRef = FirebaseDatabase.instance.ref("videos/${user.uid}").push();

      await dbRef.set({
        "timestamp": timestamp, // Matched with gallery.js
        "videoUrl": videoUrl ?? "", // Matched with gallery.js
        "title": "Native Tracking Session", // Matched with gallery.js
        "rallyCount": _sessionData.length, // Proxy stat for now
        "tracking_points": _sessionData,
      });

      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Upload Complete! ✅")));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Upload Failed: $e")));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  void onDetection(BallDetection detection) {
    if (mounted) {
      setState(() => _latestDetection = detection);
      if (_isRecording) {
        _sessionData.add({
          'x': detection.x,
          'y': detection.y,
          'conf': detection.confidence,
          't': DateTime.now().millisecondsSinceEpoch,
        });
      }
    }
  }

  @override
  void onThermalWarning(ThermalLevel level) {}

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null)
      return Scaffold(body: Center(child: Text(_errorMessage!)));
    if (_textureId == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Native Tennis Tracker")),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Texture(textureId: _textureId!),
          BallOverlay(detection: _latestDetection),

          // --- RESTORED UI ELEMENTS ---

          // 1. Connection Status Overlay
          Positioned(
            top: 10,
            right: 10,
            child: Chip(
              label: Text(
                  widget.isConnected ? "ESP32 Connected" : "ESP32 Offline"),
              backgroundColor: widget.isConnected
                  ? Colors.green.withOpacity(0.8)
                  : Colors.red.withOpacity(0.8),
              labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),

          // 2. Detection Status & Monospace Proximity Display
          Positioned(
            top: 20,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _latestDetection == null
                      ? "Searching..."
                      : "BALL FOUND: ${(_latestDetection!.confidence * 100).toStringAsFixed(1)}%",
                  style: TextStyle(
                    color: _latestDetection == null
                        ? Colors.white
                        : Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    backgroundColor: Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: Colors.black54,
                  child: const Text(
                    "PROXIMITY: 0.0cm", // Restoring the monospace look from Tracking branch
                    style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          // 3. Uploading Loader
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleRecording,
        icon: Icon(_isRecording ? Icons.stop : Icons.videocam),
        label: Text(_isRecording ? "Stop & Upload" : "Record Session"),
        backgroundColor: _isRecording ? Colors.red : Colors.blue,
      ),
    );
  }
}
