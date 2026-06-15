import Foundation
import Combine
import AVFoundation

final class AudioRecorder: NSObject, ObservableObject {

    enum RecordState { case idle, recording, done }

    @Published var recordState: RecordState = .idle
    @Published var elapsedSeconds: Int = 0
    @Published var meterLevels: [CGFloat] = .init(repeating: 0.12, count: 30)

    private(set) var recordingURL: URL?

    private var recorder: AVAudioRecorder?
    private var elapsedTimer: Timer?
    private var meterTimer: Timer?

    // MARK: - Public API

    /// Requests microphone permission then begins recording.
    func requestAndStart() {
        Task {
            let granted = await AVAudioApplication.requestRecordPermission()
            if granted { beginRecording() }
        }
    }

    func stop() {
        elapsedTimer?.invalidate(); elapsedTimer = nil
        meterTimer?.invalidate(); meterTimer = nil
        recorder?.stop()
        recordingURL = recorder?.url
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        DispatchQueue.main.async { self.recordState = .done }
    }

    func discard() {
        stop()
        if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
        recordingURL = nil
        DispatchQueue.main.async {
            self.elapsedSeconds = 0
            self.meterLevels = .init(repeating: 0.12, count: 30)
            self.recordState = .idle
        }
    }

    // MARK: - Private

    private func beginRecording() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("justin_voice_\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let r = try AVAudioRecorder(url: url, settings: settings)
            r.isMeteringEnabled = true
            r.record()
            recorder = r
        } catch { return }

        DispatchQueue.main.async {
            self.recordState = .recording
            self.elapsedSeconds = 0
        }

        elapsedTimer = .scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.elapsedSeconds += 1 }
        }
        meterTimer = .scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.pollMeters()
        }
    }

    private func pollMeters() {
        guard let r = recorder, r.isRecording else { return }
        r.updateMeters()
        let avg = r.averagePower(forChannel: 0)  // -160...0 dB
        let norm = CGFloat(max(0, (avg + 60) / 60))
        let t = Date().timeIntervalSinceReferenceDate
        let levels: [CGFloat] = (0..<30).map { i in
            let wave = 0.1 * CGFloat(sin(Double(i) * 0.9 + t * 5))
            return min(1, max(0.04, norm + wave + CGFloat.random(in: -0.06...0.06)))
        }
        DispatchQueue.main.async { self.meterLevels = levels }
    }
}

// MARK: - Formatting

extension Int {
    var asTimeCode: String { String(format: "%d:%02d", self / 60, self % 60) }
}
