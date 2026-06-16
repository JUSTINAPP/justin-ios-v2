import SwiftUI

struct NotificationsView: View {
    @State private var allowNotifications = true
    @State private var messageOpened = true
    @State private var newGiftOrMessage = true
    @State private var scheduledDelivery = true
    @State private var quietHours = true

    var body: some View {
        List {
            // Master toggle
            Section {
                Toggle("Allow notifications", isOn: $allowNotifications)
                    .tint(.brandPurple)
            }

            // Per-event toggles
            Section {
                Toggle("When someone opens a message you sent", isOn: $messageOpened)
                    .tint(.brandPurple)
                Toggle("When you receive a new gift or message", isOn: $newGiftOrMessage)
                    .tint(.brandPurple)
                Toggle("When a message you scheduled is about to be delivered", isOn: $scheduledDelivery)
                    .tint(.brandPurple)
            }
            .disabled(!allowNotifications)
            .animation(.easeInOut(duration: 0.2), value: allowNotifications)

            // Quiet hours
            Section {
                Toggle(isOn: $quietHours) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quiet hours")
                        Text("No notifications late at night")
                            .font(.system(.caption))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.brandPurple)
            }
            .disabled(!allowNotifications)
            .animation(.easeInOut(duration: 0.2), value: allowNotifications)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .scrollClearance()
    }
}

#Preview {
    NavigationStack { NotificationsView() }
}
