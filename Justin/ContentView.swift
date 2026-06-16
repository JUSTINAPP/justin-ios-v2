import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        Group {
            switch auth.state {
            case .loading:
                Color(.systemBackground).ignoresSafeArea()
            case .signedIn:
                MainTabView()
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
