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

    // ISO8601 parsers shared by the nested Decodable types (Supabase returns
    // timestamptz as strings; try fractional-seconds first, then plain).
    fileprivate static let isoFull: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    fileprivate static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    func fetch(recipientId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Step 1 — server-side filtered gift list.
            // get_received_gifts() is a SECURITY DEFINER RPC that joins against
            // blocks and excludes future gifts from blocked authors before they
            // ever leave the database.  Client-side filtering is intentionally
            // removed; all block enforcement happens here in one SQL call.
            struct RpcParams: Encodable {
                let pRecipientId: UUID
                enum CodingKeys: String, CodingKey { case pRecipientId = "p_recipient_id" }
            }
            let rpcRows: [RpcGiftRow] = try await supabase
                .rpc("get_received_gifts", params: RpcParams(pRecipientId: recipientId))
                .execute()
                .value
            debugLog("[Shelf] get_received_gifts returned \(rpcRows.count) gifts (blocked authors excluded server-side)")

            let gifts = rpcRows.map {
                ReceivedGiftRow(id: $0.id, authorId: $0.authorId, fromName: $0.authorName ?? "Someone")
            }

            guard !gifts.isEmpty else {
                sections = ShelfSections()
                debugLog("[Shelf] 0 visible received messages")
                return
            }

            // Step 2 — all messages for those gifts in one batch
            let messages: [Message] = try await supabase
                .from("messages")
                .select()
                .in("gift_id", values: gifts.map(\.id.uuidString))
                .execute()
                .value

            debugLog("[Shelf] loaded \(messages.count) received messages")
            sections = organize(messages: messages, gifts: gifts)

        } catch {
            debugLog("[Shelf] fetch failed: \(error)")
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
                    ShelfMessage(from: fromName, duration: "—", shelfItem: item)
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

    // MARK: - Internal model (built from RPC response, used by organize())

    struct ReceivedGiftRow {
        let id:       UUID
        let authorId: UUID
        let fromName: String
    }

    // MARK: - RPC response decoder

    /// Flat response from get_received_gifts() — block filtering already applied server-side.
    private struct RpcGiftRow: Decodable {
        let id:         UUID
        let authorId:   UUID
        let authorName: String?

        enum CodingKeys: String, CodingKey {
            case id
            case authorId   = "author_id"
            case authorName = "author_name"
        }
    }
}
