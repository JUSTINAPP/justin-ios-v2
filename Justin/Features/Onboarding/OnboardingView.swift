import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        ZStack {
            if case .awaitingCode(let phone) = auth.state {
                OTPEntryView(phone: phone)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            } else if auth.state == .awaitingName {
                NameEntryView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            } else {
                NavigationStack {
                    WelcomeView()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: auth.state)
    }
}
