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

// MARK: - VisionDetector (内嵌)

private class VisionDetector: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sequenceHandler = VNSequenceRequestHandler()
    private var isRunning = false

    var onResult: ((String, Double, Bool, Double) -> Void)?
    var onError: ((String) -> Void)?

    private var lastDetectionTime: TimeInterval = 0
    private let detectionInterval: TimeInterval = 0.2

    func start() {
        guard !isRunning else { return }
        setupCaptureSession()
        isRunning = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func stop() {
        isRunning = false
        captureSession.stopRunning()
    }

    private func setupCaptureSession() {
        captureSession.sessionPreset = .low
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera),
              captureSession.canAddInput(input) else {
            onError?("无法访问前置摄像头")
            return
        }
        captureSession.addInput(input)
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "vision.detection", qos: .userInitiated))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        if let connection = videoOutput.connection(with: .video) {
            connection.isVideoMirrored = true
            connection.videoOrientation = .portrait
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastDetectionTime >= detectionInterval else { return }
        lastDetectionTime = now
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let faceRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            if let error = error { self?.onError?("检测错误: \(error.localizedDescription)"); return }
            self?.processFaceObservations(request.results as? [VNFaceObservation])
        }
        do { try sequenceHandler.perform([faceRequest], on: pixelBuffer) } catch {}
    }

    private func processFaceObservations(_ observations: [VNFaceObservation]?) {
        guard let face = observations?.first else { onResult?("neutral", 0.0, false, 0.0); return }
        let (emotion, confidence) = detectEmotion(from: face)
        let (isAttention, attentionScore) = detectAttention(from: face)
        onResult?(emotion, confidence, isAttention, attentionScore)
    }

    private func detectEmotion(from face: VNFaceObservation) -> (String, Double) {
        guard let landmarks = face.landmarks else { return ("neutral", 0.0) }
        var score: [String: Double] = ["happy": 0.0, "sad": 0.0, "surprised": 0.0, "angry": 0.0, "neutral": 0.3]
        if let outerLips = landmarks.outerLips {
            let h = mouthOpenHeight(outerLips), w = mouthWidth(outerLips), r = w > 0 ? h / w : 0
            if r > 0.5 { score["surprised"] = min(1, score["surprised"]! + 0.7); score["happy"] = min(1, score["happy"]! + 0.3) }
            else if r > 0.3 { score["happy"] = min(1, score["happy"]! + 0.5) }
            else if r < 0.1 { score["sad"] = min(1, score["sad"]! + 0.3); score["angry"] = min(1, score["angry"]! + 0.2) }
        }
        if let lb = landmarks.leftEyebrow, let rb = landmarks.rightEyebrow {
            let br = browRaiseScore(lb, rb)
            if br > 0.4 { score["surprised"] = min(1, score["surprised"]! + 0.5) }
            else if br < -0.2 { score["angry"] = min(1, score["angry"]! + 0.6); score["sad"] = min(1, score["sad"]! + 0.3) }
        }
        if let le = landmarks.leftEye, let re = landmarks.rightEye {
            if eyeOpennessScore(le, re) < 0.3 { score["sad"] = min(1, score["sad"]! + 0.2); score["angry"] = min(1, score["angry"]! + 0.1) }
        }
        let top = score.sorted { $0.value > $1.value }.first!
        return (top.key, top.value)
    }

    private func detectAttention(from face: VNFaceObservation) -> (Bool, Double) {
        let b = face.boundingBox
        let xd = abs(b.midX - 0.5) * 2, yd = abs(b.midY - 0.55) * 2
        let s = max(0.0, 1.0 - (xd * 0.7 + yd * 0.3))
        return (s > 0.5, s)
    }

    private func mouthOpenHeight(_ lips: VNFaceLandmarkRegion2D) -> Double {
        let pts = lips.normalizedPoints; guard pts.count >= 16 else { return 0 }
        return Double(abs((pts[2].y + pts[3].y) / 2 - (pts[9].y + pts[10].y) / 2))
    }
    private func mouthWidth(_ lips: VNFaceLandmarkRegion2D) -> Double {
        let pts = lips.normalizedPoints; guard pts.count >= 12 else { return 0 }
        return Double(abs(pts[0].x - pts[6].x))
    }
    private func browRaiseScore(_ lb: VNFaceLandmarkRegion2D, _ rb: VNFaceLandmarkRegion2D) -> Double {
        let lp = lb.normalizedPoints, rp = rb.normalizedPoints
        guard !lp.isEmpty, !rp.isEmpty else { return 0 }
        let avg = ((lp.map{$0.y}.reduce(0,+)/Double(lp.count)) + (rp.map{$0.y}.reduce(0,+)/Double(rp.count))) / 2
        return Double(avg - 0.68) * 10
    }
    private func eyeOpennessScore(_ le: VNFaceLandmarkRegion2D, _ re: VNFaceLandmarkRegion2D) -> Double {
        let lp = le.normalizedPoints, rp = re.normalizedPoints
        guard lp.count >= 8, rp.count >= 8 else { return 0.5 }
        let lr = abs(lp[1].y - lp[5].y) / max(abs(lp[0].x - lp[4].x), 0.001)
        let rr = abs(rp[1].y - rp[5].y) / max(abs(rp[0].x - rp[4].x), 0.001)
        return min(1, max(0, Double((lr + rr) / 2 * 5)))
    }
}

