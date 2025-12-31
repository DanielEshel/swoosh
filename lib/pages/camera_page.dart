import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:swoosh/ml_stub.dart'
    if (dart.library.ffi) 'package:swoosh/ml_native.dart';

class CameraPage extends StatefulWidget {
  // NEW: BLE callback instead of servoCharacteristic
  final Future<void> Function(String) onSendCommand;

  // NEW: whether BLE is connected (from AppShell)
  final bool isConnected;

  const CameraPage({
    super.key,
    required this.onSendCommand,
    required this.isConnected,
  });

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  // no tflite for now
  late final TFLiteManager _ml = TFLiteManager();

  bool _isInitialized = false;
  String? _errorMessage;

  bool _isRecording = false;
  bool _isUploading = false;

  Rect? _ballRect;
  double? _confidence;

  @override
  void initState() {
    super.initState();
    _initCameraAndModel();
  }

  Future<void> _initCameraAndModel() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception("No cameras available");

      final camera = cameras.first;

      final ctrl = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await ctrl.initialize();

      // Load ML only if available (Android/iOS)
      // no tflite for now
      // await _ml.loadModel();

      if (!mounted) return;

      setState(() {
        _controller = ctrl;
        _isInitialized = true;
        _errorMessage = null;
      });
    } catch (e) {
      _handleError("Camera init failed: $e");
    }
  }

  void _handleError(String msg) {
    if (!mounted) return;
    setState(() {
      _isInitialized = false;
      _errorMessage = msg;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ============================================================
  // BLE SERVO COMMAND
  // ============================================================
  Future<void> _sendServoCommand(String cmd) async {
    if (!widget.isConnected) {
      _showSnackBar("Not connected! Connect in Home tab.");
      return;
    }
    try {
      await widget.onSendCommand(cmd);
    } catch (e) {
      _showSnackBar("Failed sending command: $e");
    }
  }

  // ============================================================
  // VIDEO RECORDING + UPLOAD
  // ============================================================
  Future<void> _startRecording() async {
    if (_controller == null) return;
    try {
      await _controller!.startVideoRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      _showSnackBar("Error starting recording: $e");
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null) return;
    try {
      final XFile file = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);
      _uploadVideo(File(file.path));
    } catch (e) {
      _showSnackBar("Error stopping recording: $e");
    }
  }

  Future<void> _uploadVideo(File file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar("Login required to upload");
      return;
    }

    setState(() => _isUploading = true);

    try {
      final fileName = "${DateTime.now().millisecondsSinceEpoch}.mp4";
      final ref = FirebaseStorage.instance.ref("videos/${user.uid}/$fileName");

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      await FirebaseDatabase.instance.ref("videos/${user.uid}").push().set({
        "videoUrl": url,
        "timestamp": ServerValue.timestamp,
        "title": fileName,
      });

      _showSnackBar("Upload successful!");
    } catch (e) {
      _showSnackBar("Upload failed: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _controller?.dispose();
    _ml.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(body: Center(child: Text(_errorMessage!)));
    }

    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isBtReady = widget.isConnected;

    return Scaffold(
      appBar: AppBar(title: const Text("Tennis Tracker")),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          // 🎮 Only show servo controls if BLE is connected
          if (isBtReady)
            Positioned(
              top: 40,
              left: 30,
              right: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildArrowBtn(Icons.arrow_back_ios_new, "0"), // left
                  _buildArrowBtn(Icons.arrow_forward_ios, "1"), // right
                ],
              ),
            ),

          // ⚠️ If NOT connected, show warning
          if (!isBtReady)
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bluetooth_disabled,
                          color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text("Connect in Home Tab",
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),

          // Upload overlay
          if (_isUploading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // REC button
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: _isRecording ? _stopRecording : _startRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: _isRecording ? Colors.red : Colors.transparent,
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.videocam,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrowBtn(IconData icon, String cmd) {
    return GestureDetector(
      onTapDown: (_) => _sendServoCommand(cmd), // start moving
      onTapUp: (_) => _sendServoCommand("S"), // stop when released
      onTapCancel: () => _sendServoCommand("S"), // stop if finger slides away
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}
