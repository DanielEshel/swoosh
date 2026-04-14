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
    
    // NEW: Bluetooth Manager for the high-speed tracking loop
    private var bleController: BleServoController?
    
    init(messenger: FlutterBinaryMessenger, registry: FlutterTextureRegistry) {
        self.binaryMessenger = messenger
        self.registry = registry
        self.detectionApi = BallDetectionApi(binaryMessenger: messenger)
        
        super.init()
        
        // Initialize BLE Controller
        self.bleController = BleServoController(binaryMessenger: messenger)
        
        // Register the Pigeon HostApi so Flutter can call scanForDevices(), connectToDevice(), etc.
        if let controller = self.bleController {
            BleCommandApiSetup.setUp(binaryMessenger: messenger, api: controller)
        }
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
                
                // 2. Filter for ONLY tennis balls using your new model's labels
                // and only those with a confidence higher than 40%
                let tennisBallDetections = results.filter { observation in
                    let label = observation.labels.first?.identifier ?? ""
                    return (label == "tennis_ball" || label == "tennis ball") && observation.confidence > 0.4
                }

                // 3. Find the "best" tennis ball in the frame
                guard let bestBall = tennisBallDetections.max(by: { $0.confidence < $1.confidence }) else {
                    // If no tennis ball is found, tell Flutter to clear the old box
                    return
                }

                // --- THE NEW NATIVE TRACKING LOOP ---
                let bbox = bestBall.boundingBox
                
                // Map the X coordinate of the bounding box (0.0 to 1.0) to a servo angle (0 to 180 degrees)
                // Note: We use midX since Vision coordinates are normalized.
                // If the phone camera feed is mirrored, you might need to invert this mapping
                // by using: let targetAngle = 180 - Int(bbox.midX * 180.0)
                let centerX = bbox.midX
                let targetAngle = Int(centerX * 180.0)
                
                // Fire the command to the ESP32 natively (Zero Flutter latency)
                self.bleController?.sendServoCommand(angle: targetAngle)

                // 4. Send ONLY this detection to Flutter so the UI can draw the bounding box
                let detection = BallDetection(
                    x: Double(bbox.midX),
                    y: Double(1.0 - bbox.midY), // Keep the Y-flip for Flutter's coordinate system
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
