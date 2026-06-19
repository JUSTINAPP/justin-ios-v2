import SwiftUI
import UIKit
import Supabase

// MARK: - KenBurnsPlayerView
//
// Calm player. Three modes detected from message content:
//   voiceOnly — gradient + avatar + waveform + controls
//   words     — same + typed caption below avatar
//   photos    — still images, soft cross-fade only (NO pan/zoom/scale)
//
// Photo layer constraints (never regress):
//   • GeometryReader pins images to exact screen bounds
//   • .clipped() — nothing bleeds outside the frame
//   • allowsHitTesting(false) on every photo layer — touches pass through
//   • X close button lives in .overlay above the entire ZStack

struct KenBurnsPlayerView: View {
    var voicePath:     String?   = nil
    var photoPaths:    [String]  = []
    var fromName:      String    = ""
    var localImages:   [UIImage] = []
    var showControls:  Bool      = true
    var caption:       String?   = nil
    var avatarURL:     URL?      = nil
    /// Local file URL for preview before upload. Takes priority over voicePath.
    var localAudioURL:       URL?      = nil
    /// Shows a large centre play/pause button (preview mode). Also triggers loadMedia.
    var showCenterPlayButton: Bool     = false

    @Environment(\.dismiss) private var dismiss
    @StateObject private var audio = AudioPlayer()

    // Load / playback
    @State private var hasStarted    = false
    @State private var isLoading     = false
    @State private var loadedImages: [UIImage] = []
    @State private var playbackEnded = false

    // Cross-fade slideshow (no pan/zoom/scale)
    @State private var displayIndex:    Int    = 0      // currently shown photo
    @State private var fadingIn:        Int?   = nil    // next photo fading in behind the front
    @State private var fadeOutOpacity:  Double = 1.0    // front photo opacity: 1 → 0 during fade
    @State private var slideshowStarted = false
    @State private var slideshowTask:   Task<Void, Never>? = nil

    // Background drift
    @State private var gradientPhase = false

    private static let fadeDuration: Double = 0.7

    private var activeImages: [UIImage] { !localImages.isEmpty ? localImages : loadedImages }

    private enum PlayerMode { case voiceOnly, words, photos }
    private var mode: PlayerMode {
        if !photoPaths.isEmpty || !localImages.isEmpty { return .photos }
        if let c = caption, !c.isEmpty { return .words }
        return .voiceOnly
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            gradientBackground
            if mode == .voiceOnly {
                voiceOnlyContent
            } else {
                if mode == .photos { photoLayer } else { avatarLayer }
                bottomScrim
                if showCenterPlayButton && !playbackEnded { centerPlayButtonView }
                VStack {
                    Spacer()
                    if let c = caption, !c.isEmpty { wordsView(c) }
                    if showControls { controlsBar }
                }
                if playbackEnded && showControls { endedOverlay }
            }
        }
        .overlay(alignment: .topLeading) {
            if showControls { closeButton }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                gradientPhase = true
            }
            guard !hasStarted else { return }
            hasStarted = true
            if showControls || showCenterPlayButton { Task { await loadMedia() } }
        }
        .onDisappear {
            slideshowTask?.cancel()
            audio.stop()
        }
        .onChange(of: audio.didFinishPlaying) { _, finished in
            guard finished else { return }
            slideshowTask?.cancel()
            playbackEnded = true
            print("[Player] ended")
        }
    }

    // MARK: - Gradient background
    //
    // Warm horizontal sunrise: deep aubergine at top, soft coral glow at bottom.
    // The gradient band breathes slowly up and down (10 s loop) via startPoint/endPoint.
    // Photos cover this completely; voice-only and words modes show it in full.

    private var gradientBackground: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hex: "2b1d3a"), location: 0),
                .init(color: Color(hex: "4a2c47"), location: 0.28),
                .init(color: Color(hex: "8a4a5a"), location: 0.62),
                .init(color: Color(hex: "d98a6a"), location: 1),
            ],
            startPoint: gradientPhase ? .top : UnitPoint(x: 0.5, y: -0.12),
            endPoint:   gradientPhase ? .bottom : UnitPoint(x: 0.5, y: 1.12)
        )
        .ignoresSafeArea()
    }

    // MARK: - Photo layer (constrained, non-interactive, cross-fade only)
    //
    // Two layers in a ZStack:
    //   • back  — the NEXT photo at opacity 1 (revealed as front fades out)
    //   • front — the CURRENT photo, opacity animates 1 → 0 during fade
    // GeometryReader provides exact screen bounds; .clipped() enforces them.
    // No pan, zoom, or scale at any point.

    @ViewBuilder
    private var photoLayer: some View {
        let imgs = activeImages
        if !imgs.isEmpty {
            GeometryReader { geo in
                ZStack {
                    if let nextIdx = fadingIn {
                        photoImage(imgs[nextIdx % imgs.count], size: geo.size)
                    }
                    photoImage(imgs[displayIndex % imgs.count], size: geo.size)
                        .opacity(fadeOutOpacity)
                }
                .onAppear {
                    print("[Player] photo layer laid out, screen size = \(geo.size)")
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private func photoImage(_ img: UIImage, size: CGSize) -> some View {
        Image(uiImage: img)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipped()
            .allowsHitTesting(false)
    }

    // MARK: - Avatar layer

    private var avatarLayer: some View {
        VStack {
            Spacer()
            PersonAvatarView(
                name: fromName.isEmpty ? "Me" : fromName,
                size: 120,
                remoteAvatarURL: avatarURL
            )
            Spacer()
            Spacer()
        }
    }

    // MARK: - Voice-only layout
    //
    // Three distinct vertical zones — avatar never overlaps the play button.
    //   Zone 1 (top)    — sender avatar + "from Name" label
    //   Zone 2 (centre) — large waveform + large play/pause button
    //   Zone 3 (bottom) — elapsed / total time

    @ViewBuilder
    private var voiceOnlyContent: some View {
        VStack(spacing: 0) {

            // Zone 1 — Avatar
            VStack(spacing: 10) {
                PersonAvatarView(
                    name: fromName.isEmpty ? "Me" : fromName,
                    size: 64,
                    remoteAvatarURL: avatarURL
                )
                .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 1.5))

                if !fromName.isEmpty {
                    Text("from \(fromName)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.60))
                }
            }
            .padding(.top, 104) // clear status bar + close button

            Spacer()

            // Zone 2 — Waveform + Play
            VStack(spacing: 28) {
                VoiceWaveform(isPlaying: audio.isPlaying)
                    .frame(maxWidth: 280)

                largePlayButton
            }

            Spacer()

            // Zone 3 — Time
            if audio.duration > 0 {
                Text("\(audio.currentTime.asTimeCode) / \(audio.duration.asTimeCode)")
                    .font(.system(size: 14, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                Color.clear.frame(height: 18)
            }
        }
        .padding(.bottom, 52)
    }

    // Large white-circle play / pause / replay button for voice-only mode.
    // Handles idle, playing, and ended states — no separate ended overlay needed.

    private var largePlayButton: some View {
        Button { onPlayTap() } label: {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.92))
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 4)

                Group {
                    if playbackEnded {
                        Image(systemName: "arrow.circlepath")
                            .font(.system(size: 26, weight: .semibold))
                    } else if audio.isPlaying {
                        Image(systemName: "pause")
                            .font(.system(size: 26, weight: .semibold))
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .offset(x: 3) // optical centre for play triangle
                    }
                }
                .foregroundStyle(Color.ink)
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.45 : 1)
    }

    // MARK: - Centre play button (preview mode — photos/words only)

    private var centerPlayButtonView: some View {
        Button { onPlayTap() } label: {
            Image(systemName: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.25), radius: 12)
        }
    }

    // MARK: - Bottom scrim

    private var bottomScrim: some View {
        VStack {
            Spacer()
            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 300)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Words
    //
    // Anchored at the bottom of the screen, growing upward.
    // Capped at 180pt so very long text never reaches the X close button.
    // Scrollable within the bounded area when content overflows.

    private func wordsView(_ text: String) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            Text(text)
                .font(.custom("Caveat", size: 22))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: 180)
        .padding(.horizontal, 32)
        .padding(.bottom, 12)
    }

    // MARK: - Controls bar

    private var controlsBar: some View {
        HStack(alignment: .center, spacing: 14) {
            Button { onPlayTap() } label: {
                Image(systemName: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(isLoading ? .white.opacity(0.4) : .white)
            }
            .disabled(isLoading)

            Waveform(isPlaying: audio.isPlaying)

            Spacer()

            if audio.duration > 0 {
                Text("\(audio.currentTime.asTimeCode) / \(audio.duration.asTimeCode)")
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
            } else if isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.75)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 52)
    }

    // MARK: - Ended overlay

    private var endedOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                if !fromName.isEmpty {
                    Text("From \(fromName)")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Button { replayFromStart() } label: {
                    Label("Play again", systemImage: "arrow.circlepath")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 13)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
            .padding(.bottom, 64)
        }
    }

    // MARK: - Close button (topmost via .overlay — always tappable)

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(11)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .padding(.top, 56)
        .padding(.leading, 20)
    }

    // MARK: - Load media

    private func loadMedia() async {
        let modeLabel: String
        switch mode {
        case .voiceOnly: modeLabel = "voiceOnly"
        case .words:     modeLabel = "words"
        case .photos:    modeLabel = "photos"
        }
        print("[Player] mode = \(modeLabel)")

        isLoading = true
        defer { isLoading = false }

        // Load all photos in parallel, preserving order
        if mode == .photos && localImages.isEmpty && !photoPaths.isEmpty {
            var ordered = Array(repeating: UIImage?.none, count: photoPaths.count)
            await withTaskGroup(of: (Int, UIImage?).self) { group in
                for (i, path) in photoPaths.enumerated() {
                    group.addTask {
                        do {
                            let url = try await supabase.storage
                                .from("photos").createSignedURL(path: path, expiresIn: 3600)
                            let (data, _) = try await URLSession.shared.data(from: url)
                            return (i, UIImage(data: data))
                        } catch {
                            print("[Player] photo \(i) load failed: \(error)")
                            return (i, nil)
                        }
                    }
                }
                for await (i, img) in group { ordered[i] = img }
            }
            loadedImages = ordered.compactMap { $0 }
            print("[Player] loaded \(loadedImages.count) photos")
        }

        // Load audio — local file for preview, or remote storage path for saved messages
        if let localURL = localAudioURL {
            audio.load(url: localURL)
            print("[Player] audio ready (local) duration=\(audio.duration)")
        } else if let path = voicePath {
            do {
                let url = try await supabase.storage
                    .from("voice").createSignedURL(path: path, expiresIn: 3600)
                await audio.loadRemote(url)
                print("[Player] audio ready duration=\(audio.duration)")
            } catch {
                print("[Player] voice URL failed: \(error)")
            }
        }
    }

    // MARK: - Play / Pause

    private func onPlayTap() {
        if playbackEnded { replayFromStart(); return }
        audio.playPause()
        if audio.isPlaying {
            print("[Player] audio playing")
            if mode == .photos { startSlideshow() }
        }
    }

    // MARK: - Replay

    private func replayFromStart() {
        playbackEnded = false
        slideshowTask?.cancel()
        slideshowTask    = nil
        displayIndex     = 0
        fadingIn         = nil
        fadeOutOpacity   = 1.0
        slideshowStarted = false
        audio.playPause()
        print("[Player] audio playing")
        if mode == .photos { startSlideshow() }
    }

    // MARK: - Cross-fade slideshow (opacity only — no pan, zoom, or scale)

    private func startSlideshow() {
        let imgs = activeImages
        guard imgs.count > 1 else { return }
        guard !slideshowStarted else { return }
        slideshowStarted = true

        let audioDuration = audio.duration
        let perPhoto    = audioDuration > 0
            ? max(3.0, audioDuration / Double(imgs.count))
            : 5.0
        let holdDuration = max(0.5, perPhoto - Self.fadeDuration)
        let fadeNs       = UInt64(Self.fadeDuration * 1_000_000_000)

        slideshowTask = Task { @MainActor in
            var current = 0
            while !Task.isCancelled {
                // Pause-aware hold: elapsed time only ticks while audio is playing
                var elapsed = 0.0
                while elapsed < holdDuration {
                    guard !Task.isCancelled else { return }
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms
                    if audio.isPlaying { elapsed += 0.05 }
                }
                guard !Task.isCancelled else { return }

                let next = current + 1
                if next >= imgs.count { break }   // hold on last photo; don't loop

                // Reveal next photo underneath the front layer, then fade front out
                fadingIn = next
                withAnimation(.easeInOut(duration: Self.fadeDuration)) {
                    fadeOutOpacity = 0
                }
                try? await Task.sleep(nanoseconds: fadeNs)
                guard !Task.isCancelled else { return }

                // Atomic swap: SwiftUI batches these into one render pass (no flash)
                displayIndex   = next
                fadingIn       = nil
                fadeOutOpacity = 1.0

                current = next
            }
        }
    }
}

// MARK: - Waveform (animates only while playing)

private struct Waveform: View {
    var isPlaying: Bool = false
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<12, id: \.self) { WaveBar(index: $0, isPlaying: isPlaying) }
        }
    }
}

private struct WaveBar: View {
    let index:     Int
    let isPlaying: Bool
    @State private var active = false

    private static let lo: [CGFloat] = [0.20, 0.35, 0.15, 0.40, 0.25, 0.30, 0.18, 0.38, 0.22, 0.32, 0.17, 0.28]
    private static let hi: [CGFloat] = [0.70, 0.90, 0.85, 0.65, 1.00, 0.75, 0.95, 0.60, 0.88, 0.72, 1.00, 0.80]
    private static let sp: [Double]  = [0.35, 0.42, 0.28, 0.38, 0.45, 0.31, 0.40, 0.36, 0.29, 0.43, 0.33, 0.41]

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white.opacity(0.65))
            .frame(width: 3, height: (active ? Self.hi[index] : Self.lo[index]) * 24 + 4)
            .animation(
                active
                    ? .easeInOut(duration: Self.sp[index])
                          .repeatForever(autoreverses: true)
                          .delay(Double(index) * 0.06)
                    : .easeOut(duration: 0.3),
                value: active
            )
            .onChange(of: isPlaying) { _, playing in active = playing }
            .onAppear { active = isPlaying }
    }
}

// MARK: - Voice-only large waveform (22 bars, reacts to audio.isPlaying)

private struct VoiceWaveform: View {
    var isPlaying: Bool = false
    var body: some View {
        HStack(alignment: .center, spacing: 3.5) {
            ForEach(0..<22, id: \.self) { VoiceWaveBar(index: $0, isPlaying: isPlaying) }
        }
        .frame(height: 64)
    }
}

private struct VoiceWaveBar: View {
    let index:     Int
    let isPlaying: Bool
    @State private var active = false

    private static let lo: [CGFloat] = [
        0.12, 0.28, 0.10, 0.40, 0.18, 0.34, 0.10, 0.48, 0.16, 0.30,
        0.22, 0.14, 0.36, 0.10, 0.42, 0.24, 0.12, 0.38, 0.20, 0.28, 0.14, 0.22,
    ]
    private static let hi: [CGFloat] = [
        0.50, 0.88, 0.72, 0.65, 1.00, 0.80, 0.95, 0.58, 0.86, 0.70,
        0.92, 0.68, 0.96, 0.55, 0.80, 0.90, 0.82, 0.62, 0.92, 0.72, 0.86, 0.68,
    ]
    private static let sp: [Double] = [
        0.50, 0.62, 0.42, 0.55, 0.68, 0.45, 0.58, 0.48, 0.40, 0.60,
        0.46, 0.55, 0.38, 0.64, 0.48, 0.56, 0.42, 0.50, 0.58, 0.44, 0.52, 0.46,
    ]

    var body: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(.white.opacity(active ? 0.88 : 0.38))
            .frame(width: 3.5, height: (active ? Self.hi[index] : Self.lo[index]) * 64 + 3)
            .animation(
                active
                    ? .easeInOut(duration: Self.sp[index])
                          .repeatForever(autoreverses: true)
                          .delay(Double(index) * 0.04)
                    : .easeOut(duration: 0.4),
                value: active
            )
            .onChange(of: isPlaying) { _, playing in active = playing }
            .onAppear { active = isPlaying }
    }
}

// MARK: - Preview

#Preview {
    KenBurnsPlayerView(fromName: "Mum")
}
