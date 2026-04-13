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
                    
                    // 2. Filter for ONLY tennis balls (labeled as "sports ball")
                    // and only those with a confidence higher than 40%
                    let tennisBallDetections = results.filter { observation in
                        let label = observation.labels.first?.identifier ?? ""
                        return label == "sports ball" && observation.confidence > 0.4
                    }

                    // 3. Find the "best" tennis ball in the frame
                    guard let bestBall = tennisBallDetections.max(by: { $0.confidence < $1.confidence }) else {
                        // If no tennis ball is found, tell Flutter to clear the old box
                        // (Sending a null or zeroed detection depending on your API)
                        return
                    }

                    // 4. Send ONLY this detection to Flutter
                    let bbox = bestBall.boundingBox
                    let detection = BallDetection(
                        x: Double(bbox.midX),
                        y: Double(1.0 - bbox.midY), // Keep the Y-flip for Flutter
                        width: Double(bbox.width),
                        height: Double(bbox.height),
                        confidence: Double(bestBall.confidence),
                        isKalmanPrediction: false
                    )

                    DispatchQueue.main.async {
                        self.detectionApi.onDetection(detection: detection) { _ in }
                    }
                    
                }
                
                request.imageCropAndScaleOption = .scaleFill
                let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
                try? handler.perform([request])
            }
        }
}
