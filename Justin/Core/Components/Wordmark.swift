import SwiftUI

/// Persistent brand wordmark: "just" in ink, "in" in rose.
struct Wordmark: View {
    var body: some View {
        (Text("just").foregroundStyle(Color.ink) + Text("in").foregroundStyle(Color.brandRose))
            .font(.system(size: 19, weight: .bold))
    }
}

#Preview {
    Wordmark()
        .padding()
}
