import SwiftUI

struct WelcomeView: View {
    var body: some View {
        ZStack {
            SunriseGradientBackground()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    HStack(spacing: 0) {
                        Text("just").foregroundStyle(.white)
                        Text("in").foregroundStyle(Color.brandRose)
                    }
                    .font(.system(size: 40, weight: .bold))
                    .padding(.bottom, 4)

                    Text("A gift for someone you love —\ntheir voice, when they need it.")
                        .font(.system(.body))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

                Spacer()

                NavigationLink(destination: PhoneEntryView()) {
                    Text("Get started")
                        .font(.system(.body, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.bottom, 52)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack { WelcomeView() }
}
