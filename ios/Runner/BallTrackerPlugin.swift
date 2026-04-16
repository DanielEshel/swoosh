import Foundation
import Flutter
import Vision
import CoreVideo

extension FlutterError: Swift.Error {}

class BallTrackerPlugin: NSObject, BallTrackerApi, CameraFrameDelegate {
    private var binaryMessenger: FlutterBinaryMessenger
    private var detectionApi: BallDetectionApi
    private var cameraController: CameraTextureController?
    private var registry: FlutterTextureRegistry
    
    private var mlInference: CoreMLInference?
    private var isProcessingFrame = false
    private let inferenceQueue = DispatchQueue(label: "com.swoosh.inference", qos: .userInitiated)
    
    private var bleController: BleServoController?
    
    
    init(messenger: FlutterBinaryMessenger, registry: FlutterTextureRegistry) {
        self.binaryMessenger = messenger
        self.registry = registry
        self.detectionApi = BallDetectionApi(binaryMessenger: messenger)
        super.init()
        
        self.bleController = BleServoController(binaryMessenger: messenger)
        
        if let controller = self.bleController {
            BleCommandApiSetup.setUp(binaryMessenger: messenger, api: controller)
        }
    }
    
    func startTracking(config: TrackingConfig, completion: @escaping (Result<Int64, Error>) -> Void) {
        print("📱 Swift: Starting native camera and ML pipeline...")
        
        // Only load the model if it's not already loaded to save memory/time
        if mlInference == nil {
            do {
                mlInference = try CoreMLInference()
            } catch {
                print("📱 Swift: Failed to load ML Model: \(error)")
                completion(.failure(error))
                return
            }
        }
        
        // Re-initialize camera controller if it was previously nil-ed out
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
        print("📱 Swift: Stopping tracking and releasing resources...")
        cameraController?.stopCamera()
        cameraController?.frameDelegate = nil
        
        // CRITICAL: Release the heavy objects to prevent memory accumulation
        cameraController = nil
        mlInference = nil
    }
    
    func didCaptureFrame(pixelBuffer: CVPixelBuffer) {
        guard let ml = mlInference, !isProcessingFrame else { return }
        
        inferenceQueue.async { [weak self] in
            guard let self = self else { return }
            self.isProcessingFrame = true
            
            let request = VNCoreMLRequest(model: ml.visionModel) { request, error in
                defer { self.isProcessingFrame = false }
                
                guard let results = request.results as? [VNRecognizedObjectObservation] else { return }
                
                let tennisBallDetections = results.filter { observation in
                    let label = observation.labels.first?.identifier ?? ""
                    // I included multiple common YOLO ball labels just in case
                    return (label == "tennis_ball" || label == "tennis ball" || label == "sports ball") && observation.confidence > 0.5
                }

                guard let bestBall = tennisBallDetections.max(by: { $0.confidence < $1.confidence }) else { return }

                let bbox = bestBall.boundingBox
                let centerX = bbox.midX // normalized 0.0 to 1.0

                // Calculate relative error:
                // -0.5 (left edge), 0 (center), 0.5 (right edge)
                let relativeError = centerX - 0.5

                // Only send command if outside a 10% deadzone to save BLE bandwidth
                if abs(relativeError) > 0.05 {
                    // The ESP32 will parse this and decide how many degrees to move
                    let commandString = String(format: "%.2f", relativeError)
                    self.bleController?.sendServoCommand(command: commandString)
                }

                let detection = BallDetection(
                    x: Double(bbox.midX),
                    y: Double(1.0 - bbox.midY),
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
