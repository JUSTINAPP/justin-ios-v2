import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthService
    @State private var showSignOutConfirm = false

    var body: some View {
        List {
            Section {
                Text("Profile")
                    .font(.system(.title2).weight(.semibold))
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listSectionSeparator(.hidden)

            // Profile header
            Section {
                HStack(spacing: 14) {
                    InitialsAvatar(name: auth.currentPerson?.displayName ?? "You", size: 60)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(auth.currentPerson?.displayName ?? "You")
                            .font(.title3.weight(.semibold))
                        if let phone = auth.currentPerson?.phone {
                            Text(phone)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // Settings rows
            Section {
                NavigationLink(destination: AccountView()) {
                    Text("Account")
                }
                NavigationLink(destination: NotificationsView()) {
                    Text("Notifications")
                }
                NavigationLink(destination: SafetyPrivacyView()) {
                    Text("Safety & privacy")
                }
            }

            // Sign out — destructive, confirmation required
            Section {
                Button(role: .destructive) {
                    showSignOutConfirm = true
                } label: {
                    Text("Sign out")
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .scrollClearance()
        .toolbar {
            ToolbarItem(placement: .principal) { Wordmark() }
        }
        .alert("Sign out?", isPresented: $showSignOutConfirm) {
            Button("Sign out", role: .destructive) {
                Task { await auth.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need your phone number to sign back in.")
        }
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .environmentObject(AuthService())
}
