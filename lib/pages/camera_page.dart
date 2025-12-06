import 'dart:async';
import 'dart:convert'; // 👈 Added for utf8 encoding
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // 👈 Added
import 'package:tflite_flutter/tflite_flutter.dart';

class CameraPage extends StatefulWidget {
  // 📥 Receive the connected servo characteristic from AppShell
  final BluetoothCharacteristic? servoCharacteristic;

  const CameraPage({super.key, this.servoCharacteristic});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  Interpreter? _interpreter;

  // 🚦 State Variables
  bool _isInitialized = false;
  String? _errorMessage;

  // 🎥 Video State Variables
  bool _isRecording = false;
  bool _isUploading = false;

  // Last detected ball position
  Rect? _ballRect;
  double? _confidence;

  @override
  void initState() {
    super.initState();
    _initCameraAndModel();
  }

  Future<void> _initCameraAndModel() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();

      // 1. Fetch Cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception("No cameras found");

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // 2. Setup Controller
      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: true, 
      );

      // 3. Initialize Camera
      await controller.initialize();
      
      if (!mounted) return;

      // 4. Load TFLite (Optional)
      // try { _interpreter = await Interpreter.fromAsset('tennis_ball.tflite'); } catch (e) { ... }

      setState(() {
        _controller = controller;
        _isInitialized = true;
        _errorMessage = null;
      });

    } on CameraException catch (e) {
      _handleError("Camera Error: ${e.description}");
    } catch (e) {
      _handleError("Failed to initialize: $e");
    }
  }

  void _handleError(String message) {
    debugPrint(message);
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _isInitialized = false;
    });
    _showSnackBar(message);
  }

  // 📡 SERVO COMMAND LOGIC
  Future<void> _sendServoCommand(String cmd) async {
    // If not connected, show a warning
    if (widget.servoCharacteristic == null) {
      _showSnackBar("Servo not connected! Connect in Home Tab first.");
      return;
    }

    try {
      // Send "L" or "R" to ESP32
      await widget.servoCharacteristic!.write(utf8.encode(cmd));
    } catch (e) {
      debugPrint("Error sending command: $e");
    }
  }
  // 🔴 1. Start Recording (With user feedback)
  Future<void> _startRecording() async {
    if (_controller == null || _controller!.value.isRecordingVideo) return;

    try {
      await _controller!.startVideoRecording();
      setState(() => _isRecording = true);
    } on CameraException catch (e) {
      _showSnackBar("Camera Error: ${e.description}");
    } catch (e) {
      _showSnackBar("Could not start recording: $e");
    }
  }

  // ⬛ 2. Stop Recording (With user feedback)
  Future<void> _stopRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) return;

    try {
      final XFile videoFile = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);
      _uploadVideo(File(videoFile.path));
    } catch (e) {
      _showSnackBar("Error saving video: $e");
    }
  }

  // ☁️ 3. Upload Logic
  Future<void> _uploadVideo(File videoFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Please log in to upload videos');
      return;
    }

    setState(() => _isUploading = true);

    try {
      final String fileName = "${DateTime.now().millisecondsSinceEpoch}.mp4";
      
      // A. Storage
      final ref = FirebaseStorage.instance.ref().child('videos/${user.uid}/$fileName');
      await ref.putFile(videoFile);
      final String downloadUrl = await ref.getDownloadURL();

      // B. Database
      final databaseRef = FirebaseDatabase.instance.ref("videos/${user.uid}");
      await databaseRef.push().set({
        "videoUrl": downloadUrl,
        "timestamp": ServerValue.timestamp,
        "title": fileName,
      });

      if (mounted) _showSnackBar('Video uploaded successfully! 🎾');

    } catch (e) {
      if (mounted) _showSnackBar('Upload failed: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  void _processCameraImage(CameraImage image) async {
     // ... Your existing logic ...
     // Since you haven't enabled stream in init, this won't run yet, which is fine.
  }


@override
  void dispose() {
    if (_controller != null && _controller!.value.isStreamingImages) {
      _controller!.stopImageStream();
    }
    _controller?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!)); // Simple error view
    }

    if (!_isInitialized || _controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Check if bluetooth is ready
    final bool isBtReady = widget.servoCharacteristic != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Tennis Ball Tracker')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Feed
          CameraPreview(_controller!),
          
          // 2. Ball Detection Overlay (Your existing code)
          if (_ballRect != null)
            CustomPaint(
              painter: _BallPainter(rect: _ballRect!, confidence: _confidence),
            ),

          // 🎮 3. SERVO ARROW PAD (Only if connected)
          if (isBtReady)
            Positioned(
              top: 50, // Near the top
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // LEFT ARROW
                  _buildArrowBtn(Icons.arrow_back_ios_new, "L"),
                  
                  // RIGHT ARROW
                  _buildArrowBtn(Icons.arrow_forward_ios, "R"),
                ],
              ),
            ),

          // ⚠️ 4. Disconnected Warning (If NOT connected)
          if (!isBtReady)
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bluetooth_disabled, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text("Servo Disconnected", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),

          // 5. Upload Loading Overlay
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 20),
                    Text("Uploading...", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),

          // 6. Record Button
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
                  child: Center(
                    child: Icon(
                      _isRecording ? Icons.stop : Icons.videocam,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 Helper Widget for Arrow Buttons
  Widget _buildArrowBtn(IconData icon, String cmd) {
    return GestureDetector(
      // Send command immediately on press
      onTapDown: (_) => _sendServoCommand(cmd),
      
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.black45,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      ),
    );
  }
}

// ... (Your existing _BallPainter class remains unchanged) ...
class _BallPainter extends CustomPainter {
  final Rect rect; 
  final double? confidence;
  _BallPainter({required this.rect, this.confidence});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.greenAccent;
    final left = rect.left * size.width;
    final top = rect.top * size.height;
    final right = rect.right * size.width;
    final bottom = rect.bottom * size.height;
    final box = Rect.fromLTRB(left, top, right, bottom);
    canvas.drawRect(box, paint);
  }
  @override
  bool shouldRepaint(covariant _BallPainter oldDelegate) => true;
}