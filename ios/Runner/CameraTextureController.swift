import Foundation
import AVFoundation
import Flutter
import CoreVideo

// 1. Updated protocol to include cameraFps
protocol CameraFrameDelegate: AnyObject {
    func didCaptureFrame(pixelBuffer: CVPixelBuffer, cameraFps: Double)
}

class CameraTextureController: NSObject, FlutterTexture, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private let registry: FlutterTextureRegistry
    private var textureId: Int64 = 0
    private let captureSession = AVCaptureSession()
    private var latestPixelBuffer: CVPixelBuffer?

    // FIX: Added the missing captureDevice variable
    private var captureDevice: AVCaptureDevice?

    // FPS calculation properties
    private var frameCount = 0
    private var lastFpsTimestamp = CACurrentMediaTime()
    private var currentCameraFps: Double = 0.0
    var onFpsUpdate: ((Double) -> Void)?
    
    weak var frameDelegate: CameraFrameDelegate?

    init(registry: FlutterTextureRegistry) {
        self.registry = registry
        super.init()
        self.textureId = self.registry.register(self)
    }
    
    func getTextureId() -> Int64 {
        return textureId
    }

    func startCamera() {
        captureSession.beginConfiguration()
        
        // 1. Prioritize Ultrawide Camera
        if let ultraWideDevice = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
            self.captureDevice = ultraWideDevice
            print("📱 Swift: Using Ultrawide Lens")
        } else {
            self.captureDevice = AVCaptureDevice.default(for: .video)
            print("📱 Swift: Ultrawide not found, using Standard Lens")
        }
        
        captureSession.sessionPreset = .vga640x480
        
        // FIX: Replaced hardcoded default camera with our selected captureDevice
        guard let activeDevice = self.captureDevice,
              let input = try? AVCaptureDeviceInput(device: activeDevice) else {
            print("📱 Swift: Failed to access camera")
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        let cameraQueue = DispatchQueue(label: "camera_frame_queue", qos: .userInteractive)
        videoOutput.setSampleBufferDelegate(self, queue: cameraQueue)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // PRESERVED: iOS 17 Rotation Fix
        if let connection = videoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                connection.videoRotationAngle = 90
            }
        }
        
        // PRESERVED: 60 FPS LOCK LOGIC
        do {
            try activeDevice.lockForConfiguration()
            
            var bestFormat: AVCaptureDevice.Format?
            for format in activeDevice.formats {
                let ranges = format.videoSupportedFrameRateRanges
                if ranges.contains(where: { $0.maxFrameRate >= 60.0 }) {
                    bestFormat = format
                    break 
                }
            }
            
            if let format = bestFormat {
                activeDevice.activeFormat = format
                activeDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 60)
                activeDevice.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 60)
                print("📱 Swift: Successfully locked camera to 60 FPS")
            } else {
                print("📱 Swift: 60 FPS not supported on this device/lens, falling back to default")
            }
            
            activeDevice.unlockForConfiguration()
        } catch {
            print("📱 Swift: Error locking camera configuration: \(error)")
        }
        
        captureSession.commitConfiguration()
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }

    func stopCamera() {
        captureSession.stopRunning()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // FPS Calculation
        frameCount += 1
        let now = CACurrentMediaTime()
        if now - lastFpsTimestamp >= 1.0 {
            currentCameraFps = Double(frameCount) / (now - lastFpsTimestamp)
            onFpsUpdate?(currentCameraFps)
            frameCount = 0
            lastFpsTimestamp = now
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        latestPixelBuffer = pixelBuffer
        registry.textureFrameAvailable(textureId)
        
        // FIX: Passing the cameraFps to the plugin
        frameDelegate?.didCaptureFrame(pixelBuffer: pixelBuffer, cameraFps: currentCameraFps)
    }

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let pixelBuffer = latestPixelBuffer else { return nil }
        return Unmanaged.passRetained(pixelBuffer)
    }
}