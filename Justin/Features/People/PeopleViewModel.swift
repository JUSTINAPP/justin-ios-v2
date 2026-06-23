import Foundation
import Supabase
import Combine

// MARK: - Display model

struct PeopleEntry: Identifiable, Hashable {
    let id: UUID
    var name: String      // var so override display_name can be applied after initial fetch
    var givingGiftId: UUID?    // gift the current user authored TO this person
    var receivingGiftId: UUID? // gift this person authored FOR the current user
    var avatarStoragePath: String? = nil

    var isGiving:    Bool { givingGiftId    != nil }
    var isReceiving: Bool { receivingGiftId != nil }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
}

// MARK: - Upcoming occasion model

struct UpcomingOccasion: Identifiable {
    let id: UUID               // occasion id
    let personId: UUID
    let personName: String
    let avatarStoragePath: String?
    let label: String
    let nextDate: Date
    let daysUntil: Int

    /// Human-friendly relative time, title-cased ("Tomorrow", "In 5 days", "In 2 weeks").
    var relativeTime: String {
        switch daysUntil {
        case 0:    return "Today"
        case 1:    return "Tomorrow"
        case 2..<8: return "In \(daysUntil) days"
        case 8..<31:
            let w = daysUntil / 7
            return "In \(w) \(w == 1 ? "week" : "weeks")"
        default:
            let m = max(1, daysUntil / 30)
            return "In \(m) \(m == 1 ? "month" : "months")"
        }
    }
}

// MARK: - ViewModel

@MainActor
final class PeopleViewModel: ObservableObject {
    @Published var people:               [PeopleEntry]                    = []
    @Published var upcomingOccasions:    [UpcomingOccasion]               = []   // ≤60 days, for the strip
    @Published var nextOccasionByPersonId: [UUID: UpcomingOccasion]      = [:]   // soonest per person, for inline list
    @Published var isLoading = false

    // UTC calendar + formatter for date-only occasion values ("yyyy-MM-dd").
    private static let utcCal: Calendar = {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c
    }()
    private static let occasionFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale     = Locale(identifier: "en_US_POSIX")
        f.timeZone   = TimeZone(identifier: "UTC")
        return f
    }()

    /// Returns the next calendar occurrence of this date's month+day on or after `after`.
    /// Occasion dates are annually recurring; the stored year is irrelevant for scheduling.
    private static func nextOccurrence(of date: Date, after refDay: Date) -> Date {
        let month = utcCal.component(.month, from: date)
        let day   = utcCal.component(.day,   from: date)
        let cal   = Calendar.current
        let year  = cal.component(.year, from: refDay)

        let thisYear = DateComponents(year: year,     month: month, day: day)
        if let d = cal.date(from: thisYear), cal.startOfDay(for: d) >= cal.startOfDay(for: refDay) {
            return d
        }
        let nextYear = DateComponents(year: year + 1, month: month, day: day)
        return Calendar.current.date(from: nextYear) ?? date
    }

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

            // Direction 3 — person_overrides: two jobs in one query.
            //   a) Finds standalone contacts (no gift) to add to the list.
            //   b) Provides avatar_storage_path for ALL persons (gift-linked + standalone).
            do {
                struct OverrideInfo: Decodable {
                    let personId: UUID
                    let avatarStoragePath: String?
                    /// The giver's private label for this person (person_overrides.custom_label).
                    /// Preferred over people.display_name everywhere in giver-facing views.
                    let customLabel: String?
                    enum CodingKeys: String, CodingKey {
                        case personId          = "person_id"
                        case avatarStoragePath = "avatar_storage_path"
                        case customLabel       = "custom_label"
                    }
                }
                let overrides: [OverrideInfo] = try await supabase
                    .from("person_overrides")
                    .select("person_id, avatar_storage_path, custom_label")
                    .eq("owner_id", value: currentPersonId.uuidString)
                    .execute()
                    .value

                // Apply avatar paths and custom labels to gift-linked persons.
                // custom_label ("Bill") takes priority over people.display_name ("William")
                // so the giver's private label survives account convergence.
                for o in overrides {
                    entries[o.personId]?.avatarStoragePath = o.avatarStoragePath
                    if let label = o.customLabel, !label.isEmpty {
                        entries[o.personId]?.name = label
                    }
                }

                // Fetch names for standalone contacts not yet in entries.
                let standaloneIds = overrides.map { $0.personId }.filter { entries[$0] == nil }
                if !standaloneIds.isEmpty {
                    let peopleRows: [PersonSummary] = try await supabase
                        .from("people")
                        .select("id, display_name")
                        .in("id", values: standaloneIds.map(\.uuidString))
                        .execute()
                        .value

                    for row in peopleRows {
                        let overrideInfo = overrides.first(where: { $0.personId == row.id })
                        // Prefer custom_label; fall back to people.display_name
                        let resolvedName = overrideInfo?.customLabel?.isEmpty == false
                            ? overrideInfo!.customLabel!
                            : (row.displayName ?? "Unknown")
                        debugLog("[People] person \(row.id) name=\(resolvedName) (source: \(overrideInfo?.customLabel != nil ? "custom_label" : "display_name"))")
                        entries[row.id] = PeopleEntry(
                            id: row.id,
                            name: resolvedName,
                            givingGiftId: nil,
                            receivingGiftId: nil,
                            avatarStoragePath: overrideInfo?.avatarStoragePath
                        )
                    }
                }
            } catch {
                debugLog("[People] overrides fetch skipped: \(error)")
            }

            people = entries.values.sorted { $0.name < $1.name }
            debugLog("[People] loaded \(people.count) people")

            // ── Upcoming occasions ─────────────────────────────────────────────
            do {
                struct OccasionRow: Decodable {
                    let id: UUID; let personId: UUID; let label: String; let date: String
                    enum CodingKeys: String, CodingKey {
                        case id, label, date; case personId = "person_id"
                    }
                }
                let rows: [OccasionRow] = try await supabase
                    .from("occasions")
                    .select("id, person_id, label, date")
                    .eq("owner_id", value: currentPersonId.uuidString)
                    .execute()
                    .value

                let today  = Calendar.current.startOfDay(for: Date())
                let cutoff = Calendar.current.date(byAdding: .day, value: 60, to: today)!

                // Compute next occurrence for every occasion, regardless of window.
                let all: [UpcomingOccasion] = rows.compactMap { row in
                    guard let stored = Self.occasionFmt.date(from: row.date) else { return nil }
                    let next  = Self.nextOccurrence(of: stored, after: today)
                    let days  = Calendar.current.dateComponents(
                        [.day], from: today, to: Calendar.current.startOfDay(for: next)
                    ).day ?? 0
                    return UpcomingOccasion(
                        id:                row.id,
                        personId:          row.personId,
                        personName:        entries[row.personId]?.name ?? "Someone",
                        avatarStoragePath: entries[row.personId]?.avatarStoragePath,
                        label:             row.label,
                        nextDate:          next,
                        daysUntil:         days
                    )
                }.sorted { $0.daysUntil < $1.daysUntil }

                // Strip: only occasions within 60 days.
                upcomingOccasions = all.filter { $0.daysUntil <= 60 }
                debugLog("[ComingUp] loaded \(upcomingOccasions.count) upcoming occasions (of \(all.count) total)")

                // Inline list: soonest per person (any window).
                var nextByPerson: [UUID: UpcomingOccasion] = [:]
                for occ in all {
                    if (nextByPerson[occ.personId]?.daysUntil ?? Int.max) > occ.daysUntil {
                        nextByPerson[occ.personId] = occ
                    }
                }
                nextOccasionByPersonId = nextByPerson
            } catch {
                debugLog("[ComingUp] occasions fetch failed (non-fatal): \(error)")
            }

        } catch {
            debugLog("[People] fetch failed: \(error)")
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
