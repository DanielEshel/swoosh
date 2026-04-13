//
//  CameraTextureController.swift
//  Runner
//
//  Created by Daniel Eshel on 13/04/2026.
//
import Foundation
import AVFoundation
import Flutter
import CoreVideo

class CameraTextureController: NSObject, FlutterTexture, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private let registry: FlutterTextureRegistry
    private var textureId: Int64 = 0
    private let captureSession = AVCaptureSession()
    
    // This holds the most recent frame for Flutter to draw
    private var latestPixelBuffer: CVPixelBuffer?
    
    // We will pass frames to this closure so your ML model can process them
    var onFrameAvailable: ((CVPixelBuffer) -> Void)?

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
        captureSession.sessionPreset = .vga640x480 // Keeps resolution low for ML performance
        
        guard let backCamera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: backCamera) else {
            print("📱 Swift: Failed to access camera")
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        // BGRA format is what FlutterTexture expects natively
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        let cameraQueue = DispatchQueue(label: "camera_frame_queue", qos: .userInteractive)
        videoOutput.setSampleBufferDelegate(self, queue: cameraQueue)
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // Lock to portrait orientation for now to match UI
        if let connection = videoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                connection.videoRotationAngle = 90
            } else {
                // Fallback on earlier versions
            }
        }
        
        captureSession.commitConfiguration()
        
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }

    func stopCamera() {
        captureSession.stopRunning()
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    // This fires 30 times a second when the camera captures a frame
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // 1. Save the frame for Flutter to draw
        latestPixelBuffer = pixelBuffer
        registry.textureFrameAvailable(textureId)
        
        // 2. Fork the frame to our ML pipeline
        onFrameAvailable?(pixelBuffer)
    }

    // MARK: - FlutterTexture Protocol
    // Flutter's GPU thread calls this to pull the frame to the screen
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let pixelBuffer = latestPixelBuffer else { return nil }
        return Unmanaged.passRetained(pixelBuffer)
    }
}
