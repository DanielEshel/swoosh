//
//  CoreMLInference.swift
//  Runner
//
//  Created by Daniel Eshel on 13/04/2026.
//
import Foundation
import CoreML
import Vision

class CoreMLInference {
    private var visionModel: VNCoreMLModel?
    private var request: VNCoreMLRequest?
    
    // This closure passes the final coordinates back to the plugin
    var onDetectionCompleted: ((Double, Double, Double, Double, Double) -> Void)?

    init() {
        setupModel()
    }

    private func setupModel() {
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .all // Forces Apple Neural Engine (ANE)
                
                // Note the capital 'Y' in Yolo26n!
                // If this still throws an error, try YOLO26n or yolo26n based on what Xcode shows.
                // 2. Safely initialize it inside the check to silence the iOS 15 warning
                
                let coreMLModel: MLModel
                
                if #available(iOS 15.0, *) {
                    coreMLModel = try yolo26n(configuration: config).model
                } else {
                    // We just need this to satisfy the compiler
                    throw NSError(domain: "SwooshML", code: 1, userInfo: nil)
                }
                
                // Now this is in the same scope and can see coreMLModel
                visionModel = try VNCoreMLModel(for: coreMLModel)
                
                request = VNCoreMLRequest(model: visionModel!) { [weak self] request, error in
                    self?.processResults(for: request, error: error)
                }
                
                request?.imageCropAndScaleOption = .scaleFill
            } catch {
                print("📱 Swift: Failed to load Core ML model: \(error)")
            }
        }

    // Called by the camera 30 times a second
    func processFrame(_ pixelBuffer: CVPixelBuffer) {
        guard let request = request else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("📱 Swift: Vision request failed: \(error)")
        }
    }

    private func processResults(for request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNRecognizedObjectObservation],
              let topResult = results.first else {
            return
        }
        
        // 3. Filter by confidence (e.g., 35% sure it's a tennis ball)
        if topResult.confidence > 0.35 {
            let rect = topResult.boundingBox
            
            // Apple Vision coordinates start at bottom-left.
            // Flutter UI coordinates start at top-left. We must flip the Y axis.
            let flippedY = 1.0 - rect.origin.y - rect.size.height
            
            onDetectionCompleted?(
                Double(rect.origin.x),
                Double(flippedY),
                Double(rect.size.width),
                Double(rect.size.height),
                Double(topResult.confidence)
            )
        }
    }
}
