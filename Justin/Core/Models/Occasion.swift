import Foundation

// Occasion represents a meaningful date for a person (birthday, anniversary, etc.).
//
// Supabase table (to be created): occasions
//   id uuid primary key
//   person_id uuid not null references people(id) on delete cascade
//   label text not null
//   date date not null
//   remind_before_recording bool not null default true
//
// When remindBeforeRecording is true, a gentle push notification should be sent
// roughly 2 weeks before the occasion prompting the author to record a new message
// (e.g. "Em's birthday is in 2 weeks — want to leave her something?").
// Prompts must be tied to real user-set occasions only — never nagging or
// engagement-farming. The author can disable reminders per occasion.
struct Occasion: Identifiable, Codable, Hashable {
    let id: UUID
    let personId: UUID
    var label: String
    var date: Date
    var remindBeforeRecording: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case personId = "person_id"
        case label
        case date
        case remindBeforeRecording = "remind_before_recording"
    }
}
