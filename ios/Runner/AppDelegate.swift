import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    
    // Pass 'controller' as the registry since FlutterViewController conforms to it
    let trackerPlugin = BallTrackerPlugin(messenger: controller.binaryMessenger, registry: controller)
      
    BallTrackerApiSetup.setUp(binaryMessenger: controller.binaryMessenger, api: trackerPlugin)
      
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
