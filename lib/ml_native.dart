import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class TFLiteManager {
  static final TFLiteManager _instance = TFLiteManager._internal();
  factory TFLiteManager() => _instance;
  TFLiteManager._internal();
  static TFLiteManager get instance => _instance;

  Interpreter? _interpreter;
  bool _isBusy = false;

  Future<void> loadModel() async {
    if (_interpreter != null) return;
    try {
      _interpreter =
          await Interpreter.fromAsset('assets/tracking/detect.tflite');
      print("✅ YOLO11 High-Speed Loaded");
    } catch (e) {
      print("❌ Model Error: $e");
    }
  }

  Future<List<Map<String, dynamic>>> detect(CameraImage image) async {
    if (_interpreter == null || _isBusy) return [];
    _isBusy = true;

    try {
      // 1. Fast Conversion
      img.Image? converted;
      if (image.format.group == ImageFormatGroup.bgra8888) {
        converted = img.Image.fromBytes(
          width: image.width,
          height: image.height,
          bytes: image.planes[0].bytes.buffer,
          order: img.ChannelOrder.bgra,
        );
      } else {
        _isBusy = false;
        return [];
      }

      // 2. Square Crop & Resize back to 640 (Fixes Bad Precondition)
      int minDim = converted.width < converted.height
          ? converted.width
          : converted.height;
      img.Image squareImg = img.copyCrop(
        converted,
        x: (converted.width - minDim) ~/ 2,
        y: (converted.height - minDim) ~/ 2,
        width: minDim,
        height: minDim,
      );
      img.Image resized = img.copyResize(squareImg, width: 640, height: 640);

      // 3. Optimized Float32 Buffer filling
      var inputBuffer = Float32List(1 * 640 * 640 * 3);
      int pixelIndex = 0;

      // Using the internal buffer is faster than a standard for-in loop
      final bytes = resized.buffer.asUint8List();
      for (int i = 0; i < bytes.length; i += 4) {
        // img package uses RGBA order by default
        inputBuffer[pixelIndex++] = bytes[i] / 255.0; // R
        inputBuffer[pixelIndex++] = bytes[i + 1] / 255.0; // G
        inputBuffer[pixelIndex++] = bytes[i + 2] / 255.0; // B
        // Skip i+3 (Alpha)
      }

      // 4. Output: [1, 84, 8400]
      var outputBuffer = List.filled(1 * 84 * 8400, 0.0).reshape([1, 84, 8400]);
      _interpreter!.run(inputBuffer.buffer, outputBuffer);

      List<List<double>> output = outputBuffer[0];
      List<Map<String, dynamic>> detections = [];

      // 5. Threshold at 6% as you requested
      for (int i = 0; i < 8400; i++) {
        double ballScore = output[36][i]; // Class 32: Sports Ball

        if (ballScore > 0.06) {
          detections.add({
            'label': 'Ball',
            'score': ballScore,
            'rect': {
              'x': (output[0][i] - (output[2][i] / 2)) / 640.0,
              'y': (output[1][i] - (output[3][i] / 2)) / 640.0,
              'w': output[2][i] / 640.0,
              'h': output[3][i] / 640.0,
            }
          });
        }
      }

      if (detections.isNotEmpty) {
        detections.sort((a, b) => (b['score'] as double).compareTo(a['score']));
        print(
            "🎾 BALL DETECTED! (${(detections.first['score'] * 100).toStringAsFixed(1)}%)");
        return [detections.first];
      }

      return [];
    } catch (e) {
      print("❌ AI Error: $e");
      return [];
    } finally {
      // 6. Mandatory Rest (Reduce sample rate to stop lag)
      // This gives the CPU 500ms to recover between frames
      await Future.delayed(const Duration(milliseconds: 500));
      _isBusy = false;
    }
  }

  void close() => _interpreter?.close();
}
