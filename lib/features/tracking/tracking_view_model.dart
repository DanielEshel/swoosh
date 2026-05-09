// lib/features/tracking/tracking_view_model.dart

double currentCameraFps = 0.0;
double currentModelFps = 0.0;

void handleDetection(BallDetection detection) {
  // Update the UI variables with the new metrics from Swift
  currentCameraFps = detection.cameraFps;
  currentModelFps = detection.modelFps;
  
  // Existing logic for shots and coordinates
  currentShotCount = detection.currentShotNumber;
  notifyListeners();
}