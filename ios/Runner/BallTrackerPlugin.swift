import Foundation
import Flutter
import Vision
import CoreVideo

extension FlutterError: Swift.Error {}

// Add CameraFrameDelegate to the class inheritance
class BallTrackerPlugin: NSObject, BallTrackerApi, CameraFrameDelegate {
    private var binaryMessenger: FlutterBinaryMessenger
    private var detectionApi: BallDetectionApi
    private var cameraController: CameraTextureController?
    private var registry: FlutterTextureRegistry
    
    // ML Properties
    private var mlInference: CoreMLInference?
    private var isProcessingFrame = false
    private let inferenceQueue = DispatchQueue(label: "com.swoosh.inference", qos: .userInitiated)
    
    init(messenger: FlutterBinaryMessenger, registry: FlutterTextureRegistry) {
        self.binaryMessenger = messenger
        self.registry = registry
        self.detectionApi = BallDetectionApi(binaryMessenger: messenger)
        super.init()
    }
    
    func startTracking(config: TrackingConfig, completion: @escaping (Result<Int64, Error>) -> Void) {
        print("📱 Swift: Starting native camera and ML pipeline...")
        
        // 1. Initialize the ML Model
        do {
            mlInference = try CoreMLInference()
            print("📱 Swift: YOLO CoreML Model loaded successfully.")
        } catch {
            print("📱 Swift: Failed to load ML Model: \(error)")
        }
        
        // 2. Start Camera and set delegate
        if cameraController == nil {
            cameraController = CameraTextureController(registry: self.registry)
            cameraController?.frameDelegate = self
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
        cameraController?.frameDelegate = nil
    }
    
    // MARK: - CameraFrameDelegate
    
    // MARK: - CameraFrameDelegate
        func didCaptureFrame(pixelBuffer: CVPixelBuffer) {
            guard let ml = mlInference, !isProcessingFrame else { return }
            
            inferenceQueue.async { [weak self] in
                guard let self = self else { return }
                self.isProcessingFrame = true
                
                let request = VNCoreMLRequest(model: ml.visionModel) { request, error in
                    defer { self.isProcessingFrame = false }
                    
                    if let error = error {
                        print("📱 Swift ML Error: \(error.localizedDescription)")
                        return
                    }
                    
                    // Now that the model has NMS, results will be VNRecognizedObjectObservation
                    guard let results = request.results as? [VNRecognizedObjectObservation] else {
                        return
                    }
                    
                    if results.isEmpty { return }
                    
                    // Get the detection with the highest confidence
                    guard let bestDetection = results.max(by: { $0.confidence < $1.confidence }) else { return }
                    
                    // Standard labels: YOLO usually calls a tennis ball 'sports ball'
                    // but we will print it to be sure.
                    let label = bestDetection.labels.first?.identifier ?? "unknown"
                    let conf = bestDetection.confidence
                    
                    print("📱 Swift ML: Detected [\(label)] at \(Int(conf * 100))% confidence")
                    
                    // Send to Flutter if it's likely a ball (confidence > 30%)
                    if conf > 0.3 {
                        let bbox = bestDetection.boundingBox
                        // Convert Vision (bottom-left) to Flutter (top-left) coordinates
                        let x = Double(bbox.midX)
                        let y = Double(1.0 - bbox.midY)
                        
                        let detection = BallDetection(
                            x: x, y: y,
                            width: Double(bbox.width),
                            height: Double(bbox.height),
                            confidence: Double(conf),
                            isKalmanPrediction: false
                        )
                        
                        DispatchQueue.main.async {
                            self.detectionApi.onDetection(detection: detection) { _ in }
                        }
                    }
                }
                
                request.imageCropAndScaleOption = .scaleFill
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                try? handler.perform([request])
            }
        }
}
