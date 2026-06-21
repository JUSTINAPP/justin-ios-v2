import Foundation
import Supabase
import Combine

@MainActor
final class GivingViewModel: ObservableObject {
    @Published var recipients: [RecipientRow] = []
    @Published var isLoading = false

    func fetch(authorId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Query 1 — all gifts authored by this user (share_token + recipient name)
            let giftRows: [RawGiftRow] = try await supabase
                .from("gifts")
                .select("id, recipient_id, share_token, people!recipient_id(display_name)")
                .eq("author_id", value: authorId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            print("[Giving] loaded \(giftRows.count) gifts")

            if giftRows.isEmpty { recipients = []; return }

            // Query 2 — all messages for those gifts, newest first (reuses Message's date parsing)
            let messages: [Message] = try await supabase
                .from("messages")
                .select()
                .in("gift_id", values: giftRows.map(\.id.uuidString))
                .order("created_at", ascending: false)
                .execute()
                .value

            // Lookups built from the gift rows
            let shareTokenByGiftId: [UUID: String?] = Dictionary(
                giftRows.map { ($0.id, $0.shareToken) },
                uniquingKeysWith: { first, _ in first }
            )
            let giftToRecipient: [UUID: (id: UUID, name: String)] = Dictionary(
                giftRows.map { ($0.id, (id: $0.recipientId, name: $0.people?.displayName ?? "Someone")) },
                uniquingKeysWith: { first, _ in first }
            )

            // Group messages by recipient
            var byRecipient: [UUID: (name: String, items: [RecipientRow.MessageItem])] = [:]
            for message in messages {
                guard let info = giftToRecipient[message.giftId] else { continue }
                let item = RecipientRow.MessageItem(
                    id: message.id,
                    message: message,
                    shareToken: shareTokenByGiftId[message.giftId] ?? nil
                )
                byRecipient[info.id, default: (info.name, [])].items.append(item)
            }

            // Query 3 — avatar paths (non-fatal)
            let recipientIds = Array(byRecipient.keys)
            var avatarPaths: [UUID: String] = [:]
            if !recipientIds.isEmpty {
                do {
                    let overrides: [AvatarOverride] = try await supabase
                        .from("person_overrides")
                        .select("person_id, avatar_storage_path")
                        .eq("owner_id", value: authorId.uuidString)
                        .in("person_id", values: recipientIds.map(\.uuidString))
                        .execute()
                        .value
                    for o in overrides {
                        if let path = o.avatarStoragePath { avatarPaths[o.personId] = path }
                    }
                } catch {
                    print("[Giving] avatar paths failed (non-fatal): \(error)")
                }
            }

            // Build recipient rows sorted by most recent message
            recipients = byRecipient.map { (recipientId, pair) in
                RecipientRow(
                    id: recipientId,
                    recipientName: pair.name,
                    avatarStoragePath: avatarPaths[recipientId],
                    items: pair.items  // already newest-first from DB order
                )
            }.sorted {
                ($0.items.first?.message.createdAt ?? .distantPast) >
                ($1.items.first?.message.createdAt ?? .distantPast)
            }

            print("[Giving] \(recipients.count) recipient(s), \(messages.count) total message(s)")

        } catch {
            print("[Giving] fetch failed: \(error)")
        }
    }

    // MARK: - Public models

    struct RecipientRow: Identifiable {
        let id: UUID               // recipientId
        let recipientName: String
        var avatarStoragePath: String?
        var items: [MessageItem]   // all messages to this recipient, newest first

        var messageCount: Int { items.count }

        struct MessageItem: Identifiable {
            let id: UUID           // message.id
            let message: Message
            let shareToken: String?
        }
    }

    // MARK: - Private Decodable shapes

    private struct RawGiftRow: Decodable {
        let id: UUID
        let recipientId: UUID
        let shareToken: String?
        let people: RecipientSummary?

        enum CodingKeys: String, CodingKey {
            case id
            case recipientId = "recipient_id"
            case shareToken  = "share_token"
            case people
        }

        struct RecipientSummary: Decodable {
            let displayName: String?
            enum CodingKeys: String, CodingKey { case displayName = "display_name" }
        }
    }

    private struct AvatarOverride: Decodable {
        let personId: UUID
        let avatarStoragePath: String?
        enum CodingKeys: String, CodingKey {
            case personId          = "person_id"
            case avatarStoragePath = "avatar_storage_path"
        }
    }
}
