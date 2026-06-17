import SwiftUI

// MARK: - Display models (also used by FeelingCollectionView)

struct ShelfMessage: Identifiable, Hashable {
    let id = UUID()
    let from: String
    let duration: String
}

struct ShelfFeeling: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let messages: [ShelfMessage]
    var cardColors: [Color] = [.brandPurple, .brandDeep]
    var illustration: String? = nil

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

// MARK: - ShelfView

struct ShelfView: View {
    var switchToGiving: (() -> Void)? = nil

    @EnvironmentObject var auth: AuthService
    @StateObject private var viewModel = ShelfViewModel()

    @State private var showPlayer = false
    @State private var singleFeelingMessage: ShelfMessage?

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.sections.hasAnyContent {
                contentScrollView
            } else {
                ZStack {
                    shelfGhost
                    EmptyState(
                        illustration: "illus-self-hug",
                        heading: "Your shelf is ready.",
                        message: "When someone leaves you a message, it'll live here, ready for whenever you need it.",
                        actionLabel: "Make a message for someone you love",
                        action: { switchToGiving?() }
                    )
                    .padding(.horizontal, 20)
                }
            }
        }
        .navigationTitle("Your shelf")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Wordmark() }
        }
        .navigationDestination(for: ShelfFeeling.self) { feeling in
            FeelingCollectionView(feeling: feeling)
        }
        .fullScreenCover(isPresented: $showPlayer) {
            playerOverlay { showPlayer = false }
        }
        .fullScreenCover(item: $singleFeelingMessage) { _ in
            playerOverlay { singleFeelingMessage = nil }
        }
        .onAppear {
            guard let id = auth.currentPerson?.id else { return }
            Task { await viewModel.fetch(recipientId: id) }
        }
    }

    // MARK: - Content scroll view

    private var contentScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                Text("Your shelf")
                    .font(.system(.title2).weight(.semibold))
                    .padding(.bottom, 4)

                // MARK: Ready for you now
                if !viewModel.sections.readyNow.isEmpty {
                    sectionHeader("Ready for you now")
                    readyNowCards
                }

                // MARK: Open when…
                if !viewModel.sections.feelingGroups.isEmpty {
                    sectionHeader("Open when\u{2026}")
                    VStack(spacing: 12) {
                        ForEach(viewModel.sections.feelingGroups) { feeling in
                            feelingCard(feeling)
                        }
                    }
                }

                // MARK: Always here
                if !viewModel.sections.alwaysHere.isEmpty {
                    sectionHeader("Always here")
                    alwaysHereCards
                }

                // MARK: Arriving later
                if !viewModel.sections.arrivingLater.isEmpty {
                    sectionHeader("Arriving later")
                    arrivingLaterRows
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .scrollClearance()
    }

    // MARK: - Ready now cards

    private var readyNowCards: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.sections.readyNow) { item in
                Button { showPlayer = true } label: {
                    ZStack(alignment: .bottomLeading) {
                        DriftingGradient(colors: [.brandPurple, .brandRose])

                        VStack(alignment: .leading, spacing: 3) {
                            Text("From \(item.fromName)")
                                .font(.system(.headline).weight(.semibold))
                                .foregroundColor(.white)
                            Text(readySubtitle(item.message))
                                .font(.system(.subheadline))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(16)
                    }
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func readySubtitle(_ message: Message) -> String {
        switch message.releaseType {
        case .now:
            return "just arrived"
        case .date:
            guard let date = message.releaseDate else { return "just arrived" }
            let days = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
            return days <= 0 ? "arrived today" : "arrived \(days) day\(days == 1 ? "" : "s") ago"
        case .feeling, .always:
            return "just arrived"
        }
    }

    // MARK: - Feeling card (adaptive tap)

    @ViewBuilder
    private func feelingCard(_ feeling: ShelfFeeling) -> some View {
        if feeling.messages.count == 1 {
            Button { singleFeelingMessage = feeling.messages[0] } label: {
                feelingCardContent(feeling)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(value: feeling) {
                feelingCardContent(feeling)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func feelingCardContent(_ feeling: ShelfFeeling) -> some View {
        ZStack(alignment: .bottomLeading) {
            DriftingGradient(colors: feeling.cardColors)

            if let name = feeling.illustration {
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 78, height: 78)
                    .opacity(0.22)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 10)
                    .padding(.trailing, 10)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Open when")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                Text(feeling.label)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundColor(.white)
                if feeling.messages.count > 1 {
                    Text("\(feeling.messages.count) messages")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            .padding(14)
        }
        .frame(height: 108)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Always here cards

    private var alwaysHereCards: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.sections.alwaysHere) { item in
                Button { showPlayer = true } label: {
                    ZStack(alignment: .leading) {
                        DriftingGradient(colors: [.brandDeep, Color(hex: "261A4A")])

                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Always here for you")
                                    .font(.system(.subheadline).weight(.medium))
                                    .foregroundColor(.white)
                                Text("From \(item.fromName)")
                                    .font(.system(.caption))
                                    .foregroundColor(.white.opacity(0.65))
                            }
                            Spacer()
                            Image("illus-hug-arms-white")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                                .opacity(0.32)
                        }
                        .padding(16)
                    }
                    .frame(height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Arriving later rows

    private var arrivingLaterRows: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.sections.arrivingLater) { item in
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("From \(item.fromName)")
                            .font(.system(.body))
                        Text(arrivingLaterSubtitle(item.message))
                            .font(.system(.caption))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 14)
                .opacity(0.55)
            }
        }
    }

    private func arrivingLaterSubtitle(_ message: Message) -> String {
        guard let date = message.releaseDate else { return "arriving soon" }
        return "opens " + DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
    }

    // MARK: - Player overlay

    @ViewBuilder
    private func playerOverlay(onClose: @escaping () -> Void) -> some View {
        KenBurnsPlayerView()
            .overlay(alignment: .topLeading) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(11)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(.top, 56)
                .padding(.leading, 20)
            }
    }

    // MARK: - Ghost background (empty state only)

    private var shelfGhost: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Hero card shape
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [.brandPurple, .brandRose],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(height: 180)

            // Feeling card shapes
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(
                    colors: [Color(hex: "3E3270"), Color(hex: "7B6BA8")],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(height: 108)

            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(
                    colors: [Color(hex: "B87090"), Color(hex: "C8855A")],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(height: 108)

            // Always-here card shape
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(
                    colors: [.brandDeep, Color(hex: "261A4A")],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(height: 88)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .opacity(0.07)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Section header

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.caption, design: .default).weight(.semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .kerning(0.6)
    }
}

#Preview {
    NavigationStack { ShelfView() }
        .environmentObject(AuthService())
}
