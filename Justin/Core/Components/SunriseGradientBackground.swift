import SwiftUI

/// Warm dark sunrise gradient — deep aubergine top → coral/peach bottom —
/// with a gentle 10 s vertical breathing drift. Used as the shared background
/// for the voice player, the welcome screen, and any loading state that needs
/// a warm, immersive feel.
///
/// Usage:
///   ZStack {
///       SunriseGradientBackground()
///       // content on top
///   }
///   .ignoresSafeArea()
struct SunriseGradientBackground: View {
    @State private var phase = false

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hex: "2b1d3a"), location: 0),
                .init(color: Color(hex: "4a2c47"), location: 0.28),
                .init(color: Color(hex: "8a4a5a"), location: 0.62),
                .init(color: Color(hex: "d98a6a"), location: 1),
            ],
            startPoint: phase ? .top : UnitPoint(x: 0.5, y: -0.12),
            endPoint:   phase ? .bottom : UnitPoint(x: 0.5, y: 1.12)
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                phase = true
            }
        }
    }
}

#Preview {
    ZStack {
        SunriseGradientBackground()
        VStack(spacing: 12) {
            Text("just").font(.system(size: 40, weight: .bold)).foregroundStyle(.white)
            Text("A gift for someone you love").foregroundStyle(.white.opacity(0.7))
        }
    }
    .ignoresSafeArea()
}
