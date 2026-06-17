import Foundation
import Combine
import AVFoundation

final class AudioPlayer: NSObject, ObservableObject {

    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var didFinishPlaying = false

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?

    // MARK: - Public API

    /// Load from a local file URL (e.g. temp directory recording).
    func load(url: URL) {
        do {
            try configureSession()
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            duration = player?.duration ?? 0
        } catch {
            print("[AudioPlayer] load failed: \(error)")
        }
    }

    /// Download audio from a remote signed URL, then load from the downloaded Data.
    /// AVAudioPlayer cannot play from a remote URL directly — it needs local data.
    func loadRemote(_ url: URL) async {
        print("[AudioPlayer] downloading from signed URL")
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            print("[AudioPlayer] downloaded \(data.count) bytes")
            try configureSession()
            player = try AVAudioPlayer(data: data)
            player?.prepareToPlay()
            duration = player?.duration ?? 0
        } catch {
            print("[AudioPlayer] failed: \(error)")
        }
    }

    func playPause() {
        guard let p = player else { return }
        if p.isPlaying {
            p.pause()
            isPlaying = false
            progressTimer?.invalidate()
        } else {
            didFinishPlaying = false
            p.play()
            isPlaying = true
            print("[AudioPlayer] playing")
            startProgressTimer()
        }
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
        isPlaying = false
        currentTime = 0
        didFinishPlaying = false
        progressTimer?.invalidate()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Private

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    private func startProgressTimer() {
        progressTimer = .scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let p = self.player else { return }
            DispatchQueue.main.async {
                self.currentTime = p.currentTime
                // Detect natural playback completion without a delegate
                if !p.isPlaying && self.isPlaying {
                    self.isPlaying = false
                    self.currentTime = 0
                    p.currentTime = 0   // reset so replay() starts from the beginning
                    self.progressTimer?.invalidate()
                    self.didFinishPlaying = true
                }
            }
        }
    }
}

// MARK: - Formatting

extension TimeInterval {
    var asTimeCode: String { Int(self).asTimeCode }
}
