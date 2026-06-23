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

        // Fetch block list with timestamps — non-fatal; empty map = no filtering.
        // Maps blocked_author_id → when_the_block_was_created.
        // Future-only rule: a gift is hidden only if it arrived AFTER the block.
        // Gifts already on the shelf before blocking are never hidden retroactively.
        var blocksByAuthor: [UUID: Date] = [:]
        do {
            struct BlockRow: Decodable {
                let blockedId: UUID
                let createdAtStr: String?
                enum CodingKeys: String, CodingKey {
                    case blockedId    = "blocked_id"
                    case createdAtStr = "created_at"
                }
            }
            let blocks: [BlockRow] = try await supabase
                .from("blocks")
                .select("blocked_id, created_at")
                .execute()
                .value
            for b in blocks {
                let blockedAt = b.createdAtStr.flatMap {
                    ShelfViewModel.isoFull.date(from: $0) ?? ShelfViewModel.isoPlain.date(from: $0)
                } ?? Date.distantPast
                blocksByAuthor[b.blockedId] = blockedAt
            }
            if !blocksByAuthor.isEmpty {
                debugLog("[Shelf] \(blocksByAuthor.count) blocked author(s) — future-only filter active")
            }
        } catch {
            debugLog("[Shelf] blocks fetch skipped (non-fatal): \(error)")
        }

        do {
            // Step 1 — gifts received by this user (includes created_at for block-filter comparison)
            let gifts: [ReceivedGiftRow] = try await supabase
                .from("gifts")
                .select("id, author_id, created_at, people!author_id(display_name)")
                .eq("recipient_id", value: recipientId.uuidString)
                .execute()
                .value

            // Future-only block filter:
            //   • author not blocked                    → always show
            //   • author blocked, gift pre-dates block  → keep (gift was there before block)
            //   • author blocked, gift post-dates block → hide (arrived after block)
            let visibleGifts: [ReceivedGiftRow]
            if blocksByAuthor.isEmpty {
                visibleGifts = gifts
            } else {
                visibleGifts = gifts.filter { gift in
                    guard let blockedAt = blocksByAuthor[gift.authorId] else {
                        return true // not blocked
                    }
                    let giftDate = gift.createdAt ?? Date.distantPast
                    let keep     = giftDate <= blockedAt
                    debugLog("[Shelf] gift \(gift.id) | author blocked @ \(blockedAt) | gift created @ \(giftDate) → \(keep ? "KEEP" : "HIDE")")
                    return keep
                }
            }

            guard !visibleGifts.isEmpty else {
                sections = ShelfSections()
                debugLog("[Shelf] loaded 0 visible received messages")
                return
            }

            // Step 2 — all messages for those gifts in one batch
            let messages: [Message] = try await supabase
                .from("messages")
                .select()
                .in("gift_id", values: visibleGifts.map(\.id.uuidString))
                .execute()
                .value

            debugLog("[Shelf] loaded \(messages.count) received messages")
            sections = organize(messages: messages, gifts: visibleGifts)

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

    // MARK: - Decodable shapes

    struct ReceivedGiftRow: Decodable {
        let id: UUID
        let authorId: UUID
        let createdAt: Date?      // used for future-only block filter
        let people: AuthorSummary?

        var fromName: String { people?.displayName ?? "Someone" }

        enum CodingKeys: String, CodingKey {
            case id
            case authorId  = "author_id"
            case createdAt = "created_at"
            case people
        }

        // Custom init: Supabase returns timestamptz as an ISO8601 string, not a
        // number, so the default Date decoding would fail. Parse it explicitly.
        init(from decoder: Decoder) throws {
            let c      = try decoder.container(keyedBy: CodingKeys.self)
            id         = try c.decode(UUID.self, forKey: .id)
            authorId   = try c.decode(UUID.self, forKey: .authorId)
            people     = try? c.decodeIfPresent(AuthorSummary.self, forKey: .people)
            if let s   = try? c.decodeIfPresent(String.self, forKey: .createdAt) {
                createdAt = ShelfViewModel.isoFull.date(from: s)
                         ?? ShelfViewModel.isoPlain.date(from: s)
            } else {
                createdAt = nil
            }
        }

        struct AuthorSummary: Decodable {
            let displayName: String?
            enum CodingKeys: String, CodingKey { case displayName = "display_name" }
        }
    }
}
