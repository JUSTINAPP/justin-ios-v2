import SwiftUI

/// Persistent brand wordmark: "just" in ink, "in" in rose.
/// Uses HStack(spacing: 0) instead of the deprecated Text + Text operator.
struct Wordmark: View {
    var fontSize: CGFloat = 19

    var body: some View {
        HStack(spacing: 0) {
            Text("just").foregroundStyle(Color.ink)
            Text("in").foregroundStyle(Color.brandRose)
        }
        .font(.system(size: fontSize, weight: .bold))
    }
}

#Preview {
    Wordmark()
        .padding()
}
