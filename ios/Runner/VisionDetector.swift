import AVFoundation
import Vision
import UIKit

/// Apple Vision 面部检测器 — 情绪 + 注意力分析
/// 通过 MethodChannel 与 Flutter 通信
class VisionDetector: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - 属性

    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sequenceHandler = VNSequenceRequestHandler()
    private var isRunning = false

    /// Flutter 回调
    var onResult: ((String, Double, Bool, Double) -> Void)? // (emotion, confidence, isAttention, attentionScore)
    var onError: ((String) -> Void)?

    // 检测节流
    private var lastDetectionTime: TimeInterval = 0
    private let detectionInterval: TimeInterval = 0.2 // 5 FPS

    // MARK: - 公开方法

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

    // MARK: - 摄像头配置

    private func setupCaptureSession() {
        captureSession.sessionPreset = .low // 低分辨率，省电

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera),
              captureSession.canAddInput(input) else {
            onError?("无法访问前置摄像头")
            return
        }

        captureSession.addInput(input)

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "vision.detection", qos: .userInitiated))

        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        // 镜像前置摄像头
        if let connection = videoOutput.connection(with: .video) {
            connection.isVideoMirrored = true
            connection.videoOrientation = .portrait
        }
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastDetectionTime >= detectionInterval else { return }
        lastDetectionTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // 人脸检测请求
        let faceRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            if let error = error {
                self?.onError?("检测错误: \(error.localizedDescription)")
                return
            }
            self?.processFaceObservations(request.results as? [VNFaceObservation])
        }

        // 人脸矩形请求（辅助判断是否有人脸）
        let faceRectRequest = VNDetectFaceRectanglesRequest()

        do {
            try sequenceHandler.perform([faceRequest, faceRectRequest], on: pixelBuffer)
        } catch {
            // 忽略单帧错误
        }
    }

    // MARK: - 面部分析

    private func processFaceObservations(_ observations: [VNFaceObservation]?) {
        guard let face = observations?.first else {
            // 未检测到人脸
            onResult?("neutral", 0.0, false, 0.0)
            return
        }

        // ---- 情绪分析 ----
        let (emotion, confidence) = detectEmotion(from: face)

        // ---- 注意力分析 ----
        let (isAttention, attentionScore) = detectAttention(from: face)

        onResult?(emotion, confidence, isAttention, attentionScore)
    }

    /// 基于面部特征推断情绪
    private func detectEmotion(from face: VNFaceObservation) -> (String, Double) {
        guard let landmarks = face.landmarks else {
            return ("neutral", 0.0)
        }

        var score: [String: Double] = [
            "happy": 0.0,
            "sad": 0.0,
            "surprised": 0.0,
            "angry": 0.0,
            "neutral": 0.3
        ]

        // --- 嘴部分析 ---
        if let outerLips = landmarks.outerLips {
            let mouthHeight = mouthOpenHeight(outerLips)
            let mouthWidth = mouthWidth(outerLips)
            let mouthRatio = mouthWidth > 0 ? mouthHeight / mouthWidth : 0

            if mouthRatio > 0.5 {
                score["surprised"] = min(1.0, score["surprised"]! + 0.7) // 张嘴 → 惊讶
                score["happy"] = min(1.0, score["happy"]! + 0.3)
            } else if mouthRatio > 0.3 {
                score["happy"] = min(1.0, score["happy"]! + 0.5) // 微笑
            } else if mouthRatio < 0.1 {
                score["sad"] = min(1.0, score["sad"]! + 0.3) // 嘴角下垂
                score["angry"] = min(1.0, score["angry"]! + 0.2)
            }
        }

        // --- 眉毛分析 ---
        if let leftBrow = landmarks.leftEyebrow, let rightBrow = landmarks.rightEyebrow {
            let browRaise = browRaiseScore(leftBrow, rightBrow)
            if browRaise > 0.4 {
                score["surprised"] = min(1.0, score["surprised"]! + 0.5) // 眉毛上扬 → 惊讶
            } else if browRaise < -0.2 {
                score["angry"] = min(1.0, score["angry"]! + 0.6) // 眉毛下压 → 生气
                score["sad"] = min(1.0, score["sad"]! + 0.3)
            }
        }

        // --- 眼睛分析 ---
        if let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye {
            let eyeOpenness = eyeOpennessScore(leftEye, rightEye)
            if eyeOpenness < 0.3 {
                score["sad"] = min(1.0, score["sad"]! + 0.2)
                score["angry"] = min(1.0, score["angry"]! + 0.1)
            }
        }

        // 取最高分情绪
        let sorted = score.sorted { $0.value > $1.value }
        let top = sorted.first!
        return (top.key, top.value)
    }

    /// 基于头部姿态推断注意力
    private func detectAttention(from face: VNFaceObservation) -> (Bool, Double) {
        // 使用 boundingBox 中心偏移估算注意力
        let box = face.boundingBox
        let centerX = box.midX
        let centerY = box.midY

        // 人脸在画面中心 = 正在看屏幕
        let xDeviation = abs(centerX - 0.5) * 2 // 0~1
        let yDeviation = abs(centerY - 0.55) * 2 // 0~1（略偏上）

        let attentionScore = max(0.0, 1.0 - (xDeviation * 0.7 + yDeviation * 0.3))
        let isAttention = attentionScore > 0.5

        return (isAttention, attentionScore)
    }

    // MARK: - 面部几何计算

    private func mouthOpenHeight(_ lips: VNFaceLandmarkRegion2D) -> Double {
        let points = lips.normalizedPoints
        guard points.count >= 16 else { return 0 }
        // 上唇中点 vs 下唇中点
        let upperY = (points[2].y + points[3].y) / 2
        let lowerY = (points[9].y + points[10].y) / 2
        return Double(abs(upperY - lowerY))
    }

    private func mouthWidth(_ lips: VNFaceLandmarkRegion2D) -> Double {
        let points = lips.normalizedPoints
        guard points.count >= 12 else { return 0 }
        return Double(abs(points[0].x - points[6].x))
    }

    private func browRaiseScore(_ leftBrow: VNFaceLandmarkRegion2D, _ rightBrow: VNFaceLandmarkRegion2D) -> Double {
        let leftPoints = leftBrow.normalizedPoints
        let rightPoints = rightBrow.normalizedPoints
        guard !leftPoints.isEmpty, !rightPoints.isEmpty else { return 0 }

        // 平均 Y 坐标 → 越高 = 眉毛越上扬
        let leftAvgY = leftPoints.map { $0.y }.reduce(0, +) / Double(leftPoints.count)
        let rightAvgY = rightPoints.map { $0.y }.reduce(0, +) / Double(rightPoints.count)
        let avgY = (leftAvgY + rightAvgY) as Double / 2.0

        // 0.7 为中性参考线（经验值），高于此线 = 上扬
        return Double(avgY - 0.68) * 10.0
    }

    private func eyeOpennessScore(_ leftEye: VNFaceLandmarkRegion2D, _ rightEye: VNFaceLandmarkRegion2D) -> Double {
        let leftPoints = leftEye.normalizedPoints
        let rightPoints = rightEye.normalizedPoints
        guard leftPoints.count >= 8, rightPoints.count >= 8 else { return 0.5 }

        // 左眼高度
        let leftHeight = abs(leftPoints[1].y - leftPoints[5].y) // 上下眼睑
        let leftWidth = abs(leftPoints[0].x - leftPoints[4].x)   // 眼角宽度
        let leftRatio = leftWidth > 0 ? leftHeight / leftWidth : 0

        // 右眼高度
        let rightHeight = abs(rightPoints[1].y - rightPoints[5].y)
        let rightWidth = abs(rightPoints[0].x - rightPoints[4].x)
        let rightRatio = rightWidth > 0 ? rightHeight / rightWidth : 0

        let avgRatio = (leftRatio + rightRatio) as Double / 2.0
        return min(1.0, max(0.0, Double(avgRatio * 5.0))) // 归一化
    }
}
