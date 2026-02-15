import 'dart:io';
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
  List<String>? _labels;
  bool _isBusy = false;
  int _lastRunTime = 0;

  bool get isLoaded => _interpreter != null;
  bool get isBusy => _isBusy;

  Future<void> loadModel() async {
    if (_interpreter != null) return;
    try {
      _interpreter =
          await Interpreter.fromAsset('assets/tracking/detect.tflite');
      _labels = await _loadLabels('assets/tracking/labelmap.txt');
      print("✅ TFLite model loaded.");
    } catch (e) {
      print("❌ Error loading model: $e");
    }
  }

  Future<List<String>> _loadLabels(String path) async {
    final fileData = await rootBundle.loadString(path);
    return fileData.split('\n');
  }

  Future<List<Map<String, dynamic>>> detect(CameraImage image) async {
    int now = DateTime.now().millisecondsSinceEpoch;
    // Throttle to 300ms (approx 3 FPS)
    if (_interpreter == null || _isBusy || (now - _lastRunTime < 300))
      return [];

    _isBusy = true;
    _lastRunTime = now;

    try {
      img.Image? converted;
      if (image.format.group == ImageFormatGroup.bgra8888) {
        converted = img.Image.fromBytes(
          width: image.width,
          height: image.height,
          bytes: image.planes[0].bytes.buffer,
          order: img.ChannelOrder.bgra,
        );
      } else {
        return [];
      }

      // Resize for Model (300x300)
      final inputImage = img.copyResize(converted, width: 300, height: 300);

      // --- 1. Prepare Input (RGB Integers) ---
      var input = List.generate(
        1,
        (index) => List.generate(
          300,
          (y) => List.generate(300, (x) {
            final pixel = inputImage.getPixel(x, y);
            return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
          }),
        ),
      );

      // --- 2. Run Inference ---
      var outputs = {
        0: List.filled(1 * 10 * 4, 0.0).reshape([1, 10, 4]),
        1: List.filled(1 * 10, 0.0).reshape([1, 10]),
        2: List.filled(1 * 10, 0.0).reshape([1, 10]),
        3: List.filled(1, 0.0).reshape([1]),
      };

      _interpreter!.runForMultipleInputs([input], outputs);

      // --- 3. Filter Results ---
      List<Map<String, dynamic>> results = [];
      for (int i = 0; i < 10; i++) {
        double score = (outputs[2] as List)[0][i];

        // Use a reasonable threshold
        if (score > 0.40) {
          int classIndex = (outputs[1] as List)[0][i].toInt();
          String label = _labels != null && classIndex < _labels!.length
              ? _labels![classIndex]
              : "Unknown";

          // STEP A: Label Check
          // We accept "sports ball" (obviously) AND "apple"/"orange" (because tennis balls are round)
          if (label.contains("ball") ||
              label.contains("apple") ||
              label.contains("orange")) {
            final loc = (outputs[0] as List)[0][i];
            // loc is [ymin, xmin, ymax, xmax] (0.0 to 1.0)

            // STEP B: Color Check (The "Tennis Ball" filter)
            // We sample the CENTER pixel of the detected box.
            double centerY = loc[0] + (loc[2] - loc[0]) / 2;
            double centerX = loc[1] + (loc[3] - loc[1]) / 2;

            int pixelX = (centerX * 300).toInt().clamp(0, 299);
            int pixelY = (centerY * 300).toInt().clamp(0, 299);

            final centerPixel = inputImage.getPixel(pixelX, pixelY);

            if (_isTennisBallColor(centerPixel)) {
              print("🎾 VALID TENNIS BALL: $label ($score)");
              results.add({
                'label': "Tennis Ball", // Rename it for UI
                'score': score,
                'rect': {
                  'y': loc[0],
                  'x': loc[1],
                  'h': loc[2] - loc[0],
                  'w': loc[3] - loc[1],
                }
              });
            } else {
              // print("🚫 Ignored $label - Wrong Color (R:${centerPixel.r} G:${centerPixel.g} B:${centerPixel.b})");
            }
          }
        }
      }
      return results;
    } catch (e) {
      print("❌ Inference error: $e");
      return [];
    } finally {
      _isBusy = false;
    }
  }

  // --- THE COLOR LOGIC ---
  bool _isTennisBallColor(img.Pixel pixel) {
    // Tennis ball = High Green + High Red + Low Blue (Yellowish)
    // White wall = High Green + High Red + High Blue (Ignored)
    // Grey floor = Low Green + Low Red + Low Blue (Ignored)

    num r = pixel.r;
    num g = pixel.g;
    num b = pixel.b;

    // 1. Must be bright enough (ignores dark shadows)
    if (g < 70) return false;

    // 2. Must be more Green than Blue (removes white/grey/blue objects)
    // We require a gap of at least 20.
    if (g < (b + 20)) return false;

    // 3. Must be more Red than Blue (removes green grass/leaves, keeps yellow)
    if (r < (b + 20)) return false;

    return true;
  }

  img.Image? _convertYUV420ToImage(CameraImage image) => null;
  void close() => _interpreter?.close();
}
