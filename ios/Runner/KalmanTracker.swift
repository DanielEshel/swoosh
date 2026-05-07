//
//  KalmanTracker.swift
//  Runner
//
//  Created by Daniel Eshel on 07/05/2026.
//


import Foundation

class KalmanTracker {
    // State variables
    // We assume the servo starts at 90 degrees (facing forward)
    var currentCameraAngle: Double = 90.0 
    private var velocity: Double = 0.0 // Degrees per second
    
    // Kalman tuning parameters
    private var processNoise: Double = 1.0     // Q: How much we trust our physics model
    private var measurementNoise: Double = 5.0 // R: How much we trust YOLO (higher = smooth but slow)
    private var estimateError: Double = 1.0    // P: Initial uncertainty
    
    private var lastTimestamp: TimeInterval = 0
    
    // MAGIC NUMBER: Degrees per pixel. 
    // You will need to tune this based on your Ultrawide camera's Field of View.
    // Example: 120-degree FOV divided by a 640px YOLO frame = ~0.18 degrees per pixel
    var degreesPerPixel: Double = 0.18
    
    /// Updates the tracker and returns the PREDICTED future angle for the servo
    /// - Parameters:
    ///   - pixelOffset: X offset from the center of the YOLO frame (negative for left, positive for right)
    ///   - currentTime: Current system time
    ///   - systemDelayMs: Total estimated lag of your system (Bluetooth + Servo turning speed)
    func updateAndPredict(pixelOffset: Double, currentTime: TimeInterval, systemDelayMs: Double) -> Int {
        
        // 1. Convert pixel offset to an absolute real-world angle
        let measuredAngle = currentCameraAngle + (pixelOffset * degreesPerPixel)
        
        // Initialization for the very first frame
        if lastTimestamp == 0 {
            lastTimestamp = currentTime
            currentCameraAngle = measuredAngle
            return Int(currentCameraAngle)
        }
        
        let dt = currentTime - lastTimestamp
        lastTimestamp = currentTime
        
        // --- KALMAN PREDICT STEP ---
        // Where do we expect the ball to be based on its momentum?
        let predictedAngle = currentCameraAngle + (velocity * dt)
        let predictedError = estimateError + processNoise
        
        // --- KALMAN UPDATE STEP ---
        // Calculate Kalman Gain (Do we trust our momentum prediction, or the new YOLO measurement more?)
        let kalmanGain = predictedError / (predictedError + measurementNoise)
        
        // Update our official state
        currentCameraAngle = predictedAngle + kalmanGain * (measuredAngle - predictedAngle)
        
        // Update our velocity (degrees per second)
        velocity = (currentCameraAngle - predictedAngle) / dt
        
        // Update the error covariance for the next frame
        estimateError = (1 - kalmanGain) * predictedError
        
        // --- PREDICTION (Defeating the Lag) ---
        // Look into the future by your system delay amount
        let delaySeconds = systemDelayMs / 1000.0
        let futureAngle = currentCameraAngle + (velocity * delaySeconds)
        
        return clamp(angle: Int(futureAngle))
    }
    
    // Keep the servo within safe 360 bounds
    private func clamp(angle: Int) -> Int {
        if angle < 0 { return 0 }
        if angle > 360 { return 360 }
        return angle
    }
    
    // Call this if the ball is lost for more than 1-2 seconds
    func reset() {
        velocity = 0.0
        lastTimestamp = 0
    }
}
