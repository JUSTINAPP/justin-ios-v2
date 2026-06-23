import SwiftUI
import Supabase

// Navigation destinations within the People tab.
private enum PeopleNavDest: Hashable {
    case detail(PeopleEntry)
    case receivedGift(giftId: UUID?, name: String)
    case givingGift(giftId: UUID?, name: String, personId: UUID?)
}

struct PeopleView: View {
    @EnvironmentObject var auth: AuthService
    @StateObject private var viewModel = PeopleViewModel()
    @State private var showAddPerson     = false
    @State private var recordingForPerson: PeopleEntry? = nil

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.people.isEmpty {
                ScrollView {
                    VStack(spacing: 10) {
                        // ── Coming up strip ──────────────────────────────────
                        if !viewModel.upcomingOccasions.isEmpty {
                            comingUpStrip
                                .padding(.bottom, 6)
                        }

                        Text("People")
                            .font(.system(.title2).weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 4)

                        ForEach(viewModel.people) { person in
                            personRow(person)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }
                .scrollClearance()
            } else {
                ZStack {
                    peopleGhost
                    EmptyState(
                        illustration: "illus-waving-hand",
                        heading: "Your people will appear here.",
                        message: "Add the people you love, and keep the moments that matter to them close.",
                        actionLabel: "Add someone",
                        action: { showAddPerson = true }
                    )
                    .padding(.horizontal, 20)
                }
            }
        }
        .background(Color.lilacBg.ignoresSafeArea())
        .navigationTitle("People")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.lilacBg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) { Wordmark() }
            ToolbarItem(placement: .primaryAction) {
                Button { showAddPerson = true } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.brandPurple)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationDestination(for: PeopleNavDest.self) { dest in
            switch dest {
            case .detail(let person):
                PersonDetailView(person: person)
            case .receivedGift(let giftId, let name):
                ReceivedGiftDetailView(giftId: giftId, fromName: name)
            case .givingGift(let giftId, let name, let personId):
                GiftDetailView(giftId: giftId, recipientName: name, recipientPersonId: personId)
            }
        }
        .sheet(isPresented: $showAddPerson) {
            AddPersonView(isPresented: $showAddPerson) { entry in
                viewModel.people.append(entry)
                viewModel.people.sort { $0.name < $1.name }
                if let id = auth.currentPerson?.id {
                    Task { await viewModel.fetch(currentPersonId: id) }
                }
            }
        }
        .onAppear {
            guard let id = auth.currentPerson?.id else { return }
            Task { await viewModel.fetch(currentPersonId: id) }
        }
        // Re-fetch when block/unblock fires (same signal as shelf refresh)
        // so the blocked badge appears/disappears without navigating away.
        .onChange(of: auth.needsShelfRefresh) { _, needsRefresh in
            guard needsRefresh, let id = auth.currentPerson?.id else { return }
            Task { await viewModel.fetch(currentPersonId: id) }
        }
        .fullScreenCover(item: $recordingForPerson) { person in
            RecordFlowView(prefillRecipientName: person.name, prefillRecipientId: person.id)
        }
    }

    // MARK: - Ghost background (empty state only)

    private var peopleGhost: some View {
        VStack(spacing: 18) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color.brandPurple)
                        .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 7) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary)
                            .frame(width: 88, height: 13)
                        HStack(spacing: 6) {
                            Capsule()
                                .fill(Color.brandPurple)
                                .frame(width: 90, height: 20)
                            Capsule()
                                .fill(Color.brandRose)
                                .frame(width: 90, height: 20)
                        }
                    }

                    Spacer()
                }
                .padding(14)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .opacity(0.09)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Person row

    @ViewBuilder
    private func personRow(_ person: PeopleEntry) -> some View {
        // Outer NavigationLink: tapping the card → PersonDetailView.
        // Inner NavigationLink tags: SwiftUI hit-tests to the innermost tappable view,
        // so tapping a tag fires only the tag's link, not the card's link.
        NavigationLink(value: PeopleNavDest.detail(person)) {
            HStack(spacing: 14) {
                CachedAvatarView(storagePath: person.avatarStoragePath, name: person.name, size: 48)

                VStack(alignment: .leading, spacing: 6) {
                    Text(person.name)
                        .font(.system(.body).weight(.medium))
                        .foregroundColor(.primary)

                    HStack(spacing: 6) {
                        if person.isBlocked { blockedBadge }
                        if let occ = viewModel.nextOccasionByPersonId[person.id] {
                            occasionBadge(occ)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Blocked badge (person row inline)

    private var blockedBadge: some View {
        Label("Blocked", systemImage: "hand.raised.fill")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(Color.ink.opacity(0.55))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(hex: "EEECEA"))
            .clipShape(Capsule())
    }

    // MARK: - Occasion badge (person row inline)

    private func occasionBadge(_ occ: UpcomingOccasion) -> some View {
        Label {
            Text("\(occ.label) \(occ.relativeTime.lowercased())")
                .font(.system(size: 11, weight: .medium))
        } icon: {
            Image(systemName: occasionIcon(for: occ.label))
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(Color.ink.opacity(0.55))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color(hex: "EEECEA"))
        .clipShape(Capsule())
    }

    /// SF Symbol name keyed to occasion label.
    private func occasionIcon(for label: String) -> String {
        switch label.lowercased() {
        case "birthday":      return "birthday.cake"
        case "anniversary":   return "heart"
        case "mother's day":  return "heart.fill"
        case "father's day":  return "person.fill"
        default:              return "calendar"
        }
    }
    // MARK: - Coming up strip

    private var comingUpStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Coming up")
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(Color.secondary)
                .textCase(.uppercase)
                .kerning(0.6)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.upcomingOccasions) { occ in
                        comingUpCard(occ)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    private func comingUpCard(_ occ: UpcomingOccasion) -> some View {
        let action = cardAction(for: occ.daysUntil)
        return VStack(alignment: .leading, spacing: 10) {
            // Avatar + name
            HStack(spacing: 8) {
                CachedAvatarView(storagePath: occ.avatarStoragePath, name: occ.personName, size: 34)
                Text(occ.personName)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            // Occasion type
            Text(occ.label)
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(Color.ink)

            // Relative time
            Text(occ.relativeTime)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(Color.brandPurple)

            // Colour-coded action pill
            Button {
                recordingForPerson = viewModel.people.first { $0.id == occ.personId }
            } label: {
                Text(action.label)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(action.fg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(action.bg)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 158, alignment: .leading)
        .frame(minHeight: 158)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 5, x: 0, y: 2)
    }

    // MARK: - Card action style (colour-coded by proximity)

    private struct CardAction {
        let label: String
        let bg: Color
        let fg: Color
    }

    /// Imminent (≤7 days): purple "Leave a message".
    /// Soon (8–30 days): warm peach "Plan something".
    /// Distant (31+ days): neutral grey "Set reminder".
    private func cardAction(for daysUntil: Int) -> CardAction {
        switch daysUntil {
        case 0..<8:
            return CardAction(label: "Leave a message", bg: Color.brandPurple,        fg: .white)
        case 8..<31:
            return CardAction(label: "Plan something",  bg: Color(hex: "FBF0E6"),     fg: Color(hex: "8B4A1C"))
        default:
            return CardAction(label: "Set reminder",    bg: Color(hex: "EEECEA"),     fg: Color.ink.opacity(0.55))
        }
    }
}


#Preview {
    NavigationStack { PeopleView() }
        .environmentObject(AuthService())
}
