// lib/ml_stub.dart

class TFLiteManager {
  // --- SINGLETON PATTERN START ---
  static final TFLiteManager _instance = TFLiteManager._internal();

  factory TFLiteManager() {
    return _instance;
  }

  TFLiteManager._internal();

  static TFLiteManager get instance => _instance;
  // --- SINGLETON PATTERN END ---

  // The compiler needs these properties to exist
  bool get isBusy => false;
  bool get isLoaded => false;

  Future<void> loadModel() async {
    print("TFLite disabled on Web/Stub.");
  }

  // Helper to prevent crashes if code tries to call detect()
  Future<List<Map<String, dynamic>>> detect(dynamic image) async {
    return [];
  }

  void close() {}
}
