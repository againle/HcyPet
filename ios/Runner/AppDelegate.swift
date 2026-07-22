import Flutter
import UIKit

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
                result(true) // iOS 26+ 原生 Vision 始终可用
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func startVision(result: @escaping FlutterResult) {
        visionDetector = VisionDetector()

        visionDetector?.onResult = { [weak self] emotion, confidence, isAttention, attentionScore in
            guard let self = self,
                  let controller = self.window?.rootViewController as? FlutterViewController else { return }

            let channel = FlutterMethodChannel(name: self.visionChannel, binaryMessenger: controller.binaryMessenger)
            channel.invokeMethod("onVisionResult", arguments: [
                "emotion": emotion,
                "confidence": confidence,
                "isAttention": isAttention,
                "attentionScore": attentionScore
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

