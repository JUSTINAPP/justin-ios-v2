import SwiftUI

struct PeopleView: View {

    private struct PersonEntry: Identifiable {
        var id: String { name }
        let name: String
        let receiving: Bool // they have a gift coming to you
        let giving: Bool    // you have a gift for them
    }

    private let people: [PersonEntry] = [
        PersonEntry(name: "Mum",    receiving: true,  giving: true),
        PersonEntry(name: "Em",     receiving: false, giving: true),
        PersonEntry(name: "Jordan", receiving: false, giving: true),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(people) { person in
                    personRow(person)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .navigationTitle("People")
        .navigationBarTitleDisplayMode(.large)
    }

    private func personRow(_ person: PersonEntry) -> some View {
        HStack(spacing: 14) {
            InitialsAvatar(name: person.name, size: 48)
            VStack(alignment: .leading, spacing: 6) {
                Text(person.name)
                    .font(.system(.body).weight(.medium))
                HStack(spacing: 6) {
                    if person.receiving {
                        relationshipTag("their gift to you", systemImage: "arrow.down", color: .brandPurple)
                    }
                    if person.giving {
                        relationshipTag("your gift to them", systemImage: "arrow.up", color: .brandRose)
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
