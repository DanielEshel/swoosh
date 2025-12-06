import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  Interpreter? _interpreter;

  // 🚦 State Variables
  bool _isInitialized = false;
  bool _isDetecting = false;
  String? _errorMessage; // 👈 Track errors to show in UI

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

  // ✅ BETTER: Step-by-step initialization with specific error handling
  Future<void> _initCameraAndModel() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();

      // 1. Fetch Cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception("No cameras found on device");
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // 2. Setup Controller
      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: true, // Required for video
      );

      // 3. Initialize Camera
      await controller.initialize();
      
      // Safety check: Did user leave the screen while we were loading?
      if (!mounted) return;

      // 4. Load TFLite (Optional)
      // try {
      //   _interpreter = await Interpreter.fromAsset('tennis_ball.tflite');
      // } catch (e) {
      //   debugPrint("Warning: TFLite model failed to load, but camera is OK. Error: $e");
      //   // We don't stop the app here, we just log it and continue
      // }

      // 5. Success! Update State
      setState(() {
        _controller = controller;
        _isInitialized = true;
        _errorMessage = null; // Clear any previous errors
      });

    } on CameraException catch (e) {
      // Specific handling for Camera permission errors
      _handleError("Camera Error: ${e.description}");
    } catch (e) {
      // Generic handling for everything else
      _handleError("Failed to initialize: $e");
    }
  }

  // 🛠 Helper to handle errors cleanly
  void _handleError(String message) {
    debugPrint(message); // Log for developer
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
      _isInitialized = false;
    });
    // Show a snackbar so the user knows what happened
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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

  // ... (Keep _processCameraImage and _BallPainter exactly as they were) ...
  
  void _processCameraImage(CameraImage image) async {
     // ... Your existing logic ...
     // Since you haven't enabled stream in init, this won't run yet, which is fine.
  }

@override
  void dispose() {
    // 1. Stop the stream if it exists (important for TFLite later)
    if (_controller != null && _controller!.value.isStreamingImages) {
      _controller!.stopImageStream();
    }
    
    // 2. Dispose the controller properly
    _controller?.dispose();
    
    // 3. Close the interpreter
    _interpreter?.close();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Handle Error State
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Camera Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_errorMessage!, textAlign: TextAlign.center),
              ),
              ElevatedButton(
                onPressed: _initCameraAndModel, // Retry button!
                child: const Text("Retry"),
              )
            ],
          ),
        ),
      );
    }

    // 2. Handle Loading State
    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 3. Main Camera UI
    return Scaffold(
      appBar: AppBar(title: const Text('Tennis Ball Tracker')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          
          if (_ballRect != null)
            CustomPaint(
              painter: _BallPainter(rect: _ballRect!, confidence: _confidence),
            ),

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
}

// ... (Keep your _BallPainter class exactly as it was) ...
class _BallPainter extends CustomPainter {
  final Rect rect; // normalized (0..1) rect
  final double? confidence;

  _BallPainter({
    required this.rect,
    this.confidence,
  });

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

    if (confidence != null) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${(confidence! * 100).toStringAsFixed(1)}%',
          style: const TextStyle(
            color: Colors.greenAccent,
            fontSize: 14,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(box.left, math.max(0, box.top - textPainter.height - 4)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BallPainter oldDelegate) {
    return rect != oldDelegate.rect || confidence != oldDelegate.confidence;
  }
}