// Used on Web — tflite_flutter disabled

class TFLiteManager {
  bool get isLoaded => false;

  Future<void> loadModel() async {
    // Skip TFLite on Web
    print("TFLite disabled on Web.");
  }

  void close() {
    // nothing to close
  }
}
