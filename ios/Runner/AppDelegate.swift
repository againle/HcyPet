import Flutter
import UIKit
import AVFoundation
import Vision
import Speech

// MARK: - 帧数据快照

struct FaceFrameSnapshot {
    let timestamp: TimeInterval; let hasFace: Bool; let boundingBox: CGRect
    let headYaw: Double; let headPitch: Double; let headRoll: Double
    let eyeOpenness: Double; let mouthOpenRatio: Double; let browRaise: Double
    let lipCornerY: Double; let faceSize: Double
    static let empty = FaceFrameSnapshot(timestamp: 0, hasFace: false, boundingBox: .zero,
        headYaw: 0, headPitch: 0, headRoll: 0, eyeOpenness: 0.5, mouthOpenRatio: 0,
        browRaise: 0, lipCornerY: 0.5, faceSize: 0)
}

struct EmotionSpectrum {
    var calm: Double = 0.5; var focused: Double = 0.5; var frustrated: Double = 0.0
    var bored: Double = 0.0; var happy: Double = 0.0; var anxious: Double = 0.0; var tired: Double = 0.0
}

enum StudyScene: String { case reading; case computer; case phone; case distracted; case noFace }

// MARK: - VisionDetector V3

class VisionDetector: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sequenceHandler = VNSequenceRequestHandler()
    private var isRunning = false
    var onResult: ((String, Double, String, Bool) -> Void)?
    var onError: ((String) -> Void)?
    private var lastDetectionTime: TimeInterval = 0
    private let detectionInterval: TimeInterval = 0.2
    private let ringBufferCapacity = 30
    private var ringBuffer: [FaceFrameSnapshot] = []
    private var ringBufferIndex = 0
    private var totalFramesProcessed = 0
    private var baselineEyeOpenness: Double = 0.65
    private var baselineBrowY: Double = 0.68
    private var baselineFaceSize: Double = 0.32
    private var eyebrowMovementHistory: [Double] = []
    private var mouthPressHistory: [Double] = []
    private var blinkCountWindow: [TimeInterval] = []

    func start() {
        guard !isRunning else { return }; resetBuffers(); setupCaptureSession(); isRunning = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in self?.captureSession.startRunning() }
    }
    func stop() { isRunning = false; captureSession.stopRunning(); resetBuffers() }
    private func resetBuffers() {
        ringBuffer.removeAll(); ringBufferIndex = 0; totalFramesProcessed = 0
        eyebrowMovementHistory.removeAll(); mouthPressHistory.removeAll(); blinkCountWindow.removeAll()
    }
    private func setupCaptureSession() {
        captureSession.sessionPreset = .low
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera), captureSession.canAddInput(input) else {
            onError?("无法访问前置摄像头"); return
        }
        captureSession.addInput(input)
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "vision.detection", qos: .userInitiated))
        if captureSession.canAddOutput(videoOutput) { captureSession.addOutput(videoOutput) }
        if let connection = videoOutput.connection(with: .video) { connection.isVideoMirrored = true; connection.videoOrientation = .portrait }
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastDetectionTime >= detectionInterval else { return }; lastDetectionTime = now
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let faceRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            if let error = error { self?.onError?("检测错误: \(error.localizedDescription)"); return }
            self?.processFaceObservations(request.results as? [VNFaceObservation])
        }
        do { try sequenceHandler.perform([faceRequest], on: pixelBuffer) } catch {}
    }
    private func processFaceObservations(_ observations: [VNFaceObservation]?) {
        guard let face = observations?.first else { appendSnapshot(FaceFrameSnapshot.empty); emitAnalysis(); return }
        let s = buildSnapshot(from: face); appendSnapshot(s); updateBaselines(s); emitAnalysis()
    }
    private func buildSnapshot(from face: VNFaceObservation) -> FaceFrameSnapshot {
        let box = face.boundingBox
        let roll = Double(face.roll?.floatValue ?? 0) / .pi, yaw = Double(face.yaw?.floatValue ?? 0) / .pi, pitch = Double(face.pitch?.floatValue ?? 0) / .pi
        var eo: Double = 0.5, mr: Double = 0, lcy: Double = 0.5, br: Double = 0
        if let le = face.landmarks?.leftEye, let re = face.landmarks?.rightEye { eo = eyeOpennessScore(le, re) }
        if let lips = face.landmarks?.outerLips {
            mr = mouthOpenHeight(lips) / max(mouthWidth(lips), 0.001)
            let pts = lips.normalizedPoints; if pts.count >= 12 { lcy = Double((pts[0].y + pts[6].y) / 2.0) }
        }
        if let lb = face.landmarks?.leftEyebrow, let rb = face.landmarks?.rightEyebrow { br = browRaiseScore(lb, rb) }
        return FaceFrameSnapshot(timestamp: CACurrentMediaTime(), hasFace: true, boundingBox: box,
            headYaw: yaw, headPitch: pitch, headRoll: roll, eyeOpenness: eo, mouthOpenRatio: mr, browRaise: br, lipCornerY: lcy, faceSize: Double(box.width * box.height))
    }
    private func appendSnapshot(_ s: FaceFrameSnapshot) {
        if ringBuffer.count < ringBufferCapacity { ringBuffer.append(s) } else { ringBuffer[ringBufferIndex % ringBufferCapacity] = s }
        ringBufferIndex += 1; totalFramesProcessed += 1
        if s.eyeOpenness < 0.2 && (blinkCountWindow.last.map { s.timestamp - $0 > 0.5 } ?? true) { blinkCountWindow.append(s.timestamp) }
        blinkCountWindow = blinkCountWindow.filter { s.timestamp - $0 < 10.0 }
        eyebrowMovementHistory.append(s.browRaise); if eyebrowMovementHistory.count > 15 { eyebrowMovementHistory.removeFirst() }
        mouthPressHistory.append(s.mouthOpenRatio < 0.05 ? 1.0 : 0.0); if mouthPressHistory.count > 15 { mouthPressHistory.removeFirst() }
    }
    private func updateBaselines(_ s: FaceFrameSnapshot) {
        let a = 0.02
        baselineEyeOpenness = baselineEyeOpenness * (1 - a) + s.eyeOpenness * a
        baselineFaceSize = baselineFaceSize * (1 - a) + s.faceSize * a
        if s.browRaise != 0 { baselineBrowY = baselineBrowY * (1 - a) + (0.68 + s.browRaise * 0.05) * a }
    }
    private func emitAnalysis() {
        guard totalFramesProcessed >= 3 else { return }
        let scene = classifyScene(), focusScore = computeFocusScore(scene: scene), emotion = computeEmotionSpectrum(scene: scene, focusScore: focusScore)
        let isStudying = (scene == .reading || scene == .computer) && focusScore > 0.35
        onResult?(scene.rawValue, focusScore, encodeEmotionJson(emotion), isStudying)
    }
    private func classifyScene() -> StudyScene {
        let recent = Array(ringBuffer.suffix(15)), ff = recent.filter({$0.hasFace})
        guard !ff.isEmpty else { return .noFace }
        let ap = ff.map{$0.headPitch}.reduce(0,+)/Double(ff.count), ay = ff.map{abs($0.headYaw)}.reduce(0,+)/Double(ff.count), afs = ff.map{$0.faceSize}.reduce(0,+)/Double(ff.count)
        if ap > 0.35 && afs > baselineFaceSize * 1.25 { return .phone }
        let yv = variance(ff.map{$0.headYaw})
        if ap > 0.1 && ap < 0.35 && yv < 0.04 { return .reading }
        if abs(ap) < 0.15 && yv < 0.06 && variance(ff.map{Double($0.boundingBox.midX)}) < 0.015 { return .computer }
        if yv > 0.08 || Double(ff.count)/Double(recent.count) < 0.6 { return .distracted }
        return .reading
    }
    private func computeFocusScore(scene: StudyScene) -> Double {
        guard scene != .noFace else { return 0.0 }
        let ff = Array(ringBuffer.suffix(15)).filter{$0.hasFace}; guard ff.count >= 5 else { return 0.3 }
        let hs = headStabilityScore(ff), es = eyeStabilityScore(ff), fp = Double(ff.count)/Double(min(15, ringBuffer.count))
        let mc = motionCalmnessScore(ff), ps: Double = scene == .phone ? 0.15 : (scene == .distracted ? 0.2 : 1.0)
        let raw = hs*0.30+es*0.25+fp*0.20+mc*0.15+ps*0.10
        let sm: Double = { let s=scene; switch s { case .reading: return 1.0; case .computer: return 0.95; case .phone: return 0.3; case .distracted: return 0.15; case .noFace: return 0.0 } }()
        return min(1.0, max(0.0, raw*sm))
    }
    private func headStabilityScore(_ f: [FaceFrameSnapshot]) -> Double {
        let yv=variance(f.map{$0.headYaw}), pv=variance(f.map{$0.headPitch}), ar=f.map{abs($0.headRoll)}.reduce(0,+)/Double(f.count)
        return max(0,1-yv*15)*0.4+max(0,1-pv*10)*0.4+max(0,1-ar*4)*0.2
    }
    private func eyeStabilityScore(_ f: [FaceFrameSnapshot]) -> Double {
        let ev=f.map{$0.eyeOpenness}, eve=variance(ev), ae=ev.reduce(0,+)/Double(ev.count)
        let br=min(1.0,Double(blinkCountWindow.count)/10.0), bs=max(0,1-br*2.5), ss=max(0,1-eve*8)
        let os: Double = ae>baselineEyeOpenness*0.85 ? 1.0 : (ae>baselineEyeOpenness*0.6 ? 0.6 : 0.2)
        return bs*0.35+ss*0.35+os*0.30
    }
    private func motionCalmnessScore(_ f: [FaceFrameSnapshot]) -> Double {
        guard f.count>=2 else { return 0.5 }; var td: Double=0
        for i in 1..<f.count { let p=f[i-1].boundingBox, c=f[i].boundingBox; td+=sqrt(pow(Double(c.midX-p.midX),2)+pow(Double(c.midY-p.midY),2)) }
        return max(0,1.0-td/Double(f.count-1)*40)
    }
    private func computeEmotionSpectrum(scene: StudyScene, focusScore: Double) -> EmotionSpectrum {
        let recent=Array(ringBuffer.suffix(10)), ff=recent.filter{$0.hasFace}
        guard let latest=ff.last else { return EmotionSpectrum(calm:0.3,focused:0) }
        var e=EmotionSpectrum()
        let bt=abs(latest.browRaise), mpr=mouthPressHistory.reduce(0,+)/max(Double(mouthPressHistory.count),1), hm=1.0-headStabilityScore(ff)
        e.calm=max(0,1.0-bt*2.5-mpr*0.6-hm*0.5); e.focused=focusScore
        let bv=variance(eyebrowMovementHistory), ibf=latest.browRaise < -0.05, mf=motionCalmnessScore(ff)<0.7
        e.frustrated=min(1.0,(ibf ? 0.35:0)+(mpr>0.3 ? 0.25:0)+(bv>0.003 ? 0.20:0)+(mf ? 0.20:0))
        let ae=ff.map{$0.eyeOpenness}.reduce(0,+)/Double(ff.count), avr=ff.map{abs($0.headRoll)}.reduce(0,+)/Double(ff.count)
        e.bored=(ae<baselineEyeOpenness*0.75 ? 0.4:0)+(avr>0.15 ? 0.3:0)+(motionCalmnessScore(ff)>0.85&&ff.count>=8 ? 0.3:0)
        let mr=latest.mouthOpenRatio
        e.happy=(mr>0.08&&mr<0.3&&latest.lipCornerY>0.48 ? 0.6:0)+(latest.eyeOpenness<baselineEyeOpenness*0.85&&latest.eyeOpenness>0.15 ? 0.3:0)+(latest.browRaise>0.03 ? 0.1:0)
        let blr=Double(blinkCountWindow.count)/10.0
        e.anxious=(latest.eyeOpenness>baselineEyeOpenness*1.15 ? 0.3:0)+(latest.browRaise>0.08 ? 0.25:0)+(blr>0.3 ? 0.3:0)+(mpr>0.5 ? 0.15:0)
        let etd=ff.count>=8&&(Array(ff.prefix(4)).map{$0.eyeOpenness}.reduce(0,+)/4)>(Array(ff.suffix(4)).map{$0.eyeOpenness}.reduce(0,+)/4)+0.05
        e.tired=(etd ? 0.35:0)+(blr>0.4 ? 0.30:0)+(latest.headPitch>0.25 ? 0.20:0)+(ae<baselineEyeOpenness*0.55 ? 0.15:0)
        return e
    }
    private func mouthOpenHeight(_ lips: VNFaceLandmarkRegion2D) -> Double {
        let pts=lips.normalizedPoints; guard pts.count>=16 else { return 0 }
        return Double(abs((pts[2].y+pts[3].y)/2-(pts[9].y+pts[10].y)/2))
    }
    private func mouthWidth(_ lips: VNFaceLandmarkRegion2D) -> Double {
        let pts=lips.normalizedPoints; guard pts.count>=12 else { return 0 }; return Double(abs(pts[0].x-pts[6].x))
    }
    private func browRaiseScore(_ lb: VNFaceLandmarkRegion2D, _ rb: VNFaceLandmarkRegion2D) -> Double {
        let lp=lb.normalizedPoints, rp=rb.normalizedPoints; guard !lp.isEmpty, !rp.isEmpty else { return 0 }
        return (((lp.map{$0.y}.reduce(0,+)/Double(lp.count))+(rp.map{$0.y}.reduce(0,+)/Double(rp.count)))/2 - baselineBrowY) * 15.0
    }
    private func eyeOpennessScore(_ le: VNFaceLandmarkRegion2D, _ re: VNFaceLandmarkRegion2D) -> Double {
        let lp=le.normalizedPoints, rp=re.normalizedPoints; guard lp.count>=8, rp.count>=8 else { return 0.5 }
        let lr=abs(lp[1].y-lp[5].y)/max(abs(lp[0].x-lp[4].x),0.001), rr=abs(rp[1].y-rp[5].y)/max(abs(rp[0].x-rp[4].x),0.001)
        return min(1.0,max(0.0,Double((lr+rr)/2*5)))
    }
    private func variance(_ values: [Double]) -> Double {
        guard values.count>1 else { return 0 }; let m=values.reduce(0,+)/Double(values.count)
        return values.reduce(0){$0+($1-m)*($1-m)}/Double(values.count)
    }
    private func encodeEmotionJson(_ e: EmotionSpectrum) -> String {
        return "{\"calm\":\(round3(e.calm)),\"focused\":\(round3(e.focused)),\"frustrated\":\(round3(e.frustrated)),\"bored\":\(round3(e.bored)),\"happy\":\(round3(e.happy)),\"anxious\":\(round3(e.anxious)),\"tired\":\(round3(e.tired))}"
    }
    private func round3(_ v: Double) -> Double { return (v*1000).rounded()/1000 }
}

// MARK: - AppDelegate

@main
@objc class AppDelegate: FlutterAppDelegate {

    private let visionChannel = "com.hcypet.vision"
    private var visionDetector: VisionDetector?

    // V3 语音属性
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // 保持屏幕常亮
        UIApplication.shared.isIdleTimerDisabled = true

        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        let channel = FlutterMethodChannel(name: visionChannel, binaryMessenger: controller.binaryMessenger)

        channel.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "startVision": self?.startVision(result: result)
            case "stopVision": self?.stopVision(result: result)
            case "isAvailable": result(true)
            default: result(FlutterMethodNotImplemented)
            }
        }

        // V3 语音录制
        let voiceChannel = FlutterMethodChannel(name: "com.hcypet.voice", binaryMessenger: controller.binaryMessenger)
        voiceChannel.setMethodCallHandler { [weak self] (call, result) in
            self?.handleVoice(call, result: result)
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func startVision(result: @escaping FlutterResult) {
        visionDetector = VisionDetector()

        visionDetector?.onResult = { [weak self] scene, focusScore, emotionJson, isStudying in
            guard let self = self,
                  let controller = self.window?.rootViewController as? FlutterViewController else { return }
            FlutterMethodChannel(name: self.visionChannel, binaryMessenger: controller.binaryMessenger)
                .invokeMethod("onVisionResult", arguments: [
                    "scene": scene, "focusScore": focusScore,
                    "emotionJson": emotionJson, "isStudying": isStudying
                ])
        }

        visionDetector?.onError = { [weak self] error in
            guard let self = self,
                  let controller = self.window?.rootViewController as? FlutterViewController else { return }
            FlutterMethodChannel(name: self.visionChannel, binaryMessenger: controller.binaryMessenger)
                .invokeMethod("onVisionError", arguments: error)
        }

        visionDetector?.start()
        result(true)
    }

    private func stopVision(result: @escaping FlutterResult) {
        visionDetector?.stop(); visionDetector = nil; result(true)
    }

    // MARK: - Voice Methods

    private func handleVoice(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSpeechAvailable":
            result(SFSpeechRecognizer.authorizationStatus() == .authorized)
        case "requestPermission":
            SFSpeechRecognizer.requestAuthorization { s in
                DispatchQueue.main.async { result(s == .authorized) }
            }
        case "startListening":
            startVoiceListening(result: result)
        case "stopListening":
            stopVoiceListening()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startVoiceListening(result: @escaping FlutterResult) {
        stopVoiceListening()
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            result(["text": "", "success": false, "error": "音频会话失败"])
            return
        }
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let req = recognitionRequest else {
            result(["text": "", "success": false, "error": "无法创建请求"])
            return
        }
        req.shouldReportPartialResults = false
        let input = audioEngine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buf, _ in req.append(buf) }
        audioEngine.prepare()
        do { try audioEngine.start() } catch {
            result(["text": "", "success": false, "error": "录音启动失败"])
            return
        }
        recognitionTask = speechRecognizer?.recognitionTask(with: req) { [weak self] sr, err in
            guard let self = self else { return }
            if let e = err { self.stopVoiceListening(); result(["text": "", "success": false, "error": e.localizedDescription]); return }
            if let f = sr, f.isFinal { self.stopVoiceListening(); result(["text": f.bestTranscription.formattedString, "success": true]) }
        }
    }

    private func stopVoiceListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }
}

