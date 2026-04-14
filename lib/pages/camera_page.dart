import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added for session uploads

import '../features/tracking/tracking_api.g.dart';
import '../features/tracking/ball_overlay.dart';

class CameraPage extends StatefulWidget {
  // 1. Cleaned constructor to match the new AppShell
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> implements BallDetectionApi {
  final BallTrackerApi _api = BallTrackerApi();
  int? _textureId;
  String? _errorMessage;

  BallDetection? _latestDetection;

  // Recording State Variables
  bool _isRecording = false;
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

  // --- RECORDING & FIREBASE LOGIC ---

  void _toggleRecording() {
    if (_isRecording) {
      _stopAndUploadSession();
    } else {
      setState(() {
        _isRecording = true;
        _sessionData.clear(); // Clear previous session data
      });
    }
  }

  Future<void> _stopAndUploadSession() async {
    setState(() {
      _isRecording = false;
    });

    if (_sessionData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data captured to upload.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading session to Firebase...')),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Upload the recorded tracking points to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('sessions')
            .add({
          'timestamp': FieldValue.serverTimestamp(),
          'total_frames': _sessionData.length,
          'tracking_data': _sessionData,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upload Complete! ✅')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload Failed: $e')),
        );
      }
    }
  }

  @override
  void onDetection(BallDetection detection) {
    setState(() {
      _latestDetection = detection;
    });

    // If we are recording, log the coordinate data
    if (_isRecording) {
      _sessionData.add({
        'x': detection.x,
        'y': detection.y,
        'confidence': detection.confidence,
        'time': DateTime.now().millisecondsSinceEpoch,
      });
    }
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
      // Recording Button Layer
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleRecording,
        icon: Icon(_isRecording ? Icons.stop : Icons.fiber_manual_record),
        label: Text(_isRecording ? "Stop & Save" : "Record Session"),
        backgroundColor: _isRecording ? Colors.red : Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }
}
