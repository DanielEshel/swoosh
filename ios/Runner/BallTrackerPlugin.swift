import Foundation
import Flutter
import Vision
import CoreVideo
import AVFoundation

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

    // Video Recording Properties
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var isRecording = false
    private var recordingStartTime: CMTime?
    
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
        print("📱 Swift: Initializing Tracker resources...")
        
        if mlInference == nil {
            do {
                mlInference = try CoreMLInference()
            } catch {
                completion(.failure(error))
                return
            }
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
        print("📱 Swift: Disposing Tracker resources...")
        cameraController?.stopCamera()
        cameraController?.frameDelegate = nil
        cameraController = nil
        mlInference = nil
        isRecording = false
    }

    // --- Recording Interface ---
    
        
        func startRecording() throws {
            let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("swoosh_capture.mp4")
            try? FileManager.default.removeItem(at: outputURL)

            guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else { return }
            
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 720,
                AVVideoHeightKey: 1280
            ]
            
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            input.expectsMediaDataInRealTime = true
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
            
            if writer.canAdd(input) {
                writer.add(input)
                writer.startWriting()
                self.assetWriter = writer
                self.assetWriterInput = input
                self.pixelBufferAdaptor = adaptor
                self.isRecording = true
                self.recordingStartTime = nil
            }
        }

        // Pigeon @async methods require a completion handler with a Result type
        func stopRecording(completion: @escaping (Result<String, Error>) -> Void) {
            isRecording = false
            assetWriterInput?.markAsFinished()
            assetWriter?.finishWriting {
                let path = self.assetWriter?.outputURL.path ?? ""
                completion(.success(path))
            }
        }
    
    func didCaptureFrame(pixelBuffer: CVPixelBuffer) {
        let currentTime = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 600)
        
        // 1. Record Frame if active
        if isRecording, let adaptor = pixelBufferAdaptor, assetWriterInput?.isReadyForMoreMediaData == true {
            if recordingStartTime == nil {
                recordingStartTime = currentTime
                assetWriter?.startSession(atSourceTime: currentTime)
            }
            adaptor.append(pixelBuffer, withPresentationTime: currentTime)
        }

        // 2. Process ML Inference
        guard let ml = mlInference, !isProcessingFrame else { return }
        
        inferenceQueue.async { [weak self] in
            guard let self = self else { return }
            self.isProcessingFrame = true
            
            let request = VNCoreMLRequest(model: ml.visionModel) { request, error in
                defer { self.isProcessingFrame = false }
                guard let results = request.results as? [VNRecognizedObjectObservation] else { return }
                
                let tennisBallDetections = results.filter { observation in
                    let label = observation.labels.first?.identifier ?? ""
                    return (label.contains("ball")) && observation.confidence > 0.5
                }

                if let bestBall = tennisBallDetections.max(by: { $0.confidence < $1.confidence }) {
                    let bbox = bestBall.boundingBox
                    let centerX = bbox.midX
                    
                    // --- ESP32 RELATIVE LOGIC ---
                    let relativeError = centerX - 0.5
                    
                    // no Deadzone check
                    if abs(relativeError) >= 0 {
                        let commandString = String(format: "%.2f", relativeError)
                        self.bleController?.sendServoCommand(command: commandString)
                    }

                    // Send UI Update to Flutter
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
            }
            
            request.imageCropAndScaleOption = .scaleFill
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            try? handler.perform([request])
        }
    }
}
