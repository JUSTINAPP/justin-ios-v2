import SwiftUI

struct GiftShareView: View {
    let recipientName: String
    let shareToken: String?
    let onDone: () -> Void

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

                    linkBox

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
        .onAppear { composeMessageIfNeeded() }
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

    private var linkBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gift link")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(Color.ink.opacity(0.4))
                .textCase(.uppercase)
                .kerning(0.5)

            HStack(spacing: 10) {
                Text(linkString)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(Color.brandPurple)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    UIPasteboard.general.string = linkString
                    withAnimation(.easeInOut(duration: 0.15)) { didCopy = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeInOut(duration: 0.15)) { didCopy = false }
                    }
                } label: {
                    Text(didCopy ? "Copied" : "Copy")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(didCopy ? Color.brandPurple : Color.ink.opacity(0.55))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            didCopy
                                ? Color.brandPurple.opacity(0.12)
                                : Color.ink.opacity(0.07)
                        )
                        .clipShape(Capsule())
                        .animation(.easeInOut(duration: 0.15), value: didCopy)
                }
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.brandPurple.opacity(0.18), lineWidth: 1)
            }
        }
    }

    private var messageEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your message")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(Color.ink.opacity(0.4))
                .textCase(.uppercase)
                .kerning(0.5)

            TextEditor(text: $shareMessage)
                .scrollContentBackground(.hidden)
                .font(.system(.body))
                .foregroundStyle(Color.ink)
                .frame(minHeight: 120, maxHeight: 200)
                .padding(12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.ink.opacity(0.08), lineWidth: 1)
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
        shareMessage = "Hi \(recipientName), it's \(senderFirstName) — I made you something.\n\nHave a listen: \(linkString)"
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
