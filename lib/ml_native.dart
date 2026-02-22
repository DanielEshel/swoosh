import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:path_provider/path_provider.dart';

class TFLiteManager {
  static final TFLiteManager _instance = TFLiteManager._internal();
  factory TFLiteManager() => _instance;
  TFLiteManager._internal();
  static TFLiteManager get instance => _instance;

  ObjectDetector? _objectDetector;
  bool _isBusy = false;

  Future<void> loadModel() async {
    if (_objectDetector != null) return;

    try {
      // Pointing to your new 4D model location
      final localModelPath =
          await _copyAssetToLocal('assets/tracking/detect.tflite');

      final options = LocalObjectDetectorOptions(
        mode: DetectionMode.stream,
        modelPath: localModelPath,
        classifyObjects: true,
        multipleObjects:
            false, // Set to false to only track the highest confidence ball
        confidenceThreshold: 0.3,
      );

      _objectDetector = ObjectDetector(options: options);
      print("✅ ML Kit Object Detector Loaded from: $localModelPath");
    } catch (e) {
      print("❌ Error loading ML Kit model: $e");
    }
  }

  Future<String> _copyAssetToLocal(String assetPath) async {
    final path = await getApplicationDocumentsDirectory();
    final fileName = assetPath.split('/').last;
    final file = File('${path.path}/$fileName');

    // Always replace to ensure the new 4D model overwrites any older cached models
    if (await file.exists()) {
      await file.delete();
    }

    final byteData = await rootBundle.load(assetPath);
    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file.path;
  }

  Future<List<Map<String, dynamic>>> detect(
      CameraImage image, CameraDescription camera) async {
    if (_objectDetector == null || _isBusy) return [];
    _isBusy = true;

    try {
      final inputImage = _inputImageFromCameraImage(image, camera);
      if (inputImage == null) return [];

      final List<DetectedObject> objects =
          await _objectDetector!.processImage(inputImage);

      List<Map<String, dynamic>> results = [];

      // Compensate for camera rotation to fix bounding box alignment
      final isPortrait =
          camera.sensorOrientation == 90 || camera.sensorOrientation == 270;
      final imgW =
          isPortrait ? image.height.toDouble() : image.width.toDouble();
      final imgH =
          isPortrait ? image.width.toDouble() : image.height.toDouble();

      for (DetectedObject obj in objects) {
        final rect = obj.boundingBox;
        bool isBall = false;
        double confidence = 0.0;

        // Custom models sometimes don't return labels, or return index "0"
        if (obj.labels.isNotEmpty) {
          for (final l in obj.labels) {
            final text = l.text.toLowerCase();
            if (text.contains("ball") ||
                text.contains("tennis") ||
                text == "0") {
              isBall = true;
              confidence = l.confidence;
              break;
            }
          }
        } else {
          // Fallback: If your 4D model has no embedded labels, assume detection is a ball
          isBall = true;
          confidence = 1.0;
        }

        if (isBall) {
          results.add({
            'label': "Ball",
            'score': confidence,
            'rect': {
              'x': (rect.left / imgW).clamp(0.0, 1.0),
              'y': (rect.top / imgH).clamp(0.0, 1.0),
              'w': (rect.width / imgW).clamp(0.0, 1.0),
              'h': (rect.height / imgH).clamp(0.0, 1.0),
            }
          });
        }
      }

      // Sort by highest confidence
      results.sort(
          (a, b) => (b['score'] as double).compareTo(a['score'] as double));

      return results;
    } catch (e) {
      print("Error during detection: $e");
      return [];
    } finally {
      _isBusy = false;
    }
  }

  void dispose() {
    _objectDetector?.close();
    _objectDetector = null;
  }

  InputImage? _inputImageFromCameraImage(
      CameraImage image, CameraDescription camera) {
    // Android also requires the rotation to be set, otherwise ML Kit evaluates the image sideways
    final sensorOrientation = camera.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation) ??
        InputImageRotation.rotation0deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format ??
          (Platform.isIOS ? InputImageFormat.bgra8888 : InputImageFormat.nv21),
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }
}
