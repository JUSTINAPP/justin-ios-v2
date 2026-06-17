import SwiftUI
import UIKit
import Supabase

// MARK: - Slide data

private struct FallbackSlide {
    let colors: [Color]
    let drift:  CGSize
}

private let fallbackSlides: [FallbackSlide] = [
    .init(colors: [.brandPurple, .brandRose],   drift: CGSize(width:  16, height:   9)),
    .init(colors: [.brandRose,   .brandPeach],  drift: CGSize(width: -12, height: -10)),
    .init(colors: [.brandDeep,   .brandPurple], drift: CGSize(width:  10, height:  -8)),
    .init(colors: [.brandPeach,  .brandRose],   drift: CGSize(width: -14, height:  12)),
    .init(colors: [.brandPurple, .brandDeep],   drift: CGSize(width:   8, height:   6)),
]

// Each photo drift direction; wraps modulo photo count.
private let kbDrifts: [CGSize] = [
    CGSize(width:  16, height:   9),
    CGSize(width: -12, height: -10),
    CGSize(width:  10, height:  -8),
    CGSize(width: -14, height:  12),
    CGSize(width:   8, height:   6),
]

private let kbAnimDuration:    Double = 8.0  // Ken Burns zoom/pan duration
private let crossFadeDuration: Double = 1.2  // cross-fade between photos
private let minPhotoDuration:  Double = 5.0  // minimum seconds per photo

// MARK: - KenBurnsPlayerView

struct KenBurnsPlayerView: View {
    var voicePath:   String?  = nil
    var photoPaths:  [String] = []
    var fromName:    String   = ""
    /// Pre-loaded local images (pre-upload preview). Skips storage fetch when set.
    var localImages: [UIImage] = []
    /// When false, skips audio + controls (visual-only background for preview step).
    var showControls: Bool = true

    @Environment(\.dismiss) private var dismiss
    @StateObject private var audio = AudioPlayer()
    @State private var loadedImages: [UIImage] = []

    // --- Two-layer slideshow state ---
    // The ZStack has a back layer (next photo, no KB) and a front layer (current photo + KB).
    // To transition: show back, fade front out, then swap.
    @State private var frontIndex: Int     = 0    // index shown in the front layer
    @State private var backIndex:  Int     = 0    // index shown in the back layer during fade
    @State private var isFading:   Bool    = false // true while cross-fade is in progress
    @State private var frontOpacity: Double = 1.0  // animates 1 → 0 during cross-fade

    // Ken Burns applied to the front layer only; reset instantly on each photo swap.
    @State private var kbScale:  CGFloat = 1.0
    @State private var kbOffset: CGSize  = .zero

    // Cancellable slideshow driver
    @State private var slideshowTask: Task<Void, Never>? = nil
    @State private var playbackEnded: Bool = false

    private var activeImages: [UIImage] { !localImages.isEmpty ? localImages : loadedImages }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            photoBackground.ignoresSafeArea()
            bottomScrim

            if showControls {
                if playbackEnded {
                    endedOverlay
                } else {
                    playbackControls
                }
            }
        }
        // Close button lives in .overlay — it is painted AFTER and OUTSIDE the ZStack,
        // so nothing inside the ZStack can intercept its taps regardless of state.
        .overlay(alignment: .topLeading) {
            if showControls {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(11)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(.top, 56)
                .padding(.leading, 20)
            }
        }
        .onAppear {
            if showControls {
                Task { await loadAndPlay() }
            } else {
                // Visual-only preview: run slideshow with default timing, no audio.
                beginSlideshow(photoDuration: minPhotoDuration * 2)
            }
        }
        .onDisappear {
            slideshowTask?.cancel()
            audio.stop()
        }
        .onChange(of: audio.didFinishPlaying) { _, finished in
            guard finished else { return }
            slideshowTask?.cancel()
            playbackEnded = true
        }
    }

    // MARK: - Photo background

    @ViewBuilder
    private var photoBackground: some View {
        let imgs = activeImages
        ZStack {
            // Back layer: the NEXT photo/gradient, shown at scale 1 during cross-fade.
            if isFading {
                slide(index: backIndex, images: imgs)
            }
            // Front layer: the CURRENT photo/gradient with Ken Burns, fades out on transition.
            slide(index: frontIndex, images: imgs)
                .scaleEffect(kbScale)
                .offset(kbOffset)
                .opacity(frontOpacity)
        }
    }

    @ViewBuilder
    private func slide(index: Int, images: [UIImage]) -> some View {
        if images.isEmpty {
            let s = fallbackSlides[index % fallbackSlides.count]
            LinearGradient(colors: s.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        } else {
            Image(uiImage: images[index % images.count])
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        }
    }

    // MARK: - UI overlays

    private var bottomScrim: some View {
        VStack {
            Spacer()
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                .frame(height: 280)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var playbackControls: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            HStack(alignment: .center, spacing: 14) {
                if voicePath != nil {
                    Button { audio.playPause() } label: {
                        Image(systemName: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                }
                Waveform()
                Text(bottomLabel)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 52)
        }
    }

    private var endedOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                if !fromName.isEmpty {
                    Text("From \(fromName)")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                Button { replay() } label: {
                    Label("Play again", systemImage: "arrow.circlepath")
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 13)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
            .padding(.bottom, 64)
        }
        .allowsHitTesting(true)
    }

    private var bottomLabel: String {
        guard voicePath != nil else { return fromName.isEmpty ? "" : fromName }
        if audio.duration > 0 {
            let t = "\(audio.currentTime.asTimeCode) / \(audio.duration.asTimeCode)"
            return fromName.isEmpty ? t : "From \(fromName) \u{00B7} \(t)"
        }
        return fromName.isEmpty ? "Loading\u{2026}" : "From \(fromName) \u{00B7} Loading\u{2026}"
    }

    // MARK: - Load and play

    private func loadAndPlay() async {
        // Load photos (skip if using pre-loaded local images)
        if localImages.isEmpty && !photoPaths.isEmpty {
            var imgs: [UIImage] = []
            for path in photoPaths {
                do {
                    let url = try await supabase.storage
                        .from("photos").createSignedURL(path: path, expiresIn: 3600)
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let img = UIImage(data: data) { imgs.append(img) }
                } catch {
                    print("[Player] photo load failed \(path): \(error)")
                }
            }
            if !imgs.isEmpty {
                loadedImages = imgs
                print("[Player] loaded \(imgs.count) photos")
            }
        }

        // Load audio
        guard let path = voicePath else {
            // No audio path — just run the slideshow visually.
            beginSlideshow(photoDuration: minPhotoDuration * 2)
            return
        }
        do {
            let signedURL = try await supabase.storage
                .from("voice").createSignedURL(path: path, expiresIn: 3600)
            await audio.loadRemote(signedURL)
        } catch {
            print("[Player] voice signed URL failed: \(error)")
            return
        }
        guard audio.duration > 0 else {
            print("[Player] audio duration is 0 — skipping playback")
            return
        }

        // Calculate per-photo duration so photos fill the audio timeline.
        let photoCount = max(activeImages.count, 1)
        let photoDuration = max(minPhotoDuration, audio.duration / Double(photoCount))

        // Start slideshow and audio together.
        beginSlideshow(photoDuration: photoDuration)
        audio.playPause()
    }

    // MARK: - Slideshow

    /// Resets all slideshow state and starts a new cancellable Task-driven cycle.
    private func beginSlideshow(photoDuration: Double) {
        slideshowTask?.cancel()
        slideshowTask = nil

        // Reset visual state (no animation — instant reset before new KB starts).
        frontIndex   = 0
        backIndex    = 0
        isFading     = false
        frontOpacity = 1.0
        kbScale      = 1.0
        kbOffset     = .zero

        startKenBurns(at: 0)

        let count = slideCount
        guard count > 1 else { return } // Single image: just KB forever, no cycling needed.

        let holdNs     = UInt64(max(0.1, photoDuration - crossFadeDuration) * 1_000_000_000)
        let crossFadeNs = UInt64(crossFadeDuration * 1_000_000_000)

        slideshowTask = Task { @MainActor in
            var current = 0
            while !Task.isCancelled {
                // Hold the current photo for (photoDuration - crossFade).
                try? await Task.sleep(nanoseconds: holdNs)
                guard !Task.isCancelled else { break }

                // Prepare the back layer with the next photo.
                let next = (current + 1) % count
                backIndex = next
                isFading  = true

                // Fade the front out — the back layer is already showing the next photo at scale 1.
                withAnimation(.easeInOut(duration: crossFadeDuration)) {
                    frontOpacity = 0
                }

                try? await Task.sleep(nanoseconds: crossFadeNs)
                guard !Task.isCancelled else { break }

                // Swap: next photo becomes the new front; reset KB instantly then start fresh.
                // The back was showing next at scale 1.0 — front takes over at scale 1.0, no jump.
                frontIndex   = next
                isFading     = false
                frontOpacity = 1.0
                kbScale      = 1.0
                kbOffset     = .zero
                startKenBurns(at: next)

                current = next
            }
        }
    }

    private func startKenBurns(at index: Int) {
        let imgs  = activeImages
        let drift = imgs.isEmpty
            ? fallbackSlides[index % fallbackSlides.count].drift
            : kbDrifts[index % kbDrifts.count]
        withAnimation(.easeInOut(duration: kbAnimDuration)) {
            kbScale  = 1.08
            kbOffset = drift
        }
    }

    private var slideCount: Int {
        let imgs = activeImages
        return imgs.isEmpty ? fallbackSlides.count : imgs.count
    }

    // MARK: - Replay

    private func replay() {
        playbackEnded = false
        let photoCount    = max(activeImages.count, 1)
        let photoDuration = audio.duration > 0
            ? max(minPhotoDuration, audio.duration / Double(photoCount))
            : minPhotoDuration * 2
        beginSlideshow(photoDuration: photoDuration)
        audio.playPause()
    }
}

// MARK: - Waveform

private struct Waveform: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<12, id: \.self) { WaveBar(index: $0) }
        }
    }
}

private struct WaveBar: View {
    let index: Int
    @State private var active = false

    private static let lo: [CGFloat] = [0.20, 0.35, 0.15, 0.40, 0.25, 0.30, 0.18, 0.38, 0.22, 0.32, 0.17, 0.28]
    private static let hi: [CGFloat] = [0.70, 0.90, 0.85, 0.65, 1.00, 0.75, 0.95, 0.60, 0.88, 0.72, 1.00, 0.80]
    private static let sp: [Double]  = [0.35, 0.42, 0.28, 0.38, 0.45, 0.31, 0.40, 0.36, 0.29, 0.43, 0.33, 0.41]

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white.opacity(0.65))
            .frame(width: 3, height: (active ? Self.hi[index] : Self.lo[index]) * 24 + 4)
            .animation(
                .easeInOut(duration: Self.sp[index])
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.06),
                value: active
            )
            .onAppear { active = true }
    }
}

// MARK: - Preview

#Preview {
    KenBurnsPlayerView()
}
