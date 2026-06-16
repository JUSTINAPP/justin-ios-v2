import SwiftUI

// MARK: - Local data models

struct ShelfMessage: Identifiable, Hashable {
    let id = UUID()
    let from: String
    let duration: String
}

struct ShelfFeeling: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let messages: [ShelfMessage]
    // Visual treatment — Color is not Hashable, so Hashable is implemented manually below
    var cardColors: [Color] = [.brandPurple, .brandDeep]
    var illustration: String? = nil

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

// MARK: - ShelfView

struct ShelfView: View {
    @State private var showPlayer = false
    @State private var singleFeelingMessage: ShelfMessage?

    private let feelings: [ShelfFeeling] = [
        ShelfFeeling(
            label: "you can't sleep",
            messages: [
                ShelfMessage(from: "Mum", duration: "0:42"),
                ShelfMessage(from: "Em", duration: "1:05"),
                ShelfMessage(from: "Dad", duration: "0:38"),
            ],
            cardColors: [Color(hex: "3E3270"), Color(hex: "7B6BA8")],
            illustration: "illus-self-hug-white"
        ),
        ShelfFeeling(
            label: "you miss home",
            messages: [
                ShelfMessage(from: "Mum", duration: "1:12"),
            ],
            cardColors: [Color(hex: "B87090"), Color(hex: "C8855A")],
            illustration: "illus-hands-face-white"
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                Text("Your shelf")
                    .font(.system(.title2).weight(.semibold))
                    .padding(.bottom, 4)

                // MARK: Ready for you now
                sectionHeader("Ready for you now")
                heroCard

                // MARK: Open when…
                sectionHeader("Open when\u{2026}")
                VStack(spacing: 12) {
                    ForEach(feelings) { feeling in
                        feelingCard(feeling)
                    }
                }

                // MARK: Always here
                sectionHeader("Always here")
                alwaysHereCard

                // MARK: Arriving later
                sectionHeader("Arriving later")
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("From Dad")
                            .font(.system(.body))
                        Text("opens on your birthday")
                            .font(.system(.caption))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 14)
                .opacity(0.55)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .scrollClearance()
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
    }

    // MARK: - Hero card

    private var heroCard: some View {
        Button { showPlayer = true } label: {
            ZStack(alignment: .bottomLeading) {
                DriftingGradient(colors: [.brandPurple, .brandRose])

                VStack(alignment: .leading, spacing: 3) {
                    Text("From Mum")
                        .font(.system(.headline).weight(.semibold))
                        .foregroundColor(.white)
                    Text("just arrived")
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

    // MARK: - Feeling card (adaptive tap behaviour)

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

            // Ghost illustration — top-trailing
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

            // Text — bottom-leading
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

    // MARK: - Always here card

    private var alwaysHereCard: some View {
        ZStack(alignment: .leading) {
            DriftingGradient(colors: [.brandDeep, Color(hex: "261A4A")])

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("For your hardest moments")
                        .font(.system(.subheadline).weight(.medium))
                        .foregroundColor(.white)
                    Text("From Em")
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
}
