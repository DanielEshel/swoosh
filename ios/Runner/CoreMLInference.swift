import Foundation
import CoreML
import Vision

class CoreMLInference {
    let visionModel: VNCoreMLModel

    init() throws {
        // 1. Configure the model to use the Neural Engine (ANE)
        let config = MLModelConfiguration()
        config.computeUnits = .all
        
        // 2. Load the auto-generated YOLO class.
        // (If Xcode complains here, check if the auto-generated class is capitalized as 'Yolo26n')
        let yolo = try yolo26n(configuration: config)
        
        // 3. Wrap it in a Vision model so we can feed it CVPixelBuffers directly
        self.visionModel = try VNCoreMLModel(for: yolo.model)
    }
}
