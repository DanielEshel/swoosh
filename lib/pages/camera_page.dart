import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
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

  bool _isInitialized = false;
  bool _isDetecting = false;

  // Last detected ball position (normalized 0..1 in preview coordinates)
  Rect? _ballRect;
  double? _confidence;

  @override
  void initState() {
    super.initState();
    _initCameraAndModel();
  }

  Future<void> _initCameraAndModel() async {
    try {
      // Ensure binding
      WidgetsFlutterBinding.ensureInitialized();

      // 1. Init cameras
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();

      // 2. Load TFLite model
      // Place your model in assets and pubspec.yaml (e.g., assets/tennis_ball.tflite)
      _interpreter = await Interpreter.fromAsset('tennis_ball.tflite');

      // 3. Start image stream
      await _controller!.startImageStream(_processCameraImage);

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing camera/model: $e');
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting || _interpreter == null || !_isInitialized) return;
    _isDetecting = true;

    try {
      // TODO: convert CameraImage (YUV420) → input tensor format
      // (e.g., 224x224 RGB float32 or uint8 depending on your model)

      // Example placeholder input (you MUST replace with real preprocessing):
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final height = inputShape[1];
      final width = inputShape[2];

      // This is just a dummy zero-filled tensor as a placeholder:
      final input = List.generate(
        height,
        (_) => List.generate(
          width,
          (_) => List.filled(3, 0.0),
        ),
      );

      // Example output: [x_center, y_center, width, height, confidence]
      final output = List.filled(1, List.filled(5, 0.0));

      _interpreter!.run(input, output);

      final result = output[0];
      final xCenter = result[0]; // 0..1
      final yCenter = result[1]; // 0..1
      final w = result[2];       // 0..1
      final h = result[3];       // 0..1
      final conf = result[4];    // 0..1

      if (conf > 0.3) {
        final left = (xCenter - w / 2).clamp(0.0, 1.0);
        final top = (yCenter - h / 2).clamp(0.0, 1.0);
        final right = (xCenter + w / 2).clamp(0.0, 1.0);
        final bottom = (yCenter + h / 2).clamp(0.0, 1.0);

        setState(() {
          _ballRect = Rect.fromLTRB(left, top, right, bottom);
          _confidence = conf;
        });
      } else {
        setState(() {
          _ballRect = null;
          _confidence = null;
        });
      }
    } catch (e) {
      debugPrint('Error during inference: $e');
    } finally {
      _isDetecting = false;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tennis Ball Tracker'),
      ),
      body: _isInitialized && _controller != null
          ? LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(_controller!),
                    // Overlay bounding box
                    if (_ballRect != null)
                      CustomPaint(
                        painter: _BallPainter(
                          rect: _ballRect!,
                          confidence: _confidence,
                        ),
                        size: Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        ),
                      ),
                  ],
                );
              },
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

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
