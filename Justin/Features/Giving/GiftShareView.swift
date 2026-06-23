import SwiftUI

struct GiftShareView: View {
    let recipientName: String
    let shareToken: String?
    let onDone: () -> Void
    /// When true (post-creation record flow), hides the back arrow so the user
    /// can't navigate back into the completed preview. Both exits call onDone().
    var exitToHome: Bool = false

    @EnvironmentObject var auth: AuthService

    @State private var shareMessage = ""
    @State private var didCopy = false

    private var linkString: String {
        guard let token = shareToken else { return "https://justinapp.com.au/g/…" }
        return "https://justinapp.com.au/g/\(token)"
    }

    private var senderFirstName: String {
        let full = auth.currentPerson?.displayName ?? ""
        return full.components(separatedBy: " ").first.flatMap { $0.isEmpty ? nil : $0 } ?? "me"
    }

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {

                    heading

                    copyLinkButton

                    messageEditor

                    ShareLink(item: shareMessage) {
                        Label("Share with \(recipientName)", systemImage: "square.and.arrow.up")
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.brandPurple)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Text("You can share this again any time from the Giving tab.")
                        .font(.system(.subheadline))
                        .foregroundStyle(Color.ink.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    doneButton
                }
                .padding(.horizontal, 28)
                .padding(.top, 36)
                .padding(.bottom, 80)
            }
        }
        .navigationTitle("Share gift")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.cream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        // When shown after gift creation, suppress back navigation into the
        // completed preview and replace with a Done button that exits to home.
        .navigationBarBackButtonHidden(exitToHome)
        .toolbar {
            if exitToHome {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { onDone() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.brandPurple)
                }
            }
        }
        .onAppear {
            debugLog("[ShareDebug] GiftShareView.onAppear")
            debugLog("[ShareDebug]   shareToken received: \(shareToken ?? "nil")")
            debugLog("[ShareDebug]   recipientName:       \(recipientName)")
            debugLog("[ShareDebug]   linkString:          \(linkString)")
            composeMessageIfNeeded()
        }
        .onChange(of: shareToken) { oldToken, newToken in
            debugLog("[ShareDebug] GiftShareView.onChange(shareToken): \(oldToken ?? "nil") → \(newToken ?? "nil")")
        }
        .onChange(of: shareToken) { _, newToken in
            guard let token = newToken else { return }
            let newLink = "https://justinapp.com.au/g/\(token)"
            shareMessage = shareMessage.replacingOccurrences(
                of: "https://justinapp.com.au/g/…", with: newLink
            )
        }
    }

    // MARK: - Sections

    private var heading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Send it to \(recipientName)")
                .font(.system(.title2, weight: .semibold))
                .foregroundStyle(Color.ink)

            Text("Share this from your own number so it arrives from someone \(recipientName) already knows.")
                .font(.system(.subheadline))
                .foregroundStyle(Color.ink.opacity(0.55))
        }
    }

    // Compact copy-link affordance — replaces the full URL box.
    // The link is already visible inside the editable message; showing the raw URL
    // a second time is redundant. This gives a quick "just the link" copy action.
    private var copyLinkButton: some View {
        Button {
            UIPasteboard.general.string = linkString
            withAnimation(.easeInOut(duration: 0.15)) { didCopy = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeInOut(duration: 0.15)) { didCopy = false }
            }
        } label: {
            Label(
                didCopy ? "Link copied" : "Copy link",
                systemImage: didCopy ? "checkmark.circle.fill" : "link"
            )
            .font(.system(.subheadline, weight: .medium))
            .foregroundStyle(didCopy ? Color.brandPurple : Color.ink.opacity(0.6))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(didCopy ? Color.brandPurple.opacity(0.10) : Color.ink.opacity(0.06))
            .clipShape(Capsule())
            .animation(.easeInOut(duration: 0.15), value: didCopy)
        }
    }

    private var messageEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Your message")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(Color.ink.opacity(0.4))
                    .textCase(.uppercase)
                    .kerning(0.5)
                Spacer()
                Label("edit freely", systemImage: "pencil")
                    .font(.system(.caption))
                    .foregroundStyle(Color.brandPurple.opacity(0.65))
            }

            TextEditor(text: $shareMessage)
                .scrollContentBackground(.hidden)
                .font(.system(.body))
                .foregroundStyle(Color.ink)
                .frame(minHeight: 80, maxHeight: 160)
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.brandPurple.opacity(0.15), lineWidth: 1)
                }
        }
    }

    private var doneButton: some View {
        Button(action: onDone) {
            Text("Done")
                .font(.system(.body, weight: .medium))
                .foregroundStyle(Color.brandPurple)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.brandPurple.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.brandPurple.opacity(0.2), lineWidth: 1)
                }
        }
    }

    // MARK: - Message composition

    private func composeMessageIfNeeded() {
        guard shareMessage.isEmpty else { return }
        shareMessage = "Hi \(recipientName), it's \(senderFirstName) — I left you a little something. Have a listen 💛\n\(linkString)"
    }
}

#Preview {
    NavigationStack {
        GiftShareView(
            recipientName: "Em",
            shareToken: "550e8400-e29b-41d4-a716-446655440000",
            onDone: {}
        )
    }
    .environmentObject(AuthService())
}
