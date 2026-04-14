import Foundation
import CoreML
import Vision

class CoreMLInference {
    let visionModel: VNCoreMLModel

    init() throws {
        // 1. Configure the model to use the Neural Engine (ANE)
        let config = MLModelConfiguration()
        config.computeUnits = .all
        
        // 2. Load the auto-generated class for your new model.
        // Xcode usually capitalizes the filename, so "best.mlpackage" becomes "Best"
        let yolo = try best(configuration: config)
        
        // 3. Wrap it in a Vision model so we can feed it CVPixelBuffers directly
        self.visionModel = try VNCoreMLModel(for: yolo.model)
    }
}
