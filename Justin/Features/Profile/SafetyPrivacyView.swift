import SwiftUI

struct SafetyPrivacyView: View {
    @State private var circleMembers: [String] = ["Mum", "Em", "Jordan"]
    @State private var blockedPeople: [String] = ["Alex"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // Intro
                Text("Justin is built to be a safe, private place. Here's how we protect you.")
                    .font(.system(.body))
                    .foregroundColor(.secondary)

                // Your privacy
                contentBlock(
                    heading: "Your privacy",
                    body: "Your messages are private. Only you and the person you send them to can see them. Justin does not read, analyse, or share what's inside your messages. We never sell your data, and there are no ads."
                )

                // Who can reach you
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeading("Who can reach you")
                    Text("You decide who's in your circle. Nobody can add a message to your shelf without your agreement. You can block or report anyone at any time.")
                        .font(.system(.body))
                    VStack(spacing: 8) {
                        navActionRow("Manage your circle", destination: ManageCircleView(people: $circleMembers, blockedPeople: $blockedPeople))
                        navActionRow("Blocked people", destination: BlockedPeopleView(blockedPeople: $blockedPeople))
                    }
                }

                // What Justin does and doesn't do
                contentBlock(
                    heading: "What Justin does and doesn't do",
                    body: "When you open a message, the person who made it is gently let know, so they have the chance to reach out. This is never automatic, and Justin never contacts anyone else on your behalf. Justin does not detect crises, alert authorities, or share your location. The people who love you are the support. Justin simply helps their voice reach you."
                )

                // If you're going through a hard time
                VStack(alignment: .leading, spacing: 10) {
                    Text("If you're going through a hard time")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(.brandDeep)
                    Text("Justin isn't a crisis service, but help is always there if you need it.")
                        .font(.system(.subheadline))
                        .foregroundColor(.secondary)
                    HStack(spacing: 0) {
                        Text("In Australia, call Lifeline any time: ")
                            .font(.system(.subheadline))
                            .foregroundColor(.secondary)
                        Link("13 11 14", destination: URL(string: "tel:131114")!)
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundColor(.brandPurple)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.brandPurple.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Your control
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeading("Your control")
                    VStack(spacing: 8) {
                        navActionRow(
                            "Remove a person",
                            subtitle: "This also deletes any unsent messages they have for you",
                            destination: ManageCircleView(people: $circleMembers, blockedPeople: $blockedPeople)
                        )
                        navActionRow(
                            "Delete your account and data",
                            isDestructive: true,
                            destination: DeleteAccountView()
                        )
                    }
                }
            }
            // frame(maxWidth:) lets the ScrollView measure content height correctly
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .scrollClearance()
        .navigationTitle("Safety & Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeading(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, weight: .semibold))
            .foregroundColor(.brandDeep)
    }

    @ViewBuilder
    private func contentBlock(heading: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeading(heading)
            Text(body)
                .font(.system(.body))
        }
    }

    /// Navigating row — wraps in a NavigationLink.
    @ViewBuilder
    private func navActionRow<D: View>(
        _ title: String,
        subtitle: String? = nil,
        isDestructive: Bool = false,
        destination: D
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.body))
                        .foregroundColor(isDestructive ? .red : .primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(.caption))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(.systemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { SafetyPrivacyView() }
}
