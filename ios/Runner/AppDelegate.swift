import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var ringtoneManager: RingtoneManager?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let ringtoneChannel = FlutterMethodChannel(
      name: "com.livekitCalling.app/ringtone",
      binaryMessenger: controller.binaryMessenger)

    ringtoneManager = RingtoneManager()

    ringtoneChannel.setMethodCallHandler {
      (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "playRingtone":
        self.ringtoneManager?.playRingtone()
        result(nil)
      case "stopRingtone":
        self.ringtoneManager?.stopRingtone()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
