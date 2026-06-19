# Justin — Build Roadmap (from here to launch)

*A map of the phases from where the build is now to App Store launch. Shows what's
done, what's next, and where each piece (Twilio, the web taste page, App Store,
etc.) fits — so the later items have a clear home instead of feeling urgent now.*

---

## Where things stand (done)

**Product & design**
- Gift-first product direction settled; full product spec written (justin-v2-spec.md)
- Live marketing website (justinapp.com.au): gift-first copy, Ken Burns demo with
  real photos, hand-drawn illustrations, share image, meta tags, favicon
- All core UI journeys mapped (onboarding both paths, web→app bridge, record flow,
  shelf, giving, dual giver/receiver model, navigation)
- Brand: wordmark, app icon (lowercase "justin", Plus Jakarta Sans), illustrations

**Backend foundation (Supabase) — built, not yet connected to the app**
- Postgres schema: people, gifts, messages, with release types
- RLS security policies, auth linkage, storage buckets
- (Still to add before connecting: occasions table, blocks table, custom-photo
  field — new concepts added during UI build)

**iOS app — prototype in progress (SwiftUI, runs in simulator)**
- Project scaffolded, structured, CLAUDE.md steering it, on GitHub
- Navigable: four-tab bar (Shelf · People · Giving · Profile)
- Ken Burns player (placeholder demo)
- Functional record flow: real voice recording, photo selection, playback
- Shelf with warmth (drifting gradients, coloured feeling cards, illustrations)
- Gift detail (with edit/delete-before-opened rules)
- Person detail (dates/occasions, notes, photo override)
- Profile: Account, Notifications, Safety & Privacy, Manage circle, Blocked people,
  Delete account (grace period)
- Invite/share moment (self-share via own Messages/WhatsApp)

---

## PHASE 1 — Finish the UI prototype  *(current phase, nearly done)*

Goal: every screen real, every tap goes somewhere, running on placeholder data.

- Full click-through to find remaining dead-ends (hollow buttons/screens)
- Fix any last hollow spots in a batch
- Confirm on a real iPhone (needs Apple Developer device setup) — the simulator
  has input quirks (e.g. mouse-scroll); real hardware shows the true feel
- Optional: revisit Ken Burns player "feel" once the surrounding app exists

**Exit criteria:** you can walk the entire app start to finish with nothing
broken or leading nowhere (just no real/saved data yet).

---

## PHASE 2 — Backend: make it real  *(the big phase; Twilio + taste page live here)*

Goal: turn the prototype into a real system — real accounts, saved data, gifts
that actually reach people. This is the largest, most complex phase.

**2a. Prep Supabase**
- Add missing tables/fields: occasions, blocks, custom-photo. (Schema additions
  via SQL, like the original setup.)

**2b. Auth (phone/OTP) — TWILIO is used here**
- Connect Supabase Auth phone/OTP. Twilio is the SMS provider that delivers the
  verification code. (Twilio is ONLY for login verification codes — NOT for
  sending gifts; gifts go via the giver's own Messages/WhatsApp.)
- Cost: a few cents per verification SMS, scales with signups only.

**2c. Wire data to screens**
- Replace placeholder data with real Supabase reads/writes across all screens.
- Upload voice files + photos to Supabase Storage.
- Pending-gift-by-phone convergence (gifts attach to a person when they verify
  their number).
- Handle real-system states: loading, errors, empty states, sync.

**2d. Shareable links + the web taste page**
- Generate real shareable gift links (e.g. justinapp.com.au/g/[id]).
- Build the WEB TASTE PAGE on justinapp.com.au — where a recipient hears a
  message without installing the app, then is drawn to install. (Lives on the
  website, but built here because it needs real gifts to display.)
- Deferred deep linking: the link survives the App Store trip so the app opens
  to the correct gift after install.

**2e. Notifications**
- Push notifications for the notify-on-open loop (graded by message type) and the
  gentle occasion reminders (record-before-the-birthday prompts).

**Exit criteria:** one person can make a gift, share it, and another person can
receive it (web taste → install → gift converges to them), with the notify-on-open
loop working.

---

## PHASE 3 — Test on real devices

- Set up Apple Developer device testing (TestFlight).
- Test the real sensory experience on actual iPhones: Ken Burns feel, audio,
  scrolling, notifications, the full give→receive loop with real people.
- Tighten Supabase storage RLS policies (scope to gift_id) before any real users.

---

## PHASE 4 — Validation  *(can start MUCH earlier — see note)*

- Test with ~5 real people whether the gift-first concept makes them want to
  install and use it. Watch real reactions to the give→receive loop.
- Test the occasion-reminder idea ("a nudge before your wife's birthday — welcome
  or annoying?").

**Note:** this doesn't have to wait until Phase 4. The live website + the prototype
are already enough to test the *concept* with people now. Highest-leverage thing
you can do cheaply, and it should inform how much to invest in the big backend
phase. Strongly worth doing in parallel, soon.

---

## PHASE 5 — Launch prep & submission  *(the App Store listing lives here)*

- Update the App Store listing: new copy, screenshots, the new app icon,
  description, keywords — all reflecting the gift-first direction. (This is the
  copy/images you saw needing updating — correctly a LAST step, once the app is
  final, so you don't redo it.)
- Wire up real Twilio account (move off trial), confirm SMS costs.
- Domestic-violence / coercive-control expert review of the safety features
  (the block/remove/kill-switch, proactive number blocking, etc.).
- Privacy policy + terms final pass (already drafted on the website).
- Submit to App Store review.

---

## Quick reference — "where does X fit?"

- **Twilio** → Phase 2b (auth). Set up and waiting; only used when wiring login.
  Only for verification codes, never for sending gifts.
- **Web taste page** → Phase 2d. On the website, but needs real gifts first.
- **App Store listing / copy / images** → Phase 5. Last step, once app is final.
- **Validation with real people** → start NOW in parallel; don't wait.
- **Real-device testing** → Phase 3, needs Apple Developer device setup.
- **Safety expert review** → Phase 5, before launch.

---

## The honest big picture

Phase 1 is nearly done and is going well. **Phase 2 (backend) is the bulk of the
remaining work** and the step where the app stops being a beautiful prototype and
becomes a real, harder-to-build system. It's worth pacing deliberately.

Before pouring weeks into Phase 2, Phase 4 validation (testing the concept with
real people using the website + prototype) is the cheapest, highest-leverage thing
— it tells you whether the gift-first hook actually makes people want to install,
which is the one risk no amount of building resolves.

---

## Running to-do (captured mid-build, for after player fixes)

**People as a standalone "people who matter" hub (not just gift recipients):**
- Allow adding a person directly in People — name, their photo, and their important dates/occasions (birthday, anniversary) and notes — WITHOUT having to create a gift for them first. A person can exist with no gift attached.
- This makes People an address-book-of-who-you-care-about that you populate first; gifting flows out of it later.
- Strengthens the occasion-reminder feature: with everyone's dates stored upfront, Justin can gently prompt "X's birthday is in two weeks — want to leave them something?" (the retention engine). Reminders must stay gentle and tied to real user-set dates only.
- Gives the app value before the first gift; lowers the barrier to entry.
- Empty-People state should invite "Add someone" directly, not only "make a gift".

**Launch a gift from People:**
- Add a "Leave [name] a message" / start-a-gift action from a person's detail (and ideally the person row), so creating isn't only possible from the Giving tab's floating +.
- Pre-fills that person as the recipient.

**Note on video replay scope:** the Ken Burns / playback work currently being fixed is the ON-PHONE (in-app) viewing experience. The WEB taste-page version of playback (recipient viewing via link without the app) is a separate later build (Phase 2d) and will need its own JS-based Ken Burns assembly.

---

## Player — cinematic layer (AFTER render is stable)

Once the Ken Burns playback render is correct and stable (no restart loop, smooth, X always present), add the richer touches — but NOT before, so we're not decorating a broken foundation:

1. **Voice/waveform animation (retain it):** the Waveform element already exists in KenBurnsPlayerView (12 animated bars). Keep it, but make it MEANINGFUL — animate only while audio is actually playing, rest when paused/ended. (This was attempted; confirm it's tied to audio.isPlaying once the render loop is fixed.)

2. **Giver-written key words / captions (the cinematic text):** let the GIVER optionally type short words/phrases when creating a message (Approach A — intentional, no transcription). During playback, these animate gently over the Ken Burns photos — fade in/out, handwritten or varied sizes/positions. This is the "cinematic" feel from the website demo (the Caveat handwritten message over Cooper's photos).
   - Touches: messages table needs an optional caption/title field; the create flow needs an optional "add a few words" field; the player overlays + animates them.
   - These words can double as the card title/occasion on the shelf (one field, two payoffs) — design alongside the title/occasion + richer-cards feature.

---

## MAJOR DECISION: v1 player = NO Ken Burns (simplified playback)

Ken Burns real-time animation proved very hard to debug in the simulator and is being DEFERRED to v2. v1 ships a simpler, calmer player that still delivers the emotional core (voice + face + words/photos). This unblocks launch and validation. Ken Burns (and any server-side video compilation) is a v2 enhancement, not a launch blocker.

**Shared base for all playback modes (calm, reuses existing pieces):**
- Avatar photo in a circle in the centre (pulls the person's photo / your custom photo of them, else initials)
- Soft gradient movement in the background (reuse the existing shelf drift gradient)
- Audio waveform at the base that ONLY animates when audio is actually playing (the Waveform element already exists — tie it to audio.isPlaying)
- Always-visible close (X) button; play opens paused on this calm state, audio + visuals start on Play; ends cleanly when audio finishes

**Three message modes:**
1. **Voice only** — just the shared base (avatar + gradient + waveform).
2. **Voice + typed words** — same base, with the giver's typed words/caption shown below the avatar (the "key words" feature, minus animation-over-slideshow). Words can double as the shelf card title.
3. **Voice + photos (max 5)** — same base, plus photos shown as a GENTLE CROSS-FADE slideshow (NO pan/zoom, NO Ken Burns motion — the motion was the source of all the jank; a plain soft fade is far simpler). Fallback if fade is fiddly: a tappable swipe carousel / thumbnail strip below the avatar that the listener moves through at their own pace while audio plays.

**Why this is the right call:** the emotional value is voice + face + words, none of which need animated pan/zoom. Ships sooner, enables validation sooner, reuses avatar/gradient/waveform already built. 

**Deferred to v2:** Ken Burns pan/zoom animation (build/test on a REAL device). 
**Deferred indefinitely / maybe-never:** server-side video file compilation (expensive: rendering service, storage, per-render cost) — only revisit if users want to export/share an actual video file.

---

## Receiving loop — full intended design (decided)

The receiving loop has staged pieces. Stage 1 (shareable link + share screen in app) and Stage 2 (web taste page that plays a gift) are DONE/live. Remaining:

**Delivery model (decided):**
- NEW recipient (not yet a Justin user): giver shares a LINK (via their own Messages/WhatsApp) → recipient hears it on the web taste page → "more messages" hook invites them to install.
- ONCE the recipient IS a Justin user (converged): new gifts reach them via IN-APP + PUSH notification — no link-sharing needed. The giver's send flow should detect "is this recipient already a verified Justin user?" and, if so, deliver in-app rather than (or in addition to) producing a share link.

**Open/heard signal (decided): YES.**
- The giver should be notified when their gift is opened/heard — whether opened on the WEB taste page or IN-APP.
- Requires: recording an "opened" event when playback happens (web page logs open by token; app logs open), and notifying the giver (in-app + optionally push).
- Keep it gentle/gift-like in tone, not a demanding read-receipt.

**Stage 3 — Convergence (the key remaining build):**
- When someone installs the app and verifies a phone number that matches gifts' recipient_phone, those gifts attach to them and appear on their Shelf. (The find-or-create-by-phone foundation already exists.)
- Convergence is what turns an anonymous link-recipient into a known user we can notify and track — it's the precondition for the in-app delivery + open-signal features above.
- A pending gift sent to a phone number should attach when that phone verifies, even if the gift was sent before they joined.

**Honest limitation:** a web page cannot reliably detect whether someone INSTALLED the app — only that the App Store link was tapped, at best. Certainty of "they're now a user" comes only from convergence (phone verification). So "did they listen but not download" stays partially unknowable on web; the product answer is (a) an "opened" event on the web page so the giver at least knows it was HEARD, and (b) a compelling hook to convert them to install, after which we know for sure.

**Build order for the rest of the receiving loop:**
1. Convergence (gift attaches on phone verify) — unlocks everything else.
2. "Gift opened" event + notify giver (web logs open; app logs open).
3. In-app/push notification delivery for gifts to existing users.
4. Deep linking (link opens the app directly if installed).

---

## Idea (v2, after convergence): nudge givers to leave 2 messages on first send

Insight: the recipient's first experience is the web taste page (no app). If only ONE message exists, they hear it on web and have weak reason to download. If a SECOND message exists that they can ONLY hear in the app, the "get the app to hear them all" CTA becomes genuinely compelling. So gently nudge the giver, on their FIRST send, to record two: one "taste" (plays on web) + one that unlocks when the recipient gets the app.

Design cautions (important):
- FRAME IT AS A GIFT MECHANIC, NOT A GROWTH HACK. Warm framing: "Add another that unlocks when they get Justin — a little surprise waiting for them." NOT "record a second one we'll hide so they're forced to download." The cynical version cuts against Justin's sincere soul; the surprise-gift version fits it. Copy and intent matter a lot.
- KEEP IT GENTLE/OPTIONAL on the first send — the first send is the most fragile moment; don't add friction that causes drop-off. The giver is trying to send one heartfelt thing; suggest, don't require.
- Make the download CTA stronger specifically on the first-time path.

Dependencies / why it's v2:
- Requires CONVERGENCE to exist first — the "locked" message must actually unlock in the app when the recipient installs + verifies. Building the nudge before convergence would promise something the app can't deliver.
- Requires designating which message is the public "taste" vs the app-only one (message tiering) — interacts with how messages are grouped per recipient and the "more messages" count/pill.

Park until convergence is built; then design the two-message first-send nudge with warm, gift-like framing.
