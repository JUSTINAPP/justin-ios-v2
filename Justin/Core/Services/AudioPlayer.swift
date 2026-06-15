import Foundation
import Combine
import AVFoundation

final class AudioPlayer: NSObject, ObservableObject {

    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?

    // MARK: - Public API

    func load(url: URL) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            duration = player?.duration ?? 0
        } catch {
            print("[AudioPlayer] load failed: \(error)")
        }
    }

    func playPause() {
        guard let p = player else { return }
        if p.isPlaying {
            p.pause()
            isPlaying = false
            progressTimer?.invalidate()
        } else {
            p.play()
            isPlaying = true
            startProgressTimer()
        }
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
        isPlaying = false
        currentTime = 0
        progressTimer?.invalidate()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Private

    private func startProgressTimer() {
        progressTimer = .scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let p = self.player else { return }
            DispatchQueue.main.async {
                self.currentTime = p.currentTime
                // Detect natural playback completion without a delegate
                if !p.isPlaying && self.isPlaying {
                    self.isPlaying = false
                    self.currentTime = 0
                    self.progressTimer?.invalidate()
                }
            }
        }
    }
}

// MARK: - Formatting

extension TimeInterval {
    var asTimeCode: String { Int(self).asTimeCode }
}
