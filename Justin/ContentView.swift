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
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService())
}
