class TFLiteManager {
  static final TFLiteManager _instance = TFLiteManager._internal();

  factory TFLiteManager() {
    return _instance;
  }

  TFLiteManager._internal();

  static TFLiteManager get instance => _instance;

  bool get isBusy => false;
  bool get isLoaded => false;

  Future<void> loadModel() async {
    print("ML disabled on Web/Stub.");
  }

  // Signature updated to match ml_native.dart
  Future<List<Map<String, dynamic>>> detect(
      dynamic image, dynamic camera) async {
    return [];
  }

  void dispose() {}
  void close() {}
}
