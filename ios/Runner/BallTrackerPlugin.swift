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
    
    // Memory of the servo's physical angle for smooth tracking
    private var currentPanAngle: Double = 90.0
    
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
        do {
            mlInference = try CoreMLInference()
        } catch {
            print("📱 Swift: Failed to load ML Model: \(error)")
        }
        
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
        cameraController?.stopCamera()
        cameraController?.frameDelegate = nil
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
                let centerX = bbox.midX
                
                // --- PROPORTIONAL TRACKING LOGIC ---
                // Calculate distance from center (0.5 is dead center)
                let error = centerX - 0.5
                
                // Create a 10% deadzone in the middle so it doesn't vibrate when perfectly aimed
                if abs(error) > 0.05 {
                    
                    // Convert error into a smooth rotation. 8.0 = max 4 degrees of movement per frame.
                    let delta = error * 8.0
                    
                    // Note: If the servo turns the WRONG way (runs away from the ball), change += to -=
                    self.currentPanAngle -= delta
                    
                    // Safety clamp between 0 and 180 degrees
                    self.currentPanAngle = max(0, min(180, self.currentPanAngle))
                    
                    // Format the angle as a clean string ("95") and send it
                    let commandString = String(Int(self.currentPanAngle))
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
