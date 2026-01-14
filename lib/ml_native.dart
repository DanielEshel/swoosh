import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class TFLiteManager {
  Interpreter? _interpreter;
  List<String>? _labels;

  // 1. ADD THIS FLAG
  bool _isBusy = false;

  bool get isLoaded => _interpreter != null;

  // 2. ADD THIS GETTER
  bool get isBusy => _isBusy;

  Future<void> loadModel() async {
    try {
      _interpreter =
          await Interpreter.fromAsset('assets/tracking/tennis_ball.tflite');
      _labels = await _loadLabels('assets/tracking/labels.txt');
      print("TFLite model loaded.");
    } catch (e) {
      print("Error loading model: $e");
    }
  }

  Future<List<String>> _loadLabels(String path) async {
    final fileData = await rootBundle.loadString(path);
    return fileData.split('\n');
  }

  Future<List<Map<String, dynamic>>> detect(CameraImage image) async {
    if (_interpreter == null || _isBusy) return [];

    // 3. SET BUSY TO TRUE
    _isBusy = true;

    try {
      // Conversion logic (YUV -> RGB)
      final img.Image? converted = _convertYUV420ToImage(image);
      if (converted == null) return [];

      // Resize to 300x300 (standard for SSD MobileNet)
      final inputImage = img.copyResize(converted, width: 300, height: 300);

      // Prepare input
      var inputBytes = Uint8List(1 * 300 * 300 * 3);
      var pixelIndex = 0;
      for (var y = 0; y < 300; y++) {
        for (var x = 0; x < 300; x++) {
          var pixel = inputImage.getPixel(x, y);
          inputBytes[pixelIndex++] = pixel.r.toInt();
          inputBytes[pixelIndex++] = pixel.g.toInt();
          inputBytes[pixelIndex++] = pixel.b.toInt();
        }
      }

      // Prepare outputs
      var outputLocations = List.filled(1 * 10 * 4, 0.0).reshape([1, 10, 4]);
      var outputClasses = List.filled(1 * 10, 0.0).reshape([1, 10]);
      var outputScores = List.filled(1 * 10, 0.0).reshape([1, 10]);
      var numDetections = List.filled(1, 0.0).reshape([1]);

      var outputs = {
        0: outputLocations,
        1: outputClasses,
        2: outputScores,
        3: numDetections,
      };

      // Run Inference
      _interpreter!.runForMultipleInputs([inputBytes], outputs);

      // Parse Results
      List<Map<String, dynamic>> results = [];
      for (int i = 0; i < 10; i++) {
        double score = outputScores[0][i];
        if (score > 0.5) {
          int classIndex = (outputClasses[0][i] as double).toInt();
          String label = _labels != null && classIndex < _labels!.length
              ? _labels![classIndex]
              : "Unknown";

          if (label.contains("ball")) {
            results.add({
              'label': label,
              'score': score,
              'rect': {
                'y': outputLocations[0][i][0],
                'x': outputLocations[0][i][1],
                'h': outputLocations[0][i][2],
                'w': outputLocations[0][i][3],
              }
            });
          }
        }
      }
      return results;
    } catch (e) {
      print("Inference error: $e");
      return [];
    } finally {
      // 4. RESET BUSY TO FALSE
      _isBusy = false;
    }
  }

  // Helper: YUV to RGB
  img.Image? _convertYUV420ToImage(CameraImage cameraImage) {
    if (cameraImage.planes.length < 3) return null;
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int? uvPixelStride = cameraImage.planes[1].bytesPerPixel;

    final image = img.Image(width: width, height: height);

    for (int w = 0; w < width; w++) {
      for (int h = 0; h < height; h++) {
        final int uvIndex =
            uvPixelStride! * (w / 2).floor() + uvRowStride * (h / 2).floor();
        final int index = h * width + w;

        final y = cameraImage.planes[0].bytes[index];
        final u = cameraImage.planes[1].bytes[uvIndex];
        final v = cameraImage.planes[2].bytes[uvIndex];

        image.setPixelRgb(w, h, _yuv2rgb(y, u, v)[0], _yuv2rgb(y, u, v)[1],
            _yuv2rgb(y, u, v)[2]);
      }
    }
    return image;
  }

  List<int> _yuv2rgb(int y, int u, int v) {
    int r = (y + v * 1436 / 1024 - 179).round();
    int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
    int b = (y + u * 1814 / 1024 - 227).round();
    return [r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255)];
  }

  void close() {
    _interpreter?.close();
  }
}
