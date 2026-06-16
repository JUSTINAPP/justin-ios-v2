import SwiftUI

/// A LinearGradient that barely breathes — its angle drifts imperceptibly
/// over ~14 seconds, looping forever. Use on brand-gradient cards to give
/// a quiet sense of life without drawing attention to itself.
struct DriftingGradient: View {
    let colors: [Color]

    @State private var drifted = false

    var body: some View {
        LinearGradient(
            colors: colors,
            startPoint: drifted ? UnitPoint(x: 0.1, y: 0.0) : UnitPoint(x: 0.0, y: 0.1),
            endPoint:   drifted ? UnitPoint(x: 0.9, y: 1.0) : UnitPoint(x: 1.0, y: 0.9)
        )
        .animation(
            .easeInOut(duration: 14).repeatForever(autoreverses: true),
            value: drifted
        )
        .onAppear { drifted = true }
    }
}

#Preview {
    DriftingGradient(colors: [.brandPurple, .brandRose])
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
