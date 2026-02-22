import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../ml_native.dart';

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
  final TFLiteManager _ml = TFLiteManager.instance;

  bool _isInitialized = false;
  String? _errorMessage;
  bool _isRecording = false;
  bool _isUploading = false;

  List<Map<String, dynamic>> _detections = [];
  String _lastCommand = "S";
  CameraDescription? _selectedCamera;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception("No cameras available");

      _selectedCamera = cameras.first;

      final ctrl = CameraController(
        _selectedCamera!,
        ResolutionPreset.medium,
        enableAudio: true,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

      await ctrl.initialize();
      await _ml.loadModel();

      ctrl.startImageStream((image) {
        if (mounted && _selectedCamera != null) {
          _ml.detect(image, _selectedCamera!).then((results) {
            if (!mounted) return;
            setState(() => _detections = results);
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

    final rect = results.first['rect'];
    final ballX = rect['x'] + (rect['w'] / 2);

    if (ballX < 0.4) {
      _sendTrackingCommand("0"); // Left
    } else if (ballX > 0.6) {
      _sendTrackingCommand("1"); // Right
    } else {
      _sendTrackingCommand("S"); // Stop
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
    } catch (e) {
      print("❌ Start Recording Error: $e");
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) return;
    try {
      final XFile file = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);
      _uploadVideo(File(file.path));
    } catch (e) {
      print("❌ Stop Recording Error: $e");
      setState(() => _isRecording = false);
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
    if (_errorMessage != null) {
      return Scaffold(body: Center(child: Text(_errorMessage!)));
    }
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Tennis Tracker")),
      body: LayoutBuilder(builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(_controller!),

            // Bounding Box Overlay
            for (var det in _detections) _buildMarker(det, constraints),

            // UI Overlays
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

            if (!widget.isConnected)
              const Positioned(
                  top: 60,
                  left: 20,
                  child: Text("⚠️ Bluetooth Disconnected",
                      style: TextStyle(color: Colors.red))),

            _buildRecordUI(),

            if (_isUploading)
              Container(
                  color: Colors.black54,
                  child: const Center(child: CircularProgressIndicator())),
          ],
        );
      }),
    );
  }

  Widget _buildMarker(Map<String, dynamic> det, BoxConstraints constraints) {
    final rect = det['rect'];
    return Positioned(
      left: rect['x'] * constraints.maxWidth,
      top: rect['y'] * constraints.maxHeight,
      width: rect['w'] * constraints.maxWidth,
      height: rect['h'] * constraints.maxHeight,
      child: Container(
        decoration: BoxDecoration(
            border: Border.all(color: Colors.greenAccent, width: 3)),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            color: Colors.black45,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              "${det['label']} ${(det['score'] * 100).toInt()}%",
              style: const TextStyle(color: Colors.greenAccent, fontSize: 10),
            ),
          ),
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
