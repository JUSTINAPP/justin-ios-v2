import Foundation
import Combine
import UIKit

/// Shared state carried across the 5 recording steps.
@MainActor
final class RecordFlowModel: ObservableObject {
    @Published var recipientName: String = ""
    // Optional phone number captured on the "Add someone new" path.
    // Identity anchor: when the recipient verifies this number on signup, deferred deep
    // linking converges any pending gifts to their shelf (handled when backend connects).
    @Published var recipientPhone: String = ""
    // true when recipient was added via "Add someone new" — drives the invite/share branch
    // after preview instead of immediately adding to an existing circle member's gift.
    @Published var isNewRecipient: Bool = false
    @Published var audioURL: URL?
    @Published var selectedImages: [UIImage] = []
    @Published var releaseType: ReleaseType = .now
    @Published var releaseDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @Published var releaseFeeling: String = ""
    @Published var hiddenUntilRelease: Bool = false

    var hasRecording: Bool { audioURL != nil }
    var hasPhotos: Bool { !selectedImages.isEmpty }
}

// MARK: - ReleaseType display helpers (UI only, not persisted)

extension ReleaseType {
    var displayName: String {
        switch self {
        case .now:     return "Right now"
        case .date:    return "On a date"
        case .feeling: return "When they feel a certain way"
        case .always:  return "Always there"
        }
    }

    var releaseSubtitle: String {
        switch self {
        case .now:     return "Opens as soon as you send it"
        case .date:    return "Sealed until a specific day you choose"
        case .feeling: return "They choose when the moment is right"
        case .always:  return "Always in their collection, never locked"
        }
    }

    var icon: String {
        switch self {
        case .now:     return "bolt"
        case .date:    return "calendar"
        case .feeling: return "heart"
        case .always:  return "infinity"
        }
    }
}
