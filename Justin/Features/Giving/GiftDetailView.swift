import SwiftUI

struct GiftDetailView: View {
    let recipientName: String

    var body: some View {
        VStack(spacing: 16) {
            InitialsAvatar(name: recipientName, size: 72)
                .padding(.top, 40)
            Text("Gift for \(recipientName)")
                .font(.title2.weight(.semibold))
            Text("Message list coming soon.")
                .font(.body)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .navigationTitle("For \(recipientName)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { GiftDetailView(recipientName: "Em") }
}
