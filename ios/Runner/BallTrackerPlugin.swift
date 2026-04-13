import Foundation
import Flutter
extension FlutterError: Swift.Error {}
class BallTrackerPlugin: NSObject, BallTrackerApi {
    private var binaryMessenger: FlutterBinaryMessenger
    private var detectionApi: BallDetectionApi
    private var cameraController: CameraTextureController?
    private var registry: FlutterTextureRegistry
    private var inferenceEngine: CoreMLInference?
    
    init(messenger: FlutterBinaryMessenger, registry: FlutterTextureRegistry) {
        self.binaryMessenger = messenger
        self.registry = registry
        self.detectionApi = BallDetectionApi(binaryMessenger: messenger)
        super.init()
    }
    
    func startTracking(config: TrackingConfig, completion: @escaping (Result<Int64, Error>) -> Void) {
        print("📱 Swift: Starting camera natively...")
        
        if cameraController == nil {
            cameraController = CameraTextureController(registry: self.registry)
        }
        
        // 1. Initialize the ML Engine
        if inferenceEngine == nil {
            inferenceEngine = CoreMLInference()
            
            // 2. When ML finds a ball, send it across Pigeon to Dart
            inferenceEngine?.onDetectionCompleted = { [weak self] x, y, w, h, conf in
                self?.sendDetectionToFlutter(x: x, y: y, w: w, h: h, conf: conf)
            }
        }
        
        // 3. When the camera captures a frame, hand it to the ML Engine
        cameraController?.onFrameAvailable = { [weak self] pixelBuffer in
            self?.inferenceEngine?.processFrame(pixelBuffer)
        }
        
        cameraController?.startCamera()
        
        if let textureId = cameraController?.getTextureId() {
            completion(.success(textureId))
        } else {
            completion(.success(0))
        }
    }
    
    func stopTracking() throws {
        print("📱 Swift: Stopping camera...")
        cameraController?.stopCamera()
    }
    
    func sendDetectionToFlutter(x: Double, y: Double, w: Double, h: Double, conf: Double) {
        let detection = BallDetection(x: x, y: y, width: w, height: h, confidence: conf, isKalmanPrediction: false)
        detectionApi.onDetection(detection: detection) { _ in }
    }
}
