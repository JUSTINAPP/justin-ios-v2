import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthService
    // TODO: move hasSeenIntro flag to user profile backend once available
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false

    var body: some View {
        Group {
            switch auth.state {
            case .loading:
                Color(.systemBackground).ignoresSafeArea()
            case .signedIn:
                if hasSeenIntro {
                    MainTabView()
                } else {
                    IntroView(onDone: { hasSeenIntro = true })
                }
            default:
                OnboardingView()
            }
        }
        .animation(.easeInOut(duration: 0.4), value: auth.state)
        // Post-signup: prompt new users to claim a gift by code.
        // Presented on top of whatever screen is active (MainTabView or IntroView).
        .sheet(isPresented: $auth.showClaimCodePrompt) {
            GiftClaimView(onClaimed: { auth.needsShelfRefresh = true })
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
}
