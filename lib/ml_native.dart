import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteManager {
  static final TFLiteManager _instance = TFLiteManager._internal();
  factory TFLiteManager() => _instance;
  TFLiteManager._internal();
  static TFLiteManager get instance => _instance;

  Interpreter? _interpreter;
  bool _isBusy = false;

  // Re-added to fix your build errors
  String lastStatus = "Initializing...";
  static final ValueNotifier<String> status =
      ValueNotifier<String>("Initializing...");

  // Pre-allocated 448p buffer
  late Float32List _inputBuffer;

  Future<void> loadModel() async {
    if (_interpreter != null) return;
    try {
      final options = InterpreterOptions()..threads = 4;
      _interpreter = await Interpreter.fromAsset(
        'assets/tracking/detect.tflite',
        options: options,
      );

      // Even if your model was trained at 640, we will resize the tensors to 448
      // to force the speed boost.
      _interpreter!.resizeInputTensor(0, [1, 448, 448, 3]);
      _interpreter!.allocateTensors();

      _inputBuffer = Float32List(1 * 448 * 448 * 3);
      _updateStatus("448p Engine Ready 🚀");
    } catch (e) {
      _updateStatus("Load Error: $e");
    }
  }

  void _updateStatus(String msg) {
    lastStatus = msg;
    status.value = msg;
  }

  Future<List<Map<String, dynamic>>> detect(CameraImage image) async {
    if (_interpreter == null || _isBusy) return [];
    _isBusy = true;

    try {
      // 1. DIRECT 448p SAMPLING
      // We read a 448x448 square from the center of your 1080p feed
      _sample448pFromYUV(image);

      var input = _inputBuffer.reshape([1, 448, 448, 3]);
      var output = List.filled(1 * 5 * 8400, 0.0).reshape([1, 5, 8400]);

      _interpreter!.run(input, output);

      List<Map<String, dynamic>> detections = [];
      double topScore = 0.0;

      for (int i = 0; i < 8400; i++) {
        double score = output[0][4][i];
        if (score > topScore) topScore = score;

        // Requirement: 80% confidence
        if (score > 0.80) {
          detections.add({
            'score': score,
            'rect': {
              'x': (output[0][0][i] - output[0][2][i] / 2).clamp(0.0, 1.0),
              'y': (output[0][1][i] - output[0][3][i] / 2).clamp(0.0, 1.0),
              'w': output[0][2][i].clamp(0.0, 1.0),
              'h': output[0][3][i].clamp(0.0, 1.0),
            }
          });
        }
      }

      _updateStatus("AI @ 448p | Top: ${(topScore * 100).toStringAsFixed(1)}%");

      if (detections.isNotEmpty) {
        detections.sort((a, b) => (b['score'] as double).compareTo(a['score']));
        return [detections.first];
      }
      return [];
    } catch (e) {
      return [];
    } finally {
      _isBusy = false;
    }
  }

  void _sample448pFromYUV(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final yPlane = image.planes[0].bytes;
    final uPlane = image.planes[1].bytes;
    final vPlane = image.planes[2].bytes;

    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;

    // Calculate center crop offsets
    int size = (height < width) ? height : width;
    int offsetX = (width - size) ~/ 2;
    int offsetY = (height - size) ~/ 2;

    int bufferIndex = 0;
    for (int y = 0; y < 448; y++) {
      int py = offsetY + (y * size ~/ 448);
      for (int x = 0; x < 448; x++) {
        int px = offsetX + (x * size ~/ 448);

        int yIdx = py * width + px;
        int uvIdx = (py ~/ 2) * uvRowStride + (px ~/ 2) * uvPixelStride;

        int yp = yPlane[yIdx];
        int up = uPlane[uvIdx];
        int vp = vPlane[uvIdx];

        // R, G, B normalization in one pass
        _inputBuffer[bufferIndex++] =
            (yp + 1.402 * (vp - 128)).clamp(0, 255) / 255.0;
        _inputBuffer[bufferIndex++] =
            (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).clamp(0, 255) /
                255.0;
        _inputBuffer[bufferIndex++] =
            (yp + 1.772 * (up - 128)).clamp(0, 255) / 255.0;
      }
    }
  }
}
