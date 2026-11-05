# Nightcap

Puts your phone into a protective "Nightcap Mode" while you're out drinking. See [SPEC.md](SPEC.md) for the full product spec.

## Status

**Phase 1 — Core lock** is written:

- Xcode project with the app + 3 extensions (Monitor, ShieldConfig, ShieldAction), shared App Group
- Screen Time authorization + `FamilyActivityPicker` for block list, allowlist, and food delivery apps
- Manual start with end time (default 6 AM), DeviceActivity timer that clears shields even if the app is killed
- Custom shield screen + shield buttons (attempts logged for the future recap)
- Allowlist (ride apps stay open inside blocked categories)
- Web loophole closer: blocked categories also cover their websites, plus curated domain packs; Strict mode
- Food delivery allow / block / "ask first"
- Pre-Game Checklist with auto and hold-to-confirm items, walkthroughs, 14-day expiry, the "Still set up?" screen, activation gate, Protection Score
- Ride home button (Uber/Lyft deep links)

**Phase 2 — Sobriety Challenge** is written:

- Reaction time (5 rounds, touch-down timing, false starts), typing (random sentence, clock starts on first key, paste detection), memory (Simon-style, 5–6 pads)
- Sober baseline from the checklist or Settings (blocked during a session); absolute limits so a deliberately slow baseline doesn't help
- Difficulty (Relaxed / Standard / Strict), 15-minute cooldown, locked for the night after 3 fails
- Passing unlocks the rest of the night, or just the tapped app for 10 minutes (setting)
- "End early" now goes through the challenge

Not yet: schedules/locations, Ex List, recap, Battery Guard, Tab Watch, full onboarding.

## Setup

1. Install **Xcode 15.4+** (Xcode 16 needs macOS 14.5+).
2. `brew install xcodegen && xcodegen generate` (re-run after adding files or editing `project.yml`).
3. Sign in to Xcode with your developer account (Settings → Accounts). The Team ID is already set in `project.yml`.
4. If `com.charlottedemas` is taken or not yours, change the bundle prefix and App Group in `project.yml` **and** `AppGroup.identifier` in `Packages/NightcapCore/Sources/NightcapCore/Storage.swift`.
5. Run on a **real iPhone** — the simulator doesn't support Screen Time APIs.
6. Request the **Family Controls (Distribution)** entitlement from Apple now; it's required for TestFlight and takes a while. Development builds work without it.

## Layout

| Path | What |
|---|---|
| `Packages/NightcapCore` | Pure Foundation logic: settings, sessions, checklist rules, walkthrough copy, domain packs, ride links. Unit-tested. |
| `Shared/` | iOS code compiled into the app and every extension: selections, `ShieldController`, DeviceActivity scheduling, brand colors. |
| `Nightcap/` | The SwiftUI app. |
| `NightcapMonitor/`, `NightcapShieldConfig/`, `NightcapShieldAction/` | The three Screen Time extensions. |

Tests: run the `Nightcap` scheme's tests in Xcode (or `swift test` in `Packages/NightcapCore` with Xcode installed).

## Verified vs. still to check on device

- ✅ Messages *can* be shielded if picked as an individual app; category shields skip it while it's in iOS's Always Allowed list. Phone can't be picked. Nightcap can't shield itself. (Apple dev forums.)
- ✅ The web filter takes at most 50 domains (Apple docs); some developers report 49 in practice, so packs are capped at 49.
- ☐ Shield "prove it" button → notification → app. Confirm the notification posts from the ShieldAction extension.
- ☐ "Just that app" unlocks re-shield after 10 minutes. DeviceActivity needs 15-minute intervals, so the timer is backdated; if iOS rejects that, the unlock lasts 15 minutes instead.
- ☐ `denyAppRemoval` blocks deleting Nightcap mid-session without side effects you dislike.
- ☐ Walkthrough Settings paths on your iOS version; add screenshots to the asset catalog using the names in `Walkthroughs.swift`.
