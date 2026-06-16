import SwiftUI

struct ProfileView: View {

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
                    InitialsAvatar(name: "Jonas", size: 60)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Jonas")
                            .font(.title3.weight(.semibold))
                        Text("+1 555 123 4567")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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

            // Sign out — destructive, no chevron
            Section {
                Button(role: .destructive) {
                    // no-op for now
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
    }
}

#Preview {
    NavigationStack { ProfileView() }
}
