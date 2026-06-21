import SwiftUI
import Supabase

struct GivingView: View {
    @EnvironmentObject var auth: AuthService
    @StateObject private var viewModel = GivingViewModel()
    @State private var showRecord = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.cream.ignoresSafeArea()

            contentArea

            // Floating + — ONLY on the Giving tab, bottom-center, above tab bar
            Button { showRecord = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.brandPurple)
                    .clipShape(Circle())
                    .shadow(color: Color.brandPurple.opacity(0.35), radius: 8, x: 0, y: 4)
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Giving")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.cream, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) { Wordmark() }
        }
        .fullScreenCover(isPresented: $showRecord) {
            RecordFlowView()
        }
        .onAppear {
            guard let id = auth.currentPerson?.id else { return }
            Task { await viewModel.fetch(authorId: id) }
        }
        .onChange(of: showRecord) { _, newValue in
            // Refresh after the record sheet dismisses so new gifts appear immediately
            if !newValue, let id = auth.currentPerson?.id {
                Task { await viewModel.fetch(authorId: id) }
            }
        }
    }

    // MARK: - Content area

    @ViewBuilder
    private var contentArea: some View {
        if viewModel.isLoading && viewModel.recipients.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 80)
        } else if viewModel.recipients.isEmpty {
            ZStack {
                givingGhost
                EmptyState(
                    illustration: "illus-hand-flower",
                    heading: "Give someone your voice.",
                    message: "Record a message for someone you love. They'll keep it for whenever they need it."
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 80)
            }
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    Text("Giving")
                        .font(.system(.title2).weight(.semibold))
                        .foregroundColor(.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 4)

                    ForEach(viewModel.recipients) { recipient in
                        NavigationLink(destination: RecipientGivingDetailView(
                            recipient: recipient,
                            onRefresh: {
                                guard let id = auth.currentPerson?.id else { return }
                                Task { await viewModel.fetch(authorId: id) }
                            }
                        )) {
                            recipientCard(recipient)
                        }
                        .buttonStyle(.plain)
                    }

                    // "Start a gift" card — secondary entry point
                    Button { showRecord = true } label: {
                        startGiftCard
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 100) // clear the floating button
            }
        }
    }

    // MARK: - Ghost background (empty state only)

    private var givingGhost: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color.brandPurple)
                        .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 5) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.brandPurple)
                            .frame(width: 80, height: 13)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.brandPurple)
                            .frame(width: 52, height: 11)
                    }

                    Spacer()

                    Circle()
                        .fill(Color.brandPurple)
                        .frame(width: 18, height: 18)
                }
                .padding(16)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .opacity(0.09)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Recipient card (one per person, all their messages aggregated)

    private func recipientCard(_ row: GivingViewModel.RecipientRow) -> some View {
        HStack(spacing: 14) {
            CachedAvatarView(storagePath: row.avatarStoragePath, name: row.recipientName, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text("For \(row.recipientName)")
                    .font(.system(.body).weight(.medium))
                    .foregroundColor(.ink)
                Text("\(row.messageCount) message\(row.messageCount == 1 ? "" : "s")")
                    .font(.system(.subheadline))
                    .foregroundColor(Color.ink.opacity(0.5))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.secondary)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }

    // MARK: - Start gift card

    private var startGiftCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.brandPurple)
            Text("Start a gift for someone")
                .font(.system(.body).weight(.medium))
                .foregroundColor(.brandPurple)
            Spacer()
        }
        .padding(16)
        .background(Color.brandPurple.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.brandPurple.opacity(0.22), lineWidth: 1)
        }
    }
}


#Preview {
    NavigationStack { GivingView() }
        .environmentObject(AuthService())
}
