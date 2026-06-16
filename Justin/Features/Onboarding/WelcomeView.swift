import SwiftUI

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                Wordmark()
                    .scaleEffect(1.6)
                    .padding(.bottom, 8)

                Text("A gift for someone you love —\ntheir voice, when they need it.")
                    .font(.system(.body))
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            NavigationLink(destination: PhoneEntryView()) {
                Text("Get started")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.brandPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.bottom, 52)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack { WelcomeView() }
}
