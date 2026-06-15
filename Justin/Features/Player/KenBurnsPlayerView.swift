import SwiftUI

// MARK: - Slide data

private struct Slide {
    let gradient: [Color]
    let driftEnd: CGSize   // subtle Ken Burns destination offset
}

private let slides: [Slide] = [
    Slide(gradient: [.brandPurple, .brandRose],   driftEnd: CGSize(width:  18, height:  10)),
    Slide(gradient: [.brandRose,   .brandPeach],  driftEnd: CGSize(width: -14, height: -12)),
    Slide(gradient: [.brandDeep,   .brandPurple], driftEnd: CGSize(width:  12, height:  -8)),
    Slide(gradient: [.brandPeach,  .brandRose],   driftEnd: CGSize(width: -16, height:  14)),
    Slide(gradient: [.brandPurple, .brandDeep],   driftEnd: CGSize(width:  10, height:   6)),
]

private let captions = [
    "Happy birthday, Coop.",
    "I'm so proud of the person\nyou're becoming.",
    "Whatever today brings,\nI'm always right here.",
]

// MARK: - Timings

private let kbDuration:     Double = 8.0  // Ken Burns animation length
private let holdDuration:   Double = 6.0  // seconds each photo holds before cross-fade
private let fadeDuration:   Double = 1.5  // cross-fade overlap duration
private let captionHold:    Double = 4.5  // time a caption stays at full opacity
private let captionFadeDur: Double = 0.8  // caption fade in / out duration

// MARK: - KenBurnsPlayerView

struct KenBurnsPlayerView: View {

    // Two-slot cross-fade: A and B alternate as current ("top") / incoming ("bottom").
    // Only the top slot has its opacity wired to topOpacity; the bottom is always opaque
    // underneath, revealing itself as the top fades out.
    @State private var slotAIndex = 0
    @State private var slotBIndex = 1
    @State private var aIsTop     = true
    @State private var topOpacity: Double = 1

    // Ken Burns state per slot
    @State private var scaleA:  CGFloat = 1.0
    @State private var offsetA: CGSize  = .zero
    @State private var scaleB:  CGFloat = 1.0
    @State private var offsetB: CGSize  = .zero

    // Caption
    @State private var captionIndex:   Int     = 0
    @State private var captionOpacity: Double  = 0
    @State private var captionOffsetY: CGFloat = 10

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Photo layers
            ZStack {
                // Bottom slot — the incoming photo, always fully opaque underneath
                photoLayer(
                    slide:  aIsTop ? slides[slotBIndex] : slides[slotAIndex],
                    scale:  aIsTop ? scaleB : scaleA,
                    offset: aIsTop ? offsetB : offsetA
                )
                // Top slot — the current photo, fades to 0 during transition
                photoLayer(
                    slide:  aIsTop ? slides[slotAIndex] : slides[slotBIndex],
                    scale:  aIsTop ? scaleA : scaleB,
                    offset: aIsTop ? offsetA : offsetB
                )
                .opacity(topOpacity)
            }
            .ignoresSafeArea()

            // Gradient scrim — dark at the bottom for text legibility
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, .black.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 340)
            }
            .ignoresSafeArea()

            // Caption + waveform overlay
            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                // TODO: Replace system font with Caveat once added to the Xcode project target:
                //   Font.custom("Caveat", size: 26)
                Text(captions[captionIndex])
                    .font(.system(.title3, design: .rounded).weight(.regular))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .opacity(captionOpacity)
                    .offset(y: captionOffsetY)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 20)

                HStack(alignment: .center, spacing: 14) {
                    Waveform()
                    // TODO: Replace with real elapsed/total time from AVAudioPlayer
                    Text("From Dad · 0:32")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 52)
            }
        }
        .onAppear(perform: start)
    }

    // MARK: - Photo layer

    private func photoLayer(slide: Slide, scale: CGFloat, offset: CGSize) -> some View {
        LinearGradient(
            colors: slide.gradient,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .scaleEffect(scale)
        .offset(offset)
    }

    // MARK: - Startup

    private func start() {
        // Ken Burns only on the first (top) slot at launch; the bottom slot's animation
        // starts when the first cross-fade begins so it enters fresh at scale 1.0.
        animateKenBurns(slot: .a, slide: slides[slotAIndex])
        showCaption()
        scheduleTransition()
    }

    // MARK: - Photo cycling

    private func scheduleTransition() {
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration) { crossfade() }
    }

    private func crossfade() {
        // Start Ken Burns on the incoming (bottom) slot right as the fade begins,
        // so it enters from scale 1.0 and drifts in as it becomes visible.
        if aIsTop {
            animateKenBurns(slot: .b, slide: slides[slotBIndex])
        } else {
            animateKenBurns(slot: .a, slide: slides[slotAIndex])
        }

        withAnimation(.easeInOut(duration: fadeDuration)) { topOpacity = 0 }

        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration) {
            aIsTop.toggle()
            topOpacity = 1  // instant — the new top was already fully visible underneath

            if aIsTop {
                // A is now top; advance B (reserve) to the next upcoming photo
                slotBIndex = (slotAIndex + 1) % slides.count
                resetKenBurns(slot: .b)
            } else {
                slotAIndex = (slotBIndex + 1) % slides.count
                resetKenBurns(slot: .a)
            }
            scheduleTransition()
        }
    }

    // MARK: - Ken Burns helpers

    private enum Slot { case a, b }

    private func animateKenBurns(slot: Slot, slide: Slide) {
        withAnimation(.easeInOut(duration: kbDuration)) {
            switch slot {
            case .a: scaleA = 1.08; offsetA = slide.driftEnd
            case .b: scaleB = 1.08; offsetB = slide.driftEnd
            }
        }
    }

    private func resetKenBurns(slot: Slot) {
        // No animation — slot is off-screen (behind the other slot) when this runs
        switch slot {
        case .a: scaleA = 1.0; offsetA = .zero
        case .b: scaleB = 1.0; offsetB = .zero
        }
    }

    // MARK: - Caption cycling

    private func showCaption() {
        captionOffsetY = 10
        withAnimation(.easeOut(duration: captionFadeDur)) {
            captionOpacity = 1
            captionOffsetY = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + captionHold) {
            withAnimation(.easeIn(duration: captionFadeDur)) { captionOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + captionFadeDur) {
                captionIndex = (captionIndex + 1) % captions.count
                showCaption()
            }
        }
    }
}

// MARK: - Waveform

// TODO: When AVAudioPlayer is wired up, drive WaveBar heights from
//   player.isMeteringEnabled + player.averagePower(forChannel:) samples
//   instead of the built-in idle animation.

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

    // Deterministic heights and speeds per bar position — no random() so values are
    // stable across re-renders.
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
