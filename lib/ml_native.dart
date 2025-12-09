import 'package:tflite_flutter/tflite_flutter.dart';

class TFLiteManager {
  Interpreter? _interpreter;

  bool get isLoaded => _interpreter != null;

  Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset('tennis_ball.tflite');
    print("TFLite model loaded.");
  }

  void close() {
    _interpreter?.close();
  }
}
