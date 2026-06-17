import SwiftUI

/// Reusable empty-state layout: illustration, heading, body, and an optional
/// gentle action link. Sits centred inside whatever container calls it.
struct EmptyState: View {
    let illustration: String
    let heading: String
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(illustration)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 164, maxHeight: 164)
                .opacity(0.82)
                .padding(.bottom, 32)

            VStack(spacing: 12) {
                Text(heading)
                    .font(.system(.title3, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.ink)

                Text(message)
                    .font(.system(.body))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.secondary)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 40)

            if let label = actionLabel, let action {
                Button(action: action) {
                    Text(label)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(Color.brandPurple)
                }
                .padding(.top, 28)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyState(
        illustration: "illus-self-hug",
        heading: "Your shelf is ready.",
        message: "When someone leaves you a message, it'll live here, ready for whenever you need it.",
        actionLabel: "Make a message for someone you love",
        action: {}
    )
}
