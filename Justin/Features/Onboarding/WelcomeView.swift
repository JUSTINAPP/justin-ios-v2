import SwiftUI

struct WelcomeView: View {
    @State private var gradientPhase = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.lilacBg,
                    Color.brandPurple.opacity(0.30),
                    Color.brandRose.opacity(0.20),
                ],
                startPoint: gradientPhase ? .topLeading : .bottomLeading,
                endPoint:   gradientPhase ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    HStack(spacing: 0) {
                        Text("just").foregroundStyle(Color.ink)
                        Text("in").foregroundStyle(Color.brandRose)
                    }
                    .font(.system(size: 40, weight: .bold))
                    .padding(.bottom, 4)

                    Text("A gift for someone you love —\ntheir voice, when they need it.")
                        .font(.system(.body))
                        .foregroundStyle(Color.ink.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

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
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                gradientPhase = true
            }
        }
    }
}

#Preview {
    NavigationStack { WelcomeView() }
}
