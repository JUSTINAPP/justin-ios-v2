import SwiftUI

/// A LinearGradient that continuously rotates between a horizontal and a vertical
/// orientation — a full 90° arc over an 8-second sinusoidal cycle.
///
/// WHY TimelineView: LinearGradient is not Animatable. Its startPoint/endPoint
/// are constructor parameters, not modifier-based properties SwiftUI can interpolate.
/// TimelineView computes the gradient position directly from the display clock each
/// frame, bypassing that limitation entirely.
///
/// WHY the old version was invisible: it only moved start/end by 0.2 units over
/// 28 seconds (~1°/sec peak, with easeInOut making it near-motionless for most of the
/// cycle). The gradient barely changed angle in any reasonable viewing window.
///
/// FIX: cosine oscillation over 8 s, full 90° rotation. Peak angular velocity is
/// ~45°/sec at the midpoint — clearly visible within 1–2 seconds of looking.
struct DriftingGradient: View {
    let colors: [Color]

    var body: some View {
        TimelineView(.animation) { context in
            let t = driftPhase(at: context.date)
            LinearGradient(
                colors: colors,
                // t=0 → horizontal (start left-centre, end right-centre)
                // t=1 → vertical   (start top-centre,  end bottom-centre)
                startPoint: UnitPoint(x: lerp(0.0, 0.5, t), y: lerp(0.5, 0.0, t)),
                endPoint:   UnitPoint(x: lerp(1.0, 0.5, t), y: lerp(0.5, 1.0, t))
            )
        }
    }

    /// Smooth cosine oscillation 0 → 1 → 0 over `cycle` seconds.
    /// Velocity is zero at both extremes (no abrupt snap at reversal) and
    /// peaks at the midpoint — naturally perceivable motion at all viewing times.
    private func driftPhase(at date: Date) -> Double {
        let cycle = 8.0
        let raw   = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
        return (1 - cos(raw / cycle * 2 * .pi)) / 2
    }

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }
}

#Preview {
    VStack(spacing: 12) {
        DriftingGradient(colors: [.brandPurple, .brandRose])
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        DriftingGradient(colors: [Color(hex: "3E3270"), Color(hex: "7B6BA8")])
            .frame(height: 108)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        DriftingGradient(colors: [Color(hex: "B87090"), Color(hex: "C8855A")])
            .frame(height: 108)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    .padding()
}
