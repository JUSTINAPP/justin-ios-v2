import SwiftUI

// MARK: - Display models (also used by FeelingCollectionView)

struct ShelfMessage: Identifiable, Hashable {
    let id = UUID()
    let from: String
    let duration: String
    var shelfItem: ShelfItem? = nil  // carries real message ref for playback

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
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

    @State private var currentlyPlaying: ShelfItem?
    @State private var singleFeelingMessage: ShelfMessage?
    @State private var showGiftsNotice = false
    @State private var giftsNoticeCount = 0
    @State private var openNotifications: [GiftOpenNotification] = []
    @State private var showClaimSheet = false

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
            ToolbarItem(placement: .topBarTrailing) {
                Button { showClaimSheet = true } label: {
                    Image(systemName: "ticket")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.ink)
                }
                .accessibilityLabel("Enter gift code")
            }
        }
        .sheet(isPresented: $showClaimSheet) {
            GiftClaimView(onClaimed: {
                guard let id = auth.currentPerson?.id else { return }
                Task { await viewModel.fetch(recipientId: id) }
            })
        }
        .navigationDestination(for: ShelfFeeling.self) { feeling in
            FeelingCollectionView(feeling: feeling)
        }
        .fullScreenCover(item: $currentlyPlaying) { item in
            playerOverlay(
                voicePath: item.message.voiceUrl,
                photoPaths: item.message.photoUrls,
                fromName: item.fromName
            ) { currentlyPlaying = nil }
        }
        .fullScreenCover(item: $singleFeelingMessage) { msg in
            playerOverlay(
                voicePath: msg.shelfItem?.message.voiceUrl,
                photoPaths: msg.shelfItem?.message.photoUrls ?? [],
                fromName: msg.from
            ) { singleFeelingMessage = nil }
        }
        .safeAreaInset(edge: .top) {
            if showGiftsNotice {
                giftsArrivalNotice
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.45), value: showGiftsNotice)
        .safeAreaInset(edge: .top) {
            if let notif = openNotifications.first {
                openNotificationBanner(notif)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.45), value: openNotifications.first?.id)
        .onAppear {
            guard let id = auth.currentPerson?.id else { return }
            Task { await viewModel.fetch(recipientId: id) }

            // Show a warm arrival notice if convergence just attached gifts.
            if auth.pendingGiftsCount > 0 {
                giftsNoticeCount = auth.pendingGiftsCount
                auth.pendingGiftsCount = 0
                withAnimation(.spring(duration: 0.45)) { showGiftsNotice = true }
                Task {
                    try? await Task.sleep(for: .seconds(5))
                    withAnimation(.easeOut(duration: 0.4)) { showGiftsNotice = false }
                }
            }

            // Load "your gift was heard" notifications for sent gifts.
            Task {
                openNotifications = await fetchGiftOpenNotifications(forAuthorId: id)
            }
        }
        .onChange(of: auth.needsShelfRefresh) { _, needsRefresh in
            guard needsRefresh, let id = auth.currentPerson?.id else { return }
            auth.needsShelfRefresh = false
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
                Button { currentlyPlaying = item } label: {
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
                Button { currentlyPlaying = item } label: {
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
    private func playerOverlay(voicePath: String?, photoPaths: [String], fromName: String, onClose: @escaping () -> Void) -> some View {
        KenBurnsPlayerView(voicePath: voicePath, photoPaths: photoPaths, fromName: fromName)
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

    // MARK: - Gifts arrival notice

    private var giftsArrivalNotice: some View {
        Button {
            withAnimation(.easeOut(duration: 0.3)) { showGiftsNotice = false }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 14))
                Text(giftsNoticeCount == 1
                    ? "A gift just landed on your shelf"
                    : "\(giftsNoticeCount) gifts just landed on your shelf"
                )
                .font(.system(.subheadline).weight(.semibold))
                Spacer()
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.6)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.brandPurple, Color.brandRose],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.brandPurple.opacity(0.22), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - "Your gift was heard" notification banner

    private func openNotificationBanner(_ notif: GiftOpenNotification) -> some View {
        Button {
            dismissOpenNotification(notif)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: notif.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.brandRose)

                VStack(alignment: .leading, spacing: 2) {
                    Text(notif.headline)
                        .font(.system(.subheadline).weight(.semibold))
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.leading)
                    if let sub = notif.subtext {
                        Text(sub)
                            .font(.system(.caption))
                            .foregroundStyle(Color.ink.opacity(0.55))
                    }
                }

                Spacer()

                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.ink.opacity(0.35))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.lilacBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.brandRose.opacity(0.22), lineWidth: 1)
                    )
            )
            .shadow(color: Color.brandPurple.opacity(0.09), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func dismissOpenNotification(_ notif: GiftOpenNotification) {
        withAnimation(.easeOut(duration: 0.35)) {
            openNotifications.removeAll { $0.id == notif.id }
        }
        // Fire-and-forget: mark in DB so it doesn't reappear; non-fatal on failure.
        Task { await markGiftOpenNotified(messageId: notif.id) }
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
