import SwiftUI

struct DeleteAccountView: View {
    @State private var confirmText = ""
    @State private var scheduledForDeletion: Bool

    init(scheduledForDeletion: Bool = false) {
        _scheduledForDeletion = State(initialValue: scheduledForDeletion)
    }

    var body: some View {
        Group {
            if scheduledForDeletion {
                scheduledView
            } else {
                warningView
            }
        }
        .navigationTitle("Delete your account")
        .navigationBarTitleDisplayMode(.inline)
        .scrollClearance()
    }

    // MARK: - Warning screen

    private var warningView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // What happens
                VStack(alignment: .leading, spacing: 12) {
                    Text("What happens when you delete")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundColor(.brandDeep)

                    VStack(alignment: .leading, spacing: 16) {
                        explanationRow(
                            icon: "xmark.circle.fill",
                            iconColor: .red.opacity(0.65),
                            text: "Your account, your shelf, and any messages you haven't sent yet will be deleted."
                        )
                        explanationRow(
                            icon: "heart.fill",
                            iconColor: .brandRose,
                            text: "Gifts you've already given will stay with the people who received them. Those are their keepsakes to keep."
                        )
                    }
                    .padding(16)
                    .background(Color(.secondarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Divider()

                // Confirm deletion
                VStack(alignment: .leading, spacing: 12) {
                    Text("To confirm, type DELETE below.")
                        .font(.system(.subheadline))
                        .foregroundColor(.secondary)

                    TextField("", text: $confirmText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Color(.secondarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    confirmText == "DELETE" ? Color.red.opacity(0.45) : Color.clear,
                                    lineWidth: 1.5
                                )
                        )

                    Button {
                        // TODO(supabase): Schedule account deletion
                        // 1. POST to rpc/schedule_account_deletion
                        //    → sets deletion_scheduled_at = now() + interval '30 days' on the user row
                        // 2. Call supabase.auth.signOut() to sign the user out immediately
                        // Restore path: any successful sign-in within 30 days should cancel the deletion.
                        //    Implement as an Edge Function or Auth hook that checks deletion_scheduled_at
                        //    on sign-in and nulls it out if still within the window.
                        scheduledForDeletion = true
                    } label: {
                        Text("Delete my account")
                            .font(.system(.body, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(confirmText == "DELETE" ? Color.red : Color.red.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .animation(.easeInOut(duration: 0.12), value: confirmText == "DELETE")
                    }
                    .disabled(confirmText != "DELETE")
                }
            }
            .padding(20)
        }
    }

    // MARK: - Scheduled deletion screen

    private var scheduledView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Spacer().frame(height: 36)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 52, weight: .light))
                    .foregroundColor(.brandPurple.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)

                Text("Your account is scheduled for deletion in 30 days.")
                    .font(.system(.title3, weight: .semibold))

                Text("Changed your mind? Just sign back in within 30 days and everything will be restored.")
                    .font(.system(.body))
                    .foregroundColor(.secondary)
            }
            .padding(20)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func explanationRow(icon: String, iconColor: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(.body))
                .padding(.top, 2)
            Text(text)
                .font(.system(.body))
        }
    }
}

#Preview("Warning") {
    NavigationStack { DeleteAccountView() }
}

#Preview("Scheduled") {
    NavigationStack { DeleteAccountView(scheduledForDeletion: true) }
}
