import SwiftUI

// The gift is shared via the GIVER's own messaging app (Messages, WhatsApp, etc.) from
// their own number — so it arrives as a message from someone the recipient already knows,
// not from an unknown shortcode or stranger. This defeats the scam/spam feel that ruins
// the moment. The optional phone number is the identity anchor: when the recipient verifies
// that number on Justin signup, deferred deep linking converges the pending gift to their
// shelf automatically. Justin never sends the SMS itself.

struct InviteShareView: View {
    let onDone: () -> Void
    @EnvironmentObject var model: RecordFlowModel

    @State private var shareMessage = ""

    // Placeholder link — replaced by a real per-gift share token from Supabase once
    // the messages table generates one on insert (e.g. messages.share_token → slug).
    private let placeholderLink = "justinapp.com.au/g/abc123"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // Heading + explanation
                VStack(alignment: .leading, spacing: 10) {
                    Text("Send \(model.recipientName) this gift")
                        .font(.system(.title2, weight: .semibold))

                    Text("Share this with \(model.recipientName) yourself, so it comes from you — not a stranger. They'll be able to hear it straight away.")
                        .font(.system(.body))
                        .foregroundColor(.secondary)
                }

                // Editable pre-written message
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your message")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .kerning(0.5)

                    TextEditor(text: $shareMessage)
                        .scrollContentBackground(.hidden)
                        .font(.system(.body))
                        .frame(minHeight: 110, maxHeight: 160)
                        .padding(12)
                        .background(Color(.secondarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Share button — opens the system share sheet using the giver's own apps
                ShareLink(item: shareMessage) {
                    Label("Share with \(model.recipientName)", systemImage: "square.and.arrow.up")
                        .font(.system(.body, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.brandPurple)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Reassurance
                Text("We've saved this gift. You can also share it later from the Giving tab.")
                    .font(.system(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                // Done — dismisses the whole record flow back to the Giving tab
                Button(action: onDone) {
                    Text("Done")
                        .font(.system(.body))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.systemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 36)
            .padding(.bottom, 100)
        }
        .navigationTitle("Share")
        .navigationBarTitleDisplayMode(.inline)
        .scrollClearance()
        .onAppear {
            guard shareMessage.isEmpty else { return }
            // TODO(auth): replace "Jonas" with the authenticated user's first name from
            //             supabase.auth.session?.user.userMetadata["first_name"]
            shareMessage = "Hi \(model.recipientName), it's Jonas — I made you something \u{1F49B}\n\(placeholderLink)"
        }
    }
}

#Preview {
    let model = RecordFlowModel()
    model.recipientName = "Em"
    model.isNewRecipient = true
    return NavigationStack {
        InviteShareView(onDone: {})
            .environmentObject(model)
    }
}
