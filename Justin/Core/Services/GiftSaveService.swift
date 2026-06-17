import Foundation
import Supabase

/// Persists a completed recording flow via a single atomic RPC call.
/// The database function create_gift_with_message handles recipient resolution,
/// gift find-or-create, and message insertion in one transaction, bypassing
/// per-table RLS issues that affected the previous three-step client-side approach.
@MainActor
final class GiftSaveService {

    func save(model: RecordFlowModel, authorId: UUID) async throws {
        let params = CreateGiftParams(
            pRecipientName: model.recipientName,
            pRecipientPhone: model.recipientPhone.isEmpty ? nil : model.recipientPhone,
            pRecipientId: model.recipientPersonId,
            pReleaseType: model.releaseType.rawValue,
            pReleaseDate: model.releaseType == .date ? model.releaseDate : nil,
            pReleaseFeeling: model.releaseType == .feeling && !model.releaseFeeling.isEmpty
                ? model.releaseFeeling : nil,
            pVoiceUrl: nil,   // TODO(storage): populate once Storage upload is wired
            pPhotoUrls: []    // TODO(storage): populate once Storage upload is wired
        )

        let debugEncoder = JSONEncoder()
        debugEncoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        debugEncoder.dateEncodingStrategy = .iso8601
        if let data = try? debugEncoder.encode(params),
           let json = String(data: data, encoding: .utf8) {
            print("[Save] create_gift_with_message params:\n\(json)")
        }

        do {
            let messageId: UUID = try await supabase
                .rpc("create_gift_with_message", params: params)
                .execute()
                .value
            print("[Save] gift+message saved, message id: \(messageId)")
        } catch {
            print("[Save] gift save failed: \(error)")
            print("[Save] localizedDescription: \(error.localizedDescription)")
            if let pgErr = error as? PostgrestError {
                print("[Save] PostgrestError — code: \(pgErr.code ?? "nil"), message: \(pgErr.message)")
                print("[Save] PostgrestError — detail: \(pgErr.detail ?? "nil"), hint: \(pgErr.hint ?? "nil")")
            }
            throw error
        }
    }

    // MARK: - RPC params

    private struct CreateGiftParams: Encodable {
        let pRecipientName: String
        let pRecipientPhone: String?
        let pRecipientId: UUID?
        let pReleaseType: String
        let pReleaseDate: Date?
        let pReleaseFeeling: String?
        let pVoiceUrl: String?
        let pPhotoUrls: [String]

        enum CodingKeys: String, CodingKey {
            case pRecipientName  = "p_recipient_name"
            case pRecipientPhone = "p_recipient_phone"
            case pRecipientId    = "p_recipient_id"
            case pReleaseType    = "p_release_type"
            case pReleaseDate    = "p_release_date"
            case pReleaseFeeling = "p_release_feeling"
            case pVoiceUrl       = "p_voice_url"
            case pPhotoUrls      = "p_photo_urls"
        }

        // Swift's synthesised Encodable uses encodeIfPresent for optionals, which
        // OMITS the key entirely when the value is nil. PostgREST matches Postgres
        // functions by the exact set of parameter names in the JSON body, so any
        // missing key reduces the apparent arity and causes PGRST202 "not found".
        // Custom encode(to:) uses encode(_:forKey:) instead, which writes
        // explicit JSON null for nil — all 8 keys are always present.
        func encode(to encoder: any Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(pRecipientName,  forKey: .pRecipientName)
            try c.encode(pRecipientPhone, forKey: .pRecipientPhone)   // null when nil
            try c.encode(pRecipientId,    forKey: .pRecipientId)      // null when nil
            try c.encode(pReleaseType,    forKey: .pReleaseType)
            try c.encode(pReleaseDate,    forKey: .pReleaseDate)       // null when nil
            try c.encode(pReleaseFeeling, forKey: .pReleaseFeeling)   // null when nil
            try c.encode(pVoiceUrl,       forKey: .pVoiceUrl)         // null when nil
            try c.encode(pPhotoUrls,      forKey: .pPhotoUrls)
        }
    }
}
