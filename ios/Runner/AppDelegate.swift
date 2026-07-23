import Flutter
import UIKit
import AVFoundation
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate {

    private let visionChannel = "com.hcypet.vision"
    private var visionDetector: VisionDetector?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        let channel = FlutterMethodChannel(name: visionChannel, binaryMessenger: controller.binaryMessenger)

        channel.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "startVision":
                self?.startVision(result: result)
            case "stopVision":
                self?.stopVision(result: result)
            case "isAvailable":
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func startVision(result: @escaping FlutterResult) {
        visionDetector = VisionDetector()

        // V3 新回调: (scene, focusScore, emotionJson, isStudying)
        visionDetector?.onResult = { [weak self] scene, focusScore, emotionJson, isStudying in
            guard let self = self,
                  let controller = self.window?.rootViewController as? FlutterViewController else { return }
            let channel = FlutterMethodChannel(name: self.visionChannel, binaryMessenger: controller.binaryMessenger)
            channel.invokeMethod("onVisionResult", arguments: [
                "scene": scene,
                "focusScore": focusScore,
                "emotionJson": emotionJson,
                "isStudying": isStudying
            ])
        }

        visionDetector?.onError = { [weak self] error in
            guard let self = self,
                  let controller = self.window?.rootViewController as? FlutterViewController else { return }
            let channel = FlutterMethodChannel(name: self.visionChannel, binaryMessenger: controller.binaryMessenger)
            channel.invokeMethod("onVisionError", arguments: error)
        }

        visionDetector?.start()
        result(true)
    }

    private func stopVision(result: @escaping FlutterResult) {
        visionDetector?.stop()
        visionDetector = nil
        result(true)
    }
}

