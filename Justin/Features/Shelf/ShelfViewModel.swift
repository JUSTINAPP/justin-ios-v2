import SwiftUI
import Supabase
import Combine

// MARK: - Section data

struct ShelfSections {
    var readyNow:     [ShelfItem] = []
    var feelingGroups:[ShelfFeeling] = []   // ShelfFeeling defined in ShelfView.swift (same module)
    var alwaysHere:   [ShelfItem] = []
    var arrivingLater:[ShelfItem] = []

    var hasAnyContent: Bool {
        !readyNow.isEmpty || !feelingGroups.isEmpty || !alwaysHere.isEmpty || !arrivingLater.isEmpty
    }
}

/// A real received message plus its sender name, ready for display.
struct ShelfItem: Identifiable {
    let id: UUID          // = message.id
    let message: Message
    let fromName: String
}

// MARK: - ViewModel

@MainActor
final class ShelfViewModel: ObservableObject {
    @Published var sections  = ShelfSections()
    @Published var isLoading = false

    func fetch(recipientId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Step 1 — gifts received by this user, with the sender's name embedded
            // people!author_id: many-to-one join (gift.author_id → people.id)
            let gifts: [ReceivedGiftRow] = try await supabase
                .from("gifts")
                .select("id, author_id, people!author_id(display_name)")
                .eq("recipient_id", value: recipientId.uuidString)
                .execute()
                .value

            guard !gifts.isEmpty else {
                sections = ShelfSections()
                print("[Shelf] loaded 0 received messages")
                return
            }

            // Step 2 — all messages for those gifts in one batch
            let messages: [Message] = try await supabase
                .from("messages")
                .select()
                .in("gift_id", values: gifts.map(\.id.uuidString))
                .execute()
                .value

            print("[Shelf] loaded \(messages.count) received messages")
            sections = organize(messages: messages, gifts: gifts)

        } catch {
            print("[Shelf] fetch failed: \(error)")
        }
    }

    // MARK: - Organisation

    private func organize(messages: [Message], gifts: [ReceivedGiftRow]) -> ShelfSections {
        let nameByGiftId = Dictionary(uniqueKeysWithValues: gifts.map { ($0.id, $0.fromName) })
        let now = Date()

        var readyNow:      [ShelfItem] = []
        var feelingBuckets:[String: [ShelfMessage]] = [:]
        var alwaysHere:    [ShelfItem] = []
        var arrivingLater: [ShelfItem] = []

        for message in messages {
            let fromName = nameByGiftId[message.giftId] ?? "Someone"
            let item = ShelfItem(id: message.id, message: message, fromName: fromName)

            switch message.releaseType {
            case .now:
                readyNow.append(item)

            case .date:
                if let date = message.releaseDate {
                    if date <= now {
                        readyNow.append(item)
                    } else {
                        arrivingLater.append(item)
                    }
                }

            case .feeling:
                let label = message.releaseFeeling.flatMap { $0.isEmpty ? nil : $0 }
                    ?? "when the moment is right"
                feelingBuckets[label, default: []].append(
                    ShelfMessage(from: fromName, duration: "—")
                )

            case .always:
                alwaysHere.append(item)
            }
        }

        // Feeling card colour palette — cycles if there are more than 4 distinct feelings
        let palette: [[Color]] = [
            [Color(hex: "3E3270"), Color(hex: "7B6BA8")],
            [Color(hex: "B87090"), Color(hex: "C8855A")],
            [Color(hex: "4A3B6B"), Color(hex: "C4849A")],
            [Color(hex: "7B6BA8"), Color(hex: "E8B48A")],
        ]
        let illustrations: [String?] = [
            "illus-self-hug-white", "illus-hands-face-white",
            nil, "illus-hug-arms-white",
        ]

        let feelingGroups: [ShelfFeeling] = feelingBuckets
            .sorted { $0.key < $1.key }
            .enumerated()
            .map { (i, kv) in
                let p = i % palette.count
                return ShelfFeeling(
                    label: kv.key,
                    messages: kv.value,
                    cardColors: palette[p],
                    illustration: illustrations[p]
                )
            }

        return ShelfSections(
            readyNow:      readyNow,
            feelingGroups: feelingGroups,
            alwaysHere:    alwaysHere,
            arrivingLater: arrivingLater
        )
    }

    // MARK: - Decodable shapes

    struct ReceivedGiftRow: Decodable {
        let id: UUID
        let authorId: UUID
        let people: AuthorSummary?

        var fromName: String { people?.displayName ?? "Someone" }

        enum CodingKeys: String, CodingKey {
            case id
            case authorId = "author_id"
            case people
        }

        struct AuthorSummary: Decodable {
            let displayName: String?
            enum CodingKeys: String, CodingKey { case displayName = "display_name" }
        }
    }
}
