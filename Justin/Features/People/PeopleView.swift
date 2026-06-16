import SwiftUI

// Navigation destinations within the People tab.
// Private to this file — all navigation is handled via navigationDestination below.
private enum PeopleNavDest: Hashable {
    case detail(String)       // → PersonDetailView
    case receivedGift(String) // → ReceivedGiftDetailView
    case givingGift(String)   // → GiftDetailView
}

struct PeopleView: View {

    private struct PersonEntry: Identifiable {
        var id: String { name }
        let name: String
        let receiving: Bool
        let giving: Bool
    }

    private let people: [PersonEntry] = [
        PersonEntry(name: "Mum",    receiving: true,  giving: true),
        PersonEntry(name: "Em",     receiving: false, giving: true),
        PersonEntry(name: "Jordan", receiving: false, giving: true),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("People")
                    .font(.system(.title2).weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)

                ForEach(people) { person in
                    personRow(person)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .scrollClearance()
        .navigationTitle("People")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Wordmark() }
        }
        // Single destination handler for the whole tab stack
        .navigationDestination(for: PeopleNavDest.self) { dest in
            switch dest {
            case .detail(let name):
                PersonDetailView(name: name)
            case .receivedGift(let name):
                ReceivedGiftDetailView(fromName: name)
            case .givingGift(let name):
                GiftDetailView(recipientName: name)
            }
        }
    }

    // MARK: - Person row

    @ViewBuilder
    private func personRow(_ person: PersonEntry) -> some View {
        // Outer NavigationLink: tapping the card (excluding tags) → PersonDetailView.
        // Inner NavigationLink tags: SwiftUI hit-tests to the innermost tappable view,
        // so tapping a tag fires the tag's link only, not the card's link.
        NavigationLink(value: PeopleNavDest.detail(person.name)) {
            HStack(spacing: 14) {
                InitialsAvatar(name: person.name, size: 48)

                VStack(alignment: .leading, spacing: 6) {
                    Text(person.name)
                        .font(.system(.body).weight(.medium))
                        .foregroundColor(.primary)

                    HStack(spacing: 6) {
                        if person.receiving {
                            NavigationLink(value: PeopleNavDest.receivedGift(person.name)) {
                                relationshipTag("their gift to you",
                                               systemImage: "arrow.down",
                                               color: .brandPurple)
                            }
                            .buttonStyle(.plain)
                        }
                        if person.giving {
                            NavigationLink(value: PeopleNavDest.givingGift(person.name)) {
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
}
