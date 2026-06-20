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
    @State private var showAddPerson = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !viewModel.people.isEmpty {
                ScrollView {
                    VStack(spacing: 10) {
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
        .navigationTitle("People")
        .navigationBarTitleDisplayMode(.inline)
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
                        if person.isReceiving {
                            NavigationLink(value: PeopleNavDest.receivedGift(giftId: person.receivingGiftId, name: person.name)) {
                                relationshipTag("their gift to you",
                                               systemImage: "arrow.down",
                                               color: .brandPurple)
                            }
                            .buttonStyle(.plain)
                        }
                        if person.isGiving {
                            NavigationLink(value: PeopleNavDest.givingGift(
                                giftId: person.givingGiftId,
                                name: person.name,
                                personId: person.id
                            )) {
                                relationshipTag("your gift to them",
                                               systemImage: "arrow.up",
                                               color: .brandRose)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tag pill

    private func relationshipTag(_ label: String, systemImage: String, color: Color) -> some View {
        Label(label, systemImage: systemImage)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}


#Preview {
    NavigationStack { PeopleView() }
        .environmentObject(AuthService())
}
