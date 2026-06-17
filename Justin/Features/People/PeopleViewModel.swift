import Foundation
import Supabase
import Combine

// MARK: - Display model

struct PeopleEntry: Identifiable, Hashable {
    let id: UUID
    let name: String
    var givingGiftId: UUID?    // gift the current user authored TO this person
    var receivingGiftId: UUID? // gift this person authored FOR the current user

    var isGiving:    Bool { givingGiftId    != nil }
    var isReceiving: Bool { receivingGiftId != nil }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

// MARK: - ViewModel

@MainActor
final class PeopleViewModel: ObservableObject {
    @Published var people: [PeopleEntry] = []
    @Published var isLoading = false

    func fetch(currentPersonId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Direction 1 — gifts I authored: recipients are people I'm giving to
            let authoredGifts: [GiftToRecipient] = try await supabase
                .from("gifts")
                .select("id, recipient_id, people!recipient_id(id, display_name)")
                .eq("author_id", value: currentPersonId.uuidString)
                .execute()
                .value

            // Direction 2 — gifts I received: authors are people giving to me
            let receivedGifts: [GiftFromAuthor] = try await supabase
                .from("gifts")
                .select("id, author_id, people!author_id(id, display_name)")
                .eq("recipient_id", value: currentPersonId.uuidString)
                .execute()
                .value

            // Merge both directions: each person appears once, with whichever tags apply
            var entries: [UUID: PeopleEntry] = [:]

            for gift in authoredGifts {
                guard let summary = gift.people else { continue }
                let pid = summary.id
                let name = summary.displayName ?? "Someone"
                if entries[pid] != nil {
                    entries[pid]!.givingGiftId = gift.id
                } else {
                    entries[pid] = PeopleEntry(
                        id: pid, name: name,
                        givingGiftId: gift.id, receivingGiftId: nil
                    )
                }
            }

            for gift in receivedGifts {
                guard let summary = gift.people else { continue }
                let pid = summary.id
                let name = summary.displayName ?? "Someone"
                if entries[pid] != nil {
                    entries[pid]!.receivingGiftId = gift.id
                } else {
                    entries[pid] = PeopleEntry(
                        id: pid, name: name,
                        givingGiftId: nil, receivingGiftId: gift.id
                    )
                }
            }

            people = entries.values.sorted { $0.name < $1.name }
            print("[People] loaded \(people.count) people")

        } catch {
            print("[People] fetch failed: \(error)")
        }
    }

    // MARK: - Decodable shapes

    private struct GiftToRecipient: Decodable {
        let id: UUID
        let recipientId: UUID
        let people: PersonSummary?
        enum CodingKeys: String, CodingKey {
            case id
            case recipientId = "recipient_id"
            case people
        }
    }

    private struct GiftFromAuthor: Decodable {
        let id: UUID
        let authorId: UUID
        let people: PersonSummary?
        enum CodingKeys: String, CodingKey {
            case id
            case authorId = "author_id"
            case people
        }
    }

    private struct PersonSummary: Decodable {
        let id: UUID
        let displayName: String?
        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
        }
    }
}
