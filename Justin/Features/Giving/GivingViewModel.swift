import Foundation
import Supabase
import Combine

@MainActor
final class GivingViewModel: ObservableObject {
    @Published var gifts: [GiftRow] = []
    @Published var isLoading = false

    func fetch(authorId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [GiftRow] = try await supabase
                .from("gifts")
                // people!recipient_id: many-to-one join using the recipient_id FK → returns single object
                // messages(id): one-to-many join → returns array; count in Swift to avoid aggregate issues
                .select("id, status, accepted, recipient_id, people!recipient_id(display_name), messages(id)")
                .eq("author_id", value: authorId.uuidString)
                .order("created_at", ascending: false)
                .execute()
                .value
            gifts = rows
            print("[Giving] loaded \(rows.count) gifts")
        } catch {
            print("[Giving] fetch failed: \(error)")
        }
    }

    struct GiftRow: Codable, Identifiable {
        let id: UUID
        let status: String
        let accepted: Bool
        let recipientId: UUID
        let people: RecipientSummary?
        let messages: [MessageStub]

        var recipientName: String { people?.displayName ?? "Someone" }
        var messageCount: Int { messages.count }

        enum CodingKeys: String, CodingKey {
            case id, status, accepted
            case recipientId = "recipient_id"
            case people, messages
        }

        struct RecipientSummary: Codable {
            let displayName: String?
            enum CodingKeys: String, CodingKey { case displayName = "display_name" }
        }

        struct MessageStub: Codable {
            let id: UUID
        }
    }
}
