import SwiftUI

/// A LinearGradient whose angle drifts slowly — a 28-second loop (14 s forward,
/// 14 s back) driven by the display clock.
///
/// WHY TimelineView instead of @State + .animation(value:):
/// LinearGradient is not Animatable. Its startPoint/endPoint are constructor
/// parameters, not modifier-based properties, so SwiftUI cannot interpolate them
/// when the view body re-evaluates. The view just snaps. TimelineView bypasses
/// this by computing the gradient position directly from the current time each
/// frame, giving true continuous drift with no SwiftUI animation involvement.
struct DriftingGradient: View {
    let colors: [Color]

    var body: some View {
        TimelineView(.animation) { context in
            let t = driftPhase(at: context.date)
            LinearGradient(
                colors: colors,
                startPoint: UnitPoint(
                    x: lerp(0.0, 0.2, t),
                    y: lerp(0.2, 0.0, t)
                ),
                endPoint: UnitPoint(
                    x: lerp(1.0, 0.8, t),
                    y: lerp(0.8, 1.0, t)
                )
            )
        }
    }

    /// Triangle wave (0→1→0 over 28 s) with easeInOut smoothing.
    /// All DriftingGradient instances share the same clock so they drift in sync.
    private func driftPhase(at date: Date) -> Double {
        let cycle = 28.0
        let half  = cycle / 2
        let raw   = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
        let tri   = raw < half ? raw / half : (cycle - raw) / half   // 0→1→0
        return easeInOut(tri)
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    private func easeInOut(_ t: Double) -> Double {
        t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}

#Preview {
    DriftingGradient(colors: [.brandPurple, .brandRose])
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
}
