import AVFoundation
import Vision
import Flutter

/// iOS 原生人脸检测 — 使用 Apple Vision 框架，零外部依赖
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

        let request = VNDetectFaceRectanglesRequest { [weak self] request, error in
            guard let observations = request.results as? [VNFaceObservation] else {
                DispatchQueue.main.async { result(self?.latestResult) }
                return
            }

            if let face = observations.first {
                let faceResult: [String: Any] = [
                    "hasFace": true,
                    "confidence": face.confidence,
                    "boundingBox": [
                        "x": face.boundingBox.origin.x,
                        "y": face.boundingBox.origin.y,
                        "width": face.boundingBox.size.width,
                        "height": face.boundingBox.size.height
                    ],
                    "roll": face.roll?.doubleValue ?? 0,
                    "yaw": face.yaw?.doubleValue ?? 0,
                    "pitch": face.pitch?.doubleValue ?? 0
                ]
                self?.latestResult = faceResult
                DispatchQueue.main.async { result(faceResult) }
            } else {
                let noFaceResult: [String: Any] = ["hasFace": false]
                self?.latestResult = noFaceResult
                DispatchQueue.main.async { result(noFaceResult) }
            }
        }

        // 进行 landmarks 检测以获得更多表情信息
        let landmarkRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let observations = request.results as? [VNFaceObservation],
                  let face = observations.first,
                  let landmarks = face.landmarks else { return }

            // 通过 landmarks 推断表情
            let smileScore = self?.calculateSmileScore(from: landmarks) ?? 0
            let leftEyeOpen = self?.calculateEyeOpenness(landmarks.leftEye) ?? 0.5
            let rightEyeOpen = self?.calculateEyeOpenness(landmarks.rightEye) ?? 0.5

            var updatedResult = self?.latestResult ?? [:]
            updatedResult["smileScore"] = smileScore
            updatedResult["leftEyeOpen"] = leftEyeOpen
            updatedResult["rightEyeOpen"] = rightEyeOpen
            updatedResult["emotion"] = smileScore > 0.5 ? "happy" : "neutral"
            self?.latestResult = updatedResult
        }

        do {
            try sequenceHandler.perform([request], on: cgImage)
            try sequenceHandler.perform([landmarkRequest], on: cgImage)
        } catch {
            DispatchQueue.main.async { result(self.latestResult) }
        }
    }

    private func createCGImage(from data: Data, width: Int, height: Int) -> CGImage? {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        guard let provider = CGDataProvider(data: data as CFData) else { return nil }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    private func calculateSmileScore(from landmarks: VNFaceLandmarks2D) -> Double {
        // 通过嘴角位置估算笑容
        guard let outerLips = landmarks.outerLips else { return 0 }
        let points = outerLips.normalizedPoints
        guard points.count >= 4 else { return 0 }

        let leftCorner = points.first!
        let rightCorner = points.last!
        let topLip = points[points.count / 3]
        let bottomLip = points[points.count * 2 / 3]

        let mouthWidth = hypot(rightCorner.x - leftCorner.x, rightCorner.y - leftCorner.y)
        let mouthHeight = hypot(bottomLip.x - topLip.x, bottomLip.y - topLip.y)

        // 嘴巴宽高比越大 = 越像笑容
        let ratio = mouthWidth / max(mouthHeight, 0.01)
        return min(max((ratio - 1.5) / 3.0, 0), 1.0)
    }

    private func calculateEyeOpenness(_ eye: VNFaceLandmarkRegion2D?) -> Double {
        guard let eye = eye else { return 0.5 }
        let points = eye.normalizedPoints
        guard points.count >= 4 else { return 0.5 }

        let eyeHeight = hypot(points[1].x - points[3].x, points[1].y - points[3].y)
        let eyeWidth = hypot(points[0].x - points[2].x, points[0].y - points[2].y)

        return min(max(eyeHeight / max(eyeWidth, 0.01) * 0.4, 0), 1.0)
    }
}
