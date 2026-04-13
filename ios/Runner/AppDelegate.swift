import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
      
    // 1. Register standard Flutter plugins first
    GeneratedPluginRegistrant.register(with: self)
      
    // 2. Ask Flutter for a safe "registrar" for your custom plugin
    // This gives us safe access to the messenger and texture registry
    let registrar = self.registrar(forPlugin: "BallTrackerPlugin")!
    
    // 3. Initialize your plugin using the registrar
    let trackerPlugin = BallTrackerPlugin(
        messenger: registrar.messenger(),
        registry: registrar.textures()
    )
      
    // 4. Connect your Pigeon API
    BallTrackerApiSetup.setUp(
        binaryMessenger: registrar.messenger(),
        api: trackerPlugin
    )
      
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
