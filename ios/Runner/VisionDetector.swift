import AVFoundation
import Vision
import UIKit

// MARK: - 帧数据快照（用于时序分析）

/// 单帧面部分析结果
struct FaceFrameSnapshot {
    let timestamp: TimeInterval
    let hasFace: Bool
    let boundingBox: CGRect          // 归一化坐标 0-1
    let headYaw: Double              // 左右转头 (-1~1, 正=右转)
    let headPitch: Double            // 上下点头 (-1~1, 正=抬头)
    let headRoll: Double             // 歪头 (-1~1)
    let eyeOpenness: Double          // 0=闭合, 1=全开
    let mouthOpenRatio: Double       // 嘴高/嘴宽
    let browRaise: Double            // 负=下压, 正=上扬
    let lipCornerY: Double           // 嘴角平均Y (越大嘴角越下垂)
    let faceSize: Double             // 人脸在画面中的相对大小

    static let empty = FaceFrameSnapshot(
        timestamp: 0, hasFace: false, boundingBox: .zero,
        headYaw: 0, headPitch: 0, headRoll: 0,
        eyeOpenness: 0.5, mouthOpenRatio: 0, browRaise: 0,
        lipCornerY: 0.5, faceSize: 0
    )
}

/// 连续情绪谱（各维度 0~1）
struct EmotionSpectrum {
    var calm: Double = 0.5        // 平静
    var focused: Double = 0.5     // 专注
    var frustrated: Double = 0.0  // 烦躁
    var bored: Double = 0.0       // 无聊
    var happy: Double = 0.0       // 开心
    var anxious: Double = 0.0     // 焦虑
    var tired: Double = 0.0       // 疲惫
}

/// 场景分类
enum StudyScene: String {
    case reading    // 看书/写字（头微低，稳定）
    case computer   // 电脑（头平视，水平扫视）
    case phone      // 手机（头低垂，靠近）
    case distracted // 分心（频繁转头/离开）
    case noFace     // 无人脸
}

// MARK: - VisionDetector (V3 重写)

/// Apple Vision 面部检测器 V3 — 场景识别 + 连续情绪谱 + 多因子专注度
/// 通过 MethodChannel 与 Flutter 通信
class VisionDetector: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - 属性

    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sequenceHandler = VNSequenceRequestHandler()
    private var isRunning = false

    /// Flutter 回调 — V3 新签名:
    /// (scene, focusScore, emotionJson, isStudying)
    var onResult: ((String, Double, String, Bool) -> Void)?
    var onError: ((String) -> Void)?

    // 检测节流
    private var lastDetectionTime: TimeInterval = 0
    private let detectionInterval: TimeInterval = 0.2 // 5 FPS

    // MARK: - 时序缓冲区（滑动窗口）

    private let ringBufferCapacity = 30  // 30帧 ≈ 6秒
    private var ringBuffer: [FaceFrameSnapshot] = []
    private var ringBufferIndex = 0
    private var totalFramesProcessed = 0

    // 面部特征基线（初始化后持续更新）
    private var baselineEyeOpenness: Double = 0.65
    private var baselineBrowY: Double = 0.68
    private var baselineFaceSize: Double = 0.32

    // 变化率追踪
    private var eyebrowMovementHistory: [Double] = []   // 最近眉毛变化率
    private var mouthPressHistory: [Double] = []        // 最近抿嘴程度
    private var blinkCountWindow: [TimeInterval] = []   // 眨眼时间戳窗口

    // MARK: - 公开方法

    func start() {
        guard !isRunning else { return }
        resetBuffers()
        setupCaptureSession()
        isRunning = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func stop() {
        isRunning = false
        captureSession.stopRunning()
        resetBuffers()
    }

    private func resetBuffers() {
        ringBuffer.removeAll()
        ringBufferIndex = 0
        totalFramesProcessed = 0
        eyebrowMovementHistory.removeAll()
        mouthPressHistory.removeAll()
        blinkCountWindow.removeAll()
    }

    // MARK: - 摄像头配置

    private func setupCaptureSession() {
        captureSession.sessionPreset = .low

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

        if let connection = videoOutput.connection(with: .video) {
            connection.isVideoMirrored = true
            connection.videoOrientation = .portrait
        }
    }

    // MARK: - AVCapture delegate

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastDetectionTime >= detectionInterval else { return }
        lastDetectionTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let faceRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            if let error = error {
                self?.onError?("检测错误: \(error.localizedDescription)")
                return
            }
            self?.processFaceObservations(request.results as? [VNFaceObservation])
        }

        do {
            try sequenceHandler.perform([faceRequest], on: pixelBuffer)
        } catch {
            // 忽略单帧错误
        }
    }

    // MARK: - 帧处理管线

    private func processFaceObservations(_ observations: [VNFaceObservation]?) {
        guard let face = observations?.first else {
            // 无人脸 → 记录空帧
            appendSnapshot(FaceFrameSnapshot.empty)
            emitAnalysis()
            return
        }

        let snapshot = buildSnapshot(from: face)
        appendSnapshot(snapshot)
        updateBaselines(snapshot)
        emitAnalysis()
    }

    /// 从 VNFaceObservation 提取帧快照
    private func buildSnapshot(from face: VNFaceObservation) -> FaceFrameSnapshot {
        let box = face.boundingBox
        let landmarks = face.landmarks
        let roll = Double(face.roll?.floatValue ?? 0) / .pi       // 归一化到 -1~1
        let yaw  = Double(face.yaw?.floatValue ?? 0) / .pi
        let pitch = Double(face.pitch?.floatValue ?? 0) / .pi

        // 眼部
        var eyeOpen: Double = 0.5
        if let lEye = landmarks?.leftEye, let rEye = landmarks?.rightEye {
            eyeOpen = eyeOpennessScore(lEye, rEye)
        }

        // 嘴部
        var mouthRatio: Double = 0
        var lipCornerY: Double = 0.5
        if let lips = landmarks?.outerLips {
            mouthRatio = mouthOpenHeight(lips) / max(mouthWidth(lips), 0.001)
            let pts = lips.normalizedPoints
            if pts.count >= 12 {
                lipCornerY = Double((pts[0].y + pts[6].y) / 2.0)
            }
        }

        // 眉毛
        var brow: Double = 0
        if let lBrow = landmarks?.leftEyebrow, let rBrow = landmarks?.rightEyebrow {
            brow = browRaiseScore(lBrow, rBrow)
        }

        let faceSize = Double(box.width * box.height)

        return FaceFrameSnapshot(
            timestamp: CACurrentMediaTime(),
            hasFace: true,
            boundingBox: box,
            headYaw: yaw,
            headPitch: pitch,
            headRoll: roll,
            eyeOpenness: eyeOpen,
            mouthOpenRatio: mouthRatio,
            browRaise: brow,
            lipCornerY: lipCornerY,
            faceSize: faceSize
        )
    }

    private func appendSnapshot(_ snapshot: FaceFrameSnapshot) {
        if ringBuffer.count < ringBufferCapacity {
            ringBuffer.append(snapshot)
        } else {
            ringBuffer[ringBufferIndex % ringBufferCapacity] = snapshot
        }
        ringBufferIndex += 1
        totalFramesProcessed += 1

        // 追踪眨眼
        if snapshot.eyeOpenness < 0.2 && (blinkCountWindow.last.map { snapshot.timestamp - $0 > 0.5 } ?? true) {
            blinkCountWindow.append(snapshot.timestamp)
        }
        // 清理超出10秒的眨眼记录
        blinkCountWindow = blinkCountWindow.filter { snapshot.timestamp - $0 < 10.0 }

        // 追踪眉毛变化
        eyebrowMovementHistory.append(snapshot.browRaise)
        if eyebrowMovementHistory.count > 15 { eyebrowMovementHistory.removeFirst() }

        // 追踪抿嘴（嘴巴紧闭程度）
        mouthPressHistory.append(snapshot.mouthOpenRatio < 0.05 ? 1.0 : 0.0)
        if mouthPressHistory.count > 15 { mouthPressHistory.removeFirst() }
    }

    private func updateBaselines(_ snapshot: FaceFrameSnapshot) {
        let alpha = 0.02 // 缓慢EMA更新基线
        baselineEyeOpenness = baselineEyeOpenness * (1 - alpha) + snapshot.eyeOpenness * alpha
        baselineFaceSize = baselineFaceSize * (1 - alpha) + snapshot.faceSize * alpha
        if snapshot.browRaise != 0 {
            baselineBrowY = baselineBrowY * (1 - alpha) + (0.68 + snapshot.browRaise * 0.05) * alpha
        }
    }

    // MARK: - 综合分析（每帧输出）

    private func emitAnalysis() {
        guard totalFramesProcessed >= 3 else { return } // 需要预热

        let scene = classifyScene()
        let focusScore = computeFocusScore(scene: scene)
        let emotion = computeEmotionSpectrum(scene: scene, focusScore: focusScore)
        let isStudying = (scene == .reading || scene == .computer) && focusScore > 0.35

        let emotionJson = encodeEmotionJson(emotion)
        onResult?(scene.rawValue, focusScore, emotionJson, isStudying)
    }

    // MARK: ——— 场景分类 ———

    /// 根据最近帧判断用户当前学习场景
    private func classifyScene() -> StudyScene {
        let recent = Array(ringBuffer.suffix(15))
        let faceFrames = recent.filter { $0.hasFace }
        guard !faceFrames.isEmpty else { return .noFace }

        let avgPitch = faceFrames.map { $0.headPitch }.reduce(0, +) / Double(faceFrames.count)
        let avgYaw   = faceFrames.map { abs($0.headYaw) }.reduce(0, +) / Double(faceFrames.count)
        let avgFaceSize = faceFrames.map { $0.faceSize }.reduce(0, +) / Double(faceFrames.count)

        // 手机特征：头低垂(正pitch大) + 人脸偏大(离得近) + 头部常偏转
        if avgPitch > 0.35 && avgFaceSize > baselineFaceSize * 1.25 {
            return .phone
        }

        // 阅读/写字特征：头微低 + 头部稳定(小yaw方差) + 人脸大小正常
        let yawVariance = variance(faceFrames.map { $0.headYaw })
        if avgPitch > 0.1 && avgPitch < 0.35 && yawVariance < 0.04 {
            return .reading
        }

        // 电脑特征：头平视(低pitch) + 稳定 + 水平扫视(中等yaw方差)
        let xCenterVariance = variance(faceFrames.map { Double($0.boundingBox.midX) })
        if abs(avgPitch) < 0.15 && yawVariance < 0.06 && xCenterVariance < 0.015 {
            return .computer
        }

        // 分心特征：频繁转头(高yaw方差) 或 频繁离开
        let facePresenceRatio = Double(faceFrames.count) / Double(recent.count)
        if yawVariance > 0.08 || facePresenceRatio < 0.6 {
            return .distracted
        }

        return .reading // 默认偏向阅读
    }

    // MARK: ——— 多因子专注度评分 ———

    /// 综合多维度计算 0~1 专注度
    private func computeFocusScore(scene: StudyScene) -> Double {
        guard scene != .noFace else { return 0.0 }

        let recent = Array(ringBuffer.suffix(15))
        let faceFrames = recent.filter { $0.hasFace }
        guard faceFrames.count >= 5 else { return 0.3 }

        // 因子1：头部姿态稳定性 (0.30)
        let headStability = headStabilityScore(faceFrames)

        // 因子2：视线/眼部稳定性 (0.25)
        let eyeStability = eyeStabilityScore(faceFrames)

        // 因子3：面部持续存在 (0.20)
        let facePresence = Double(faceFrames.count) / Double(recent.count)

        // 因子4：运动平静度 (0.15)
        let motionCalmness = motionCalmnessScore(faceFrames)

        // 因子5：姿态得分 — 手机扣分 (0.10)
        let postureScore: Double = (scene == .phone) ? 0.15 : (scene == .distracted ? 0.2 : 1.0)

        let rawScore = headStability * 0.30
                     + eyeStability * 0.25
                     + facePresence * 0.20
                     + motionCalmness * 0.15
                     + postureScore * 0.10

        // 场景衰减
        let sceneMultiplier: Double = switch scene {
        case .reading:    1.0
        case .computer:   0.95
        case .phone:      0.3
        case .distracted: 0.15
        case .noFace:     0.0
        }

        return min(1.0, max(0.0, rawScore * sceneMultiplier))
    }

    /// 头部姿态稳定性：低yaw/pitch方差 + 低roll绝对值
    private func headStabilityScore(_ frames: [FaceFrameSnapshot]) -> Double {
        let yawVar   = variance(frames.map { $0.headYaw })
        let pitchVar = variance(frames.map { $0.headPitch })
        let avgAbsRoll = frames.map { abs($0.headRoll) }.reduce(0, +) / Double(frames.count)

        let yawScore   = max(0, 1.0 - yawVar * 15)
        let pitchScore = max(0, 1.0 - pitchVar * 10)
        let rollScore  = max(0, 1.0 - avgAbsRoll * 4)

        return (yawScore * 0.4 + pitchScore * 0.4 + rollScore * 0.2)
    }

    /// 眼部稳定性：眨眼频率低 + 眼部张开度稳定
    private func eyeStabilityScore(_ frames: [FaceFrameSnapshot]) -> Double {
        let eyeValues = frames.map { $0.eyeOpenness }
        let eyeVar = variance(eyeValues)
        let avgEye = eyeValues.reduce(0, +) / Double(eyeValues.count)

        // 眨眼频率（次/秒）
        let recentBlinks = blinkCountWindow.count
        let blinkRate = min(1.0, Double(recentBlinks) / 10.0) // 10秒内眨眼次数归一化
        let blinkScore = max(0, 1.0 - blinkRate * 2.5)        // >0.4次/秒开始扣分

        // 眼部稳定
        let stabilityScore = max(0, 1.0 - eyeVar * 8)

        // 眼部健康度（太闭合=困了）
        let opennessScore: Double
        if avgEye > baselineEyeOpenness * 0.85 { opennessScore = 1.0 }
        else if avgEye > baselineEyeOpenness * 0.6 { opennessScore = 0.6 }
        else { opennessScore = 0.2 }

        return blinkScore * 0.35 + stabilityScore * 0.35 + opennessScore * 0.30
    }

    /// 运动平静度：人脸位置变化小 = 专注
    private func motionCalmnessScore(_ frames: [FaceFrameSnapshot]) -> Double {
        guard frames.count >= 2 else { return 0.5 }
        var totalDisplacement: Double = 0
        for i in 1..<frames.count {
            let prev = frames[i-1].boundingBox
            let curr = frames[i].boundingBox
            let dx = Double(curr.midX - prev.midX)
            let dy = Double(curr.midY - prev.midY)
            totalDisplacement += sqrt(dx*dx + dy*dy)
        }
        let avgDisp = totalDisplacement / Double(frames.count - 1)
        return max(0, 1.0 - avgDisp * 40)
    }

    // MARK: ——— 连续情绪谱 ———

    /// 输出7维情绪向量，每维 0~1，敏感度提高
    private func computeEmotionSpectrum(scene: StudyScene, focusScore: Double) -> EmotionSpectrum {
        let recent = Array(ringBuffer.suffix(10))
        let faceFrames = recent.filter { $0.hasFace }
        guard let latest = faceFrames.last else {
            return EmotionSpectrum(calm: 0.3, focused: 0.0)
        }

        var e = EmotionSpectrum()

        // — 平静度 calm —
        // 基于：眉毛不紧绷 + 嘴不抿 + 头部稳定
        let browTension = abs(latest.browRaise)
        let mouthPressRatio = mouthPressHistory.reduce(0, +) / max(Double(mouthPressHistory.count), 1)
        let headMotion = 1.0 - headStabilityScore(faceFrames)
        e.calm = max(0, 1.0 - browTension * 2.5 - mouthPressRatio * 0.6 - headMotion * 0.5)

        // — 专注度 focused —
        e.focused = focusScore

        // — 烦躁 frustrated —
        // 基于：眉毛间歇下压(微皱眉) + 抿嘴频率 + 头部小幅晃动
        let browVariance = variance(eyebrowMovementHistory)
        let isBrowFurrowing = latest.browRaise < -0.05  // 略微下压（比-0.2敏感得多）
        let microFidget = motionCalmnessScore(faceFrames) < 0.7
        let frustrationRaw = (isBrowFurrowing ? 0.35 : 0.0)
                           + (mouthPressRatio > 0.3 ? 0.25 : 0.0)
                           + (browVariance > 0.003 ? 0.20 : 0.0)
                           + (microFidget ? 0.20 : 0.0)
        e.frustrated = min(1.0, frustrationRaw)

        // — 无聊 bored —
        // 基于：眼部张开度持续偏低 + 头部倾斜(歪头) + 低面部变化
        let avgEye = faceFrames.map { $0.eyeOpenness }.reduce(0, +) / Double(faceFrames.count)
        let avgRoll = faceFrames.map { abs($0.headRoll) }.reduce(0, +) / Double(faceFrames.count)
        let isDroopyEye = avgEye < baselineEyeOpenness * 0.75
        let isHeadTilted = avgRoll > 0.15
        let isStatic = motionCalmnessScore(faceFrames) > 0.85 && faceFrames.count >= 8
        e.bored = (isDroopyEye ? 0.4 : 0.0) + (isHeadTilted ? 0.3 : 0.0) + (isStatic ? 0.3 : 0.0)

        // — 开心 happy —
        // 基于：嘴角上扬(嘴宽>嘴高) + 眼部微眯(笑眼)
        let mouthRatio = latest.mouthOpenRatio
        let isSmiling = mouthRatio > 0.08 && mouthRatio < 0.3 && latest.lipCornerY > 0.48
        let isEyeSmile = latest.eyeOpenness < baselineEyeOpenness * 0.85 && latest.eyeOpenness > 0.15
        e.happy = (isSmiling ? 0.6 : 0.0) + (isEyeSmile ? 0.3 : 0.0) + (latest.browRaise > 0.03 ? 0.1 : 0.0)

        // — 焦虑 anxious —
        // 基于：眉毛上扬(微紧张) + 眨眼频率高 + 眼部张开度偏高
        let blinkRate = Double(blinkCountWindow.count) / 10.0
        let isWideEye = latest.eyeOpenness > baselineEyeOpenness * 1.15
        let isBrowRaised = latest.browRaise > 0.08
        e.anxious = (isWideEye ? 0.3 : 0.0)
                  + (isBrowRaised ? 0.25 : 0.0)
                  + (blinkRate > 0.3 ? 0.3 : 0.0)
                  + (mouthPressRatio > 0.5 ? 0.15 : 0.0)

        // — 疲惫 tired —
        // 基于：眼部张开度趋势下降 + 眨眼频率增加 + 头部下倾
        let eyeTrendDown = faceFrames.count >= 8 &&
            (faceFrames.prefix(4).map{$0.eyeOpenness}.reduce(0,+)/4) >
            (faceFrames.suffix(4).map{$0.eyeOpenness}.reduce(0,+)/4) + 0.05
        let headDrooping = latest.headPitch > 0.25
        e.tired = (eyeTrendDown ? 0.35 : 0.0)
                + (blinkRate > 0.4 ? 0.30 : 0.0)
                + (headDrooping ? 0.20 : 0.0)
                + (avgEye < baselineEyeOpenness * 0.55 ? 0.15 : 0.0)

        return e
    }

    // MARK: ——— 辅助：面部几何 ———

    private func mouthOpenHeight(_ lips: VNFaceLandmarkRegion2D) -> Double {
        let pts = lips.normalizedPoints
        guard pts.count >= 16 else { return 0 }
        let upperY = (pts[2].y + pts[3].y) / 2
        let lowerY = (pts[9].y + pts[10].y) / 2
        return Double(abs(upperY - lowerY))
    }

    private func mouthWidth(_ lips: VNFaceLandmarkRegion2D) -> Double {
        let pts = lips.normalizedPoints
        guard pts.count >= 12 else { return 0 }
        return Double(abs(pts[0].x - pts[6].x))
    }

    private func browRaiseScore(_ leftBrow: VNFaceLandmarkRegion2D, _ rightBrow: VNFaceLandmarkRegion2D) -> Double {
        let lPts = leftBrow.normalizedPoints
        let rPts = rightBrow.normalizedPoints
        guard !lPts.isEmpty, !rPts.isEmpty else { return 0 }
        let lAvgY = lPts.map { $0.y }.reduce(0, +) / Double(lPts.count)
        let rAvgY = rPts.map { $0.y }.reduce(0, +) / Double(rPts.count)
        let avgY = Double((lAvgY + rAvgY) / 2.0)
        return (avgY - baselineBrowY) * 15.0
    }

    private func eyeOpennessScore(_ leftEye: VNFaceLandmarkRegion2D, _ rightEye: VNFaceLandmarkRegion2D) -> Double {
        let lPts = leftEye.normalizedPoints
        let rPts = rightEye.normalizedPoints
        guard lPts.count >= 8, rPts.count >= 8 else { return 0.5 }

        let lH = abs(lPts[1].y - lPts[5].y)
        let lW = abs(lPts[0].x - lPts[4].x)
        let lR = lW > 0 ? lH / lW : 0

        let rH = abs(rPts[1].y - rPts[5].y)
        let rW = abs(rPts[0].x - rPts[4].x)
        let rR = rW > 0 ? rH / rW : 0

        let avgRatio = Double((lR + rR) / 2.0)
        return min(1.0, max(0.0, avgRatio * 5.0))
    }

    // MARK: ——— 辅助：统计 ———

    private func variance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let sumSq = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        return sumSq / Double(values.count)
    }

    // MARK: ——— JSON 编码 ———

    private func encodeEmotionJson(_ e: EmotionSpectrum) -> String {
        return """
        {"calm":\(round3(e.calm)),"focused":\(round3(e.focused)),"frustrated":\(round3(e.frustrated)),"bored":\(round3(e.bored)),"happy":\(round3(e.happy)),"anxious":\(round3(e.anxious)),"tired":\(round3(e.tired))}
        """
    }

    private func round3(_ v: Double) -> Double {
        return (v * 1000).rounded() / 1000
    }
}
