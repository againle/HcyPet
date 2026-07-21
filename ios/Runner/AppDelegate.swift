import Flutter
import UIKit
import AVFoundation
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FaceDetectorPlugin.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "FaceDetectorPlugin"))
  }
}

// MARK: - FaceDetectorPlugin (iOS Vision 框架，零外部依赖)

class FaceDetectorPlugin: NSObject, FlutterPlugin {
    private var sequenceHandler = VNSequenceRequestHandler()
    private var latestResult: [String: Any] = [:]

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.hcypet/face_detector",
            binaryMessenger: registrar.messenger()
        )
        let instance = FaceDetectorPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "detectFace":
            guard let args = call.arguments as? [String: Any],
                  let imageData = args["imageData"] as? FlutterStandardTypedData,
                  let width = args["width"] as? Int,
                  let height = args["height"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil))
                return
            }
            detectFace(imageData: imageData.data, width: width, height: height, result: result)
        case "getLatest":
            result(latestResult.isEmpty ? nil : latestResult)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func detectFace(imageData: Data, width: Int, height: Int, result: @escaping FlutterResult) {
        guard let cgImage = createCGImage(from: imageData, width: width, height: height) else {
            result(latestResult)
            return
        }

        let rectRequest = VNDetectFaceRectanglesRequest { [weak self] request, _ in
            guard let faces = request.results as? [VNFaceObservation], let face = faces.first else {
                let r: [String: Any] = ["hasFace": false]
                self?.latestResult = r
                DispatchQueue.main.async { result(r) }
                return
            }
            let faceResult: [String: Any] = [
                "hasFace": true,
                "confidence": face.confidence as Any,
                "yaw": face.yaw?.doubleValue ?? 0,
                "pitch": face.pitch?.doubleValue ?? 0,
                "roll": face.roll?.doubleValue ?? 0
            ]
            self?.latestResult = faceResult
            DispatchQueue.main.async { result(faceResult) }
        }

        let landmarkRequest = VNDetectFaceLandmarksRequest { [weak self] request, _ in
            guard let faces = request.results as? [VNFaceObservation],
                  let face = faces.first,
                  let landmarks = face.landmarks else { return }
            let smile = self?.calcSmile(landmarks) ?? 0
            let leftEye = self?.calcEyeOpen(landmarks.leftEye) ?? 0.5
            let rightEye = self?.calcEyeOpen(landmarks.rightEye) ?? 0.5
            var r = self?.latestResult ?? [:]
            r["smileScore"] = smile
            r["leftEyeOpen"] = leftEye
            r["rightEyeOpen"] = rightEye
            r["emotion"] = smile > 0.5 ? "happy" : "neutral"
            self?.latestResult = r
        }

        do {
            try sequenceHandler.perform([rectRequest], on: cgImage)
            try sequenceHandler.perform([landmarkRequest], on: cgImage)
        } catch {
            DispatchQueue.main.async { result(self.latestResult) }
        }
    }

    private func createCGImage(from data: Data, width: Int, height: Int) -> CGImage? {
        let bytesPerRow = width * 4
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            width: width, height: height,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil,
            shouldInterpolate: true, intent: .defaultIntent)
    }

    private func calcSmile(_ landmarks: VNFaceLandmarks2D) -> Double {
        guard let outer = landmarks.outerLips else { return 0 }
        let pts = outer.normalizedPoints; guard pts.count >= 4 else { return 0 }
        let w = hypot(pts.last!.x - pts.first!.x, pts.last!.y - pts.first!.y)
        let h = hypot(pts[pts.count*2/3].x - pts[pts.count/3].x, pts[pts.count*2/3].y - pts[pts.count/3].y)
        return min(max((w / max(h, 0.01) - 1.5) / 3.0, 0), 1.0)
    }

    private func calcEyeOpen(_ eye: VNFaceLandmarkRegion2D?) -> Double {
        guard let e = eye else { return 0.5 }
        let pts = e.normalizedPoints; guard pts.count >= 4 else { return 0.5 }
        let h = hypot(pts[1].x - pts[3].x, pts[1].y - pts[3].y)
        let w = hypot(pts[0].x - pts[2].x, pts[0].y - pts[2].y)
        return min(max(h / max(w, 0.01) * 0.4, 0), 1.0)
    }
}
