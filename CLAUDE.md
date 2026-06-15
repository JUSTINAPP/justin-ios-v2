# Justin — Claude Context

## Project

Justin is a private iOS app for building someone you love a "gift of your voice" — a growing collection of short voice messages (optionally over photos) that open when the recipient needs them. The core unit is a GIFT (a collection), never a single message. Native SwiftUI + Supabase backend (Postgres, phone/OTP auth, Storage). Lead with joy/occasions; support use is discovered, not prescribed. Not a mental-health/crisis app.

## Non-negotiable product rules

- Gifts are ONE-DIRECTIONAL: one author, one recipient. Giving back is a separate gift. NEVER build a two-way thread/chat/reply between two people.
- Identity = verified phone number. One person = one number = one account.
- Voice is the ONLY recorded medium. No video. Photos are optional.
- Photos + voice → Ken Burns pan/zoom. No photos → ambient moving visual. Never require a photo.
- Encourage, never gate. One message is always complete. No counters/progress bars that make one message feel inadequate.
- Release types per message: now | date | feeling | always. Date releases have a "hidden until the day" vs "visible sealed" sub-choice.
- Opening a message notifies the AUTHOR (a human), tone scaling with type. NEVER auto-detect crisis, contact authorities, broadcast location, or auto-escalate.
- The receiver is the protected party. Gifts require recipient consent. Removing a person deletes their queued messages (kill-switch). Provide block/report and per-person mute.

## Navigation (must hold exactly)

- Four-tab bar: Shelf · People · Giving · Profile. NO center create button.
- Shelf is the landing screen and is PURELY receiving — no create affordance, no giving content. Stays calm/uncluttered.
- Giving is a separate tab. Creating lives here: a floating + (bottom-center, above tabs, ONLY in Giving) plus a "Start a gift" card.
- Receiving is a place; giving is an action. No modes, no profile-flip.
- Inactive tab icons are confident dark ink (not pale grey); active fills brand-purple. Shelf icon is a folder.

## Tech stack

- Native SwiftUI (fresh build, do not port old code).
- Backend: Supabase — Postgres, Auth (phone/OTP), Storage. Tables: people, gifts, messages, with release types + RLS already set up.
- Web→app handoff for shared gift links needs deferred deep linking.

## Brand

- Fonts: Plus Jakarta Sans (UI), Caveat (handwritten message text).
- Colors: brand-purple #7B6BA8, brand-rose #C4849A, brand-peach #E8B48A, brand-deep #4A3B6B, ink #2e2540, cream #faf0e4, lilac-bg #faf8fc.
- Receiving = white/purple world. Giving = cream/amber world. Hand-drawn single-line illustrations, used sparingly.

## Tone

Warm, human, calm, intentional. Never clinical, cheesy, or feed-like. No streaks/likes/endless scroll. Avoid em dashes in user-facing copy.
