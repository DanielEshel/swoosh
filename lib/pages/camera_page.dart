import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../ml_stub.dart' if (dart.library.ffi) '../ml_native.dart';

class CameraPage extends StatefulWidget {
  final Future<void> Function(String) onSendCommand;
  final bool isConnected;

  const CameraPage(
      {super.key, required this.onSendCommand, required this.isConnected});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  // Use Singleton
  final TFLiteManager _ml = TFLiteManager.instance;

  bool _isInitialized = false;
  String? _errorMessage;
  bool _isRecording = false;
  bool _isUploading = false;

  List<Map<String, dynamic>> _detections = [];
  String _lastCommand = "S";

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception("No cameras available");

      final ctrl = CameraController(
        cameras.first,
        ResolutionPreset.medium, // Keeping it medium to reduce lag
        enableAudio: true,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

      await ctrl.initialize();

      // We don't load model here anymore, it's done in main.dart!

      ctrl.startImageStream((image) {
        // Only run if manager is ready
        if (mounted) {
          _ml.detect(image).then((results) {
            if (!mounted) return;
            if (results.isNotEmpty) {
              setState(() => _detections = results);
              // Log coordinates to console as requested
              print("📍 Ball at: ${results.first['rect']}");
            } else {
              if (_detections.isNotEmpty) setState(() => _detections = []);
            }
            _runTrackingLogic(results);
          });
        }
      });

      setState(() {
        _controller = ctrl;
        _isInitialized = true;
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Camera Error: $e");
    }
  }

  void _runTrackingLogic(List<Map<String, dynamic>> results) {
    if (results.isEmpty) {
      if (_lastCommand != "S") _sendTrackingCommand("S");
      return;
    }

    final ballX = results.first['rect']['x'] + (results.first['rect']['w'] / 2);

    if (ballX < 0.4) {
      _sendTrackingCommand("0");
    } else if (ballX > 0.6) {
      _sendTrackingCommand("1");
    } else {
      _sendTrackingCommand("S");
    }
  }

  Future<void> _sendTrackingCommand(String cmd) async {
    if (_lastCommand == cmd) return;
    _lastCommand = cmd;
    if (widget.isConnected) {
      print("📡 Sending Bluetooth: $cmd");
      await widget.onSendCommand(cmd);
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null || _controller!.value.isRecordingVideo) return;
    try {
      await _controller!.startVideoRecording();
      setState(() => _isRecording = true);
      print("🎥 Recording Started");
    } catch (e) {
      print("❌ Start Recording Error: $e");
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null) return;
    // CRASH FIX: Checking state before stopping
    if (!_controller!.value.isRecordingVideo) {
      setState(() => _isRecording = false);
      return;
    }

    try {
      final XFile file = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);
      print("✅ Recording Stopped: ${file.path}");
      _uploadVideo(File(file.path));
    } catch (e) {
      print("❌ Stop Recording Error: $e");
      setState(() => _isRecording = false); // Reset state anyway
    }
  }

  Future<void> _uploadVideo(File file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
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
      print("☁️ Upload Complete");
    } catch (e) {
      print("❌ Upload Error: $e");
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null)
      return Scaffold(body: Center(child: Text(_errorMessage!)));
    if (!_isInitialized)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Tennis Tracker")),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),

          // Debug Text Overlay
          Positioned(
            top: 20,
            left: 20,
            child: Text(
              _detections.isEmpty ? "Scanning..." : "BALL FOUND!",
              style: TextStyle(
                  color:
                      _detections.isEmpty ? Colors.white : Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 20),
            ),
          ),

          for (var det in _detections) _buildMarker(det),

          if (!widget.isConnected)
            Positioned(
                top: 60,
                left: 20,
                child: Text("⚠️ Bluetooth Disconnected",
                    style: TextStyle(color: Colors.red))),

          _buildRecordUI(),

          if (_isUploading)
            Container(
                color: Colors.black54,
                child: Center(child: CircularProgressIndicator())),

          // Inside your Stack widget in the build method:
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              padding: EdgeInsets.all(8),
              color: Colors.black54,
              child: Text(
                TFLiteManager.instance.lastStatus,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ValueListenableBuilder<String>(
            valueListenable: TFLiteManager.status,
            builder: (context, value, child) {
              return Positioned(
                top: 60,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black54,
                  child: Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMarker(Map<String, dynamic> det) {
    final rect = det['rect'];

    // We use a simple FractionallySizedBox or manual calculation
    // since we already have normalized (0.0 to 1.0) coordinates.
    return Positioned(
      left: rect['x'] * MediaQuery.of(context).size.width,
      top: rect['y'] * MediaQuery.of(context).size.height,
      width: rect['w'] * MediaQuery.of(context).size.width,
      height: rect['h'] * MediaQuery.of(context).size.height,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.greenAccent, width: 3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          " ${det['score'].toStringAsFixed(2)}",
          style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 10,
              backgroundColor: Colors.black54),
        ),
      ),
    );
  }

  Widget _buildRecordUI() {
    return Positioned(
      bottom: 30,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: _isRecording ? _stopRecording : _startRecording,
          child: Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              color: _isRecording ? Colors.red : Colors.transparent,
            ),
            child: Icon(_isRecording ? Icons.stop : Icons.videocam,
                color: Colors.white, size: 40),
          ),
        ),
      ),
    );
  }
}
