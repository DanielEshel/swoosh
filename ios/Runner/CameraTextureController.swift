import AVFoundation
import CoreVideo
import Flutter
import Foundation

// 1. Add this protocol so the plugin can listen for frames
protocol CameraFrameDelegate: AnyObject {
  func didCaptureFrame(pixelBuffer: CVPixelBuffer)
}

class CameraTextureController: NSObject, FlutterTexture,
  AVCaptureVideoDataOutputSampleBufferDelegate
{

  private let registry: FlutterTextureRegistry
  private var textureId: Int64 = 0
  private let captureSession = AVCaptureSession()

  private var latestPixelBuffer: CVPixelBuffer?

  // 2. Add the delegate property
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
    captureSession.sessionPreset = .hd1280x720

    // New Code
    // Try to get the Ultrawide camera first, fallback to the standard Wide camera if unavailable
    let deviceType: AVCaptureDevice.DeviceType = .builtInUltraWideCamera
    let fallbackType: AVCaptureDevice.DeviceType = .builtInWideAngleCamera

    guard
      let backCamera = AVCaptureDevice.default(deviceType, for: .video, position: .back)
        ?? AVCaptureDevice.default(fallbackType, for: .video, position: .back),
      let input = try? AVCaptureDeviceInput(device: backCamera)
    else {
      print("📱 Swift: Failed to access camera")
      return
    }

    if captureSession.canAddInput(input) {
      captureSession.addInput(input)
    }

    let videoOutput = AVCaptureVideoDataOutput()
    videoOutput.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
    ]
    videoOutput.alwaysDiscardsLateVideoFrames = true

    let cameraQueue = DispatchQueue(label: "camera_frame_queue", qos: .userInteractive)
    videoOutput.setSampleBufferDelegate(self, queue: cameraQueue)

    if captureSession.canAddOutput(videoOutput) {
      captureSession.addOutput(videoOutput)
    }

    if let connection = videoOutput.connection(with: .video) {
      if #available(iOS 17.0, *) {
        connection.videoRotationAngle = 90
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
  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

    latestPixelBuffer = pixelBuffer
    registry.textureFrameAvailable(textureId)

    // 3. Send the frame to the ML pipeline!
    frameDelegate?.didCaptureFrame(pixelBuffer: pixelBuffer)
  }

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    guard let pixelBuffer = latestPixelBuffer else { return nil }
    return Unmanaged.passRetained(pixelBuffer)
  }
}
