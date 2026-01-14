// lib/ml_stub.dart

class TFLiteManager {
  // The compiler needs this property to exist, even if it's always false on Web
  bool get isBusy => false;
  bool get isLoaded => false;

  Future<void> loadModel() async {
    print("TFLite disabled on Web (stub).");
  }

  // Helper to prevent crashes if code tries to call detect() on Web
  Future<List<Map<String, dynamic>>> detect(dynamic image) async {
    return [];
  }

  void close() {}
}
