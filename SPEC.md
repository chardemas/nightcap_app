# Nightcap — Product & Technical Spec

## 1. What Nightcap is

Nightcap is an iPhone app that puts your phone into a protective "Nightcap Mode" while you're drinking. In Nightcap Mode you can't text your ex, can't make impulse purchases (rides home are always allowed), and can't post to social media. Getting out of Nightcap Mode early requires passing a sobriety challenge. The next morning you get a recap of what Nightcap stopped you from doing.

**Tone:** friendly, a little cheeky, never preachy. It's a wingman, not a parent.

**Platform:** iOS only for v1. SwiftUI, iOS 17+.

---

## 2. Feature list (v1)

### 2.1 Activation — three ways to turn Nightcap Mode on

| Trigger | Behavior |
|---|---|
| **Manual toggle** | Big "Start Nightcap" button on the home screen. User picks an end time (default: 6:00 AM next morning). |
| **Schedule** | User sets recurring windows (e.g. Fri & Sat, 10 PM–6 AM). Mode turns on and off automatically. |
| **Location** | User saves places (favorite bars, a friend's place) and/or a home location. Mode turns on when arriving at a saved place, or when leaving home after a user-set hour (e.g. after 9 PM). |

### 2.2 Restrictions while Nightcap Mode is on

- **The Ex List** — user picks contacts they shouldn't be messaging. Nightcap blocks the messaging apps used to reach them (see Known Limitations §5 — per-contact blocking in iMessage is not possible via public APIs).
- **Purchase lock** — block shopping apps and shopping websites, deny in-app purchases. **Always allowed:** ride-hailing and transit apps (Uber, Lyft, Curb, Revel, local transit apps, Maps). Allowlist is user-editable.
- **Social media lock** — shield posting apps the user selects (Instagram, X, TikTok, Snapchat, Facebook, etc.).
- **Dating apps lock** — included in the default suggested block list.
- **Money apps lock** — Venmo, Cash App, Zelle/banking apps, PayPal (no drunk "lending" or sending).
- **Gambling & trading lock** — sports betting (DraftKings, FanDuel, etc.), casino apps, stock and crypto trading apps.
- **Work lock** — email, Slack, Teams (no 1 AM message to the boss). Off by default, suggested in onboarding.
- **Web loophole closer** — whenever an app is blocked, also block its website (instagram.com, amazon.com, venmo.com, etc.) via `shield.webDomains`, so Safari isn't an easy way around the block. Optional **Strict mode** shields Safari and other browsers entirely during a session.
- **Food delivery** — user's choice in onboarding: allow, block, or cap (show a "you sure?" prompt via shield, then allow).
- **Never blocked:** Phone (emergency calls), Maps, ride-hailing apps, Nightcap itself.

### 2.2a Ex List — temporary contact hiding

Since iMessage can't be blocked per contact (§5), Nightcap adds friction at the contact level:

- **Contact disguise (opt-in):** at session start, Nightcap uses the Contacts framework (`CNSaveRequest`) to rename each Ex List contact to "🌙 Not tonight" and temporarily removes their phone numbers and emails. They're restored automatically when the session ends.
  - Before any change, Nightcap saves a full backup of each contact to the App Group container. Restore on session end, on app launch if a session ended while the app was closed, and via a "Restore contacts now" button in Settings.
  - Message threads in Messages will still exist and may show the raw number. This is a speed bump, not a wall. Say so in onboarding.
  - Claude Code: verify whether extensions can write to Contacts. If not, run the disguise from the main app (at manual start, or when a schedule-triggered notification is tapped) and restore on next launch.
- **iOS setup walkthroughs** (see §2.5) for the native, stronger options: Screen Time Communication Limits during Downtime, or blocking the contact outright.

### 2.2b Battery Guard — save your battery for the ride home

A dead phone at 2 AM means no Uber, no Maps, no calling a friend. Battery Guard protects a reserve.

- **Session start check:** if Nightcap Mode starts below 50%, notify: "You're heading out at 41%. Charge up or bring a battery pack."
- **Tiered alerts during a session** (thresholds user-editable):
  - **30%** — "30% left. Save it for the ride home." Turns on Low Power Mode (via Shortcut, see below).
  - **20%** — **Battery Lockdown**: shields battery-heavy, non-essential apps (video, games, social, camera-heavy apps, streaming music optional). Essentials stay open: Phone, Messages to trusted contact, Maps, ride apps, Nightcap.
  - **15%** — "Order your ride NOW while you still can," with the one-tap ride button.
  - **10%** — offers to send the trusted contact a "my phone's about to die, I'm at [location]" message.
- **How it runs in the background:** iOS apps can't monitor battery level while suspended. Use a **Shortcuts personal automation** ("When battery level falls below X%") that runs Nightcap **App Intents**:
  - `BatteryAlertIntent(level:)` — checks if a session is active, sends the right notification, applies the matching tier.
  - Shortcut also runs the built-in **Set Low Power Mode** action (Nightcap can't toggle Low Power Mode itself).
  - Ship a ready-made Shortcut (iCloud share link) the user installs in one tap, set to run without asking.
  - While the app is in the foreground, also read `UIDevice.current.batteryLevel` directly.
- Battery Lockdown lifts when the session ends or when the phone is charging (Shortcut automation "When charger is connected" → `BatteryAlertIntent`).

### 2.2c Tab Watch — spending tracker that roasts you

Nightcap watches what you spend at bars, restaurants, and on late-night food during a session, and roasts you as it adds up.

- **Nightly budget:** set in onboarding (e.g. $80). Can adjust per session at start.
- **What counts:** bars/nightclubs, restaurants, liquor stores, food delivery, convenience stores. Uses merchant category codes when available (MCC 5813 drinking places, 5812 restaurants, 5921 liquor stores, 5814 fast food, 5499/5411 convenience/grocery) plus a keyword fallback on merchant name.
- **Data sources (in priority order):**
  1. **Shortcuts "Transaction" automation** — fires when the user taps a Wallet card with Apple Pay; passes merchant and amount to a Nightcap App Intent `LogPurchaseIntent(merchant:amount:card:)`. Works for any card in Wallet. Ship this in the same one-tap Shortcut bundle as Battery Guard.
  2. **FinanceKit** (Apple Card / Apple Cash / Apple Savings only in the US) — reads transactions directly with merchant category. Needs a separate FinanceKit entitlement from Apple. Optional, v2.
  3. **Manual "add to tab"** button for cash, cards outside Wallet, or bars that run a tab you pay at the end.
- **The Roast** — notification tone escalates as spending passes budget thresholds. User picks the heat level in settings: **Mild / Spicy / Savage**. Example lines (Spicy):
  - 50%: "Halfway through the budget and it's 11:40. Pace yourself, champ."
  - 100%: "That's the budget. Every drink from here is a loan from Morning You."
  - 150%: "$127 at Dante. You could have bought a bottle and a nap."
  - 200%: "At this point the bartender should be paying YOU rent. Ride home?" (with ride button)
  - Rapid repeat purchases (3+ in 30 min): "Three taps in half an hour. You're not buying rounds for strangers, are you?"
  - Generate a pool of 30+ lines per heat level so it doesn't repeat. Roasts are about **spending and decisions only** — never about the user's body, looks, or identity.
- **Over-budget escalation (opt-in):** at 200% of budget, offer to share the tab with the trusted contact ("Want Sam to know you're at $160?").
- **Morning recap** includes the night's total, spend per place, and one final roast ("$184. That's 23 Ubers home. Think about it.").
- Purchases are only tracked during active sessions. Amounts and merchant names stay on device.

### 2.3 Early unlock — Sobriety Challenge

- When the user taps a blocked app, the shield screen says something like "Nightcap's got you 🌙" with a button: **"I'm sober — let me prove it."**
- That opens Nightcap, which runs a challenge. Must pass **all** of:
  1. **Reaction time** — tap when the screen changes color, 5 rounds.
  2. **Typing test** — type a randomly chosen sentence accurately within a time limit.
  3. **Memory sequence** — repeat a 5–6 item sequence (Simon-style).
- **Baseline calibration:** during onboarding, the user takes the challenge sober. Passing at night requires scoring within a set tolerance of their own baseline (e.g. reaction time no more than 25% slower).
- Failing triggers a **15-minute cooldown** before another attempt. After 3 fails, locked until the scheduled end time.
- Passing unlocks for the rest of the session (or optionally: unlocks just the one app for 10 minutes — make this a setting).

### 2.4 Safety extras

- **One-tap ride home** — a large button on the Nightcap home screen and in the Nightcap Mode notification. Opens Uber or Lyft (user's preference) with the destination set to their saved home address via deep link.
- **Get-home-safe check-in** — when Nightcap Mode starts, the user can enable a check-in. At a chosen time (or when the session ends), Nightcap asks "Home safe?" If the user doesn't confirm within 30 minutes (after one reminder), Nightcap notifies a chosen trusted contact with the user's last known location. Requires a small backend (see §4.4).
- **Morning recap** — the next morning, a notification opens a recap screen: session length, how many times each blocked app was attempted, "You tried to open Messages 4 times. Morning You says thanks." Playful, never shaming. No message content is ever captured.

### 2.5 Pre-Game Checklist — Nightcap Mode won't start until it's done

Some protections can't be enforced by the app, only by the user changing iOS settings. The Pre-Game Checklist makes that unavoidable: **Nightcap Mode cannot be started (manually or by schedule/location) until all Required items are complete.**

Each item is one of two kinds:

- **Auto-verified ✅** — Nightcap checks it itself and shows a green check. User can't fake it.
- **Self-confirmed ☑️** — Nightcap can't see iOS settings, so the user must open a step-by-step "Show me how" walkthrough (screenshots + exact Settings path), do it, then confirm with a deliberate hold-to-confirm button ("I did this — hold to confirm"). Never a single casual tap.

| Item | Kind | Level |
|---|---|---|
| Screen Time permission granted | Auto | Required |
| At least one block list selected (messaging/social/shopping) | Auto | Required |
| Home address saved + ride app installed (`canOpenURL`) | Auto | Required |
| Sober baseline challenge taken | Auto | Required |
| Ex List contacts: Communication Limits set during Downtime, Downtime schedule matches Nightcap schedule — **or** contacts blocked in iOS — **or** contact disguise turned on | Self (disguise = Auto) | Required if Ex List isn't empty |
| Safari AutoFill for credit cards turned off | Self | Required |
| App Store / iTunes purchases set to "Always require password" (Screen Time → Content & Privacy) | Self | Required |
| Apple Pay: remove Wallet from Lock Screen double-click | Self | Recommended |
| Screen Time passcode set and given to a trusted friend (prevents switching off Screen Time at night) | Self | Recommended |
| Nightcap Shortcut bundle installed (battery + transaction automations), set to "Run Immediately" | Self (Auto once an intent has fired at least once) | Recommended |
| Nightly budget set | Auto | Recommended |
| Location permission "Always" (only if location trigger is used) | Auto | Required for that trigger |
| Trusted contact set (only if check-in is used) | Auto | Required for that feature |

**Staying current:**

- Self-confirmed items **expire after 14 days** and must be re-confirmed (settings drift, people undo things).
- Before each manual session: one quick screen — "Still set up? Ex limits ✓, Safari cards off ✓, purchase password ✓" with a single hold-to-confirm for all of them.
- If a scheduled or location session is coming up and the checklist is incomplete or expired, send a notification **in the afternoon, while the user is sober**: "Tonight's Nightcap starts at 10. 2 things to check first." If still incomplete when the session should start, start it anyway with whatever *can* be enforced, and send a notification listing what's not covered.
- Home screen shows a **Protection Score** (e.g. "7/9 covered") with the missing items one tap away.

**Loophole detection:**

- If Screen Time authorization is revoked during a session (check `AuthorizationCenter.shared.authorizationStatus` on launch and in the monitor extension), log it, show it in the morning recap, and — if the user opted in — notify the trusted contact.
- If contact disguise is undone manually during a session, log it for the recap.
- Tone stays playful in the recap: "You turned off Screen Time at 1:12 AM. Bold move."

### 2.6 Onboarding

1. Explain what Nightcap does (3 short screens).
2. Request Screen Time authorization (`FamilyControls`, `.individual`).
3. Pick apps/categories to block (Apple's `FamilyActivityPicker`). Pre-suggest: messaging, social, shopping, dating.
4. Set the Ex List (contacts — used for the recap and guidance, see §5).
5. Save home address + preferred ride app.
6. Pick a trusted contact for check-ins (optional).
7. Take the sober baseline challenge.
8. Set up schedule and/or locations (optional; can do later).
9. Run the **Pre-Game Checklist** (§2.5). Onboarding ends on the Protection Score screen. Be upfront: "Nightcap can block apps for you, but a few iOS settings only you can change. Here's exactly how."

---

## 3. Screens

- **Home** — status (On/Off, ends at X), Start/Stop button, One-tap Ride Home button.
- **Active session** — dark, calm "night" theme; time remaining, ride home, check-in status.
- **Sobriety Challenge** — three-step flow, results screen.
- **Morning Recap**
- **Settings** — block lists, allowlist, Ex List, schedules, locations, trusted contact, home address, ride app, challenge difficulty, re-take baseline.

Visual style: deep navy/midnight background, warm amber accent (a "nightcap" drink glow), rounded friendly type. Dark mode first.

---

## 4. Technical architecture

### 4.1 Apple frameworks

- **FamilyControls** — authorization (`AuthorizationCenter.shared.requestAuthorization(for: .individual)`) and `FamilyActivityPicker` for selecting apps/categories/web domains.
- **ManagedSettings** — apply restrictions via `ManagedSettingsStore`:
  - `shield.applications`, `shield.applicationCategories`, `shield.webDomains`
  - `appStore.denyInAppPurchases = true`
  - Use a **named store** (e.g. `ManagedSettingsStore(named: .nightcap)`) so clearing is clean.
- **DeviceActivity** — schedules (`DeviceActivityCenter.startMonitoring`) for scheduled sessions and the end time of manual sessions.
- **CoreLocation** — region monitoring (geofences) for saved places and home. Requires "Always" location permission. iOS limits monitoring to 20 regions per app.

### 4.2 Targets (Xcode)

| Target | Purpose |
|---|---|
| `Nightcap` (app) | Main SwiftUI app |
| `NightcapMonitor` | DeviceActivityMonitor extension — applies/clears shields when schedules start/end |
| `NightcapShieldConfig` | ShieldConfiguration extension — custom shield screen text/branding |
| `NightcapShieldAction` | ShieldActionDelegate extension — handles shield button taps, logs attempts for the recap |
| `NightcapReport` (optional) | DeviceActivityReport extension if usage stats are wanted in the recap |

Also add **App Intents** to the main app (`BatteryAlertIntent`, `LogPurchaseIntent`, `StartNightcapIntent`, `RideHomeIntent`) so Shortcuts and Siri can call them.

All targets share an **App Group** (e.g. `group.com.yourname.nightcap`) for settings, session state, and the attempt log.

### 4.3 Data (local, on-device)

- `NightcapSettings` — selections (`FamilyActivitySelection`, Codable), allowlist, ex list contact IDs, home address + coordinates, ride app pref, trusted contact, challenge baseline, schedules, saved places.
- `Session` — start, planned end, actual end, trigger type, unlocked early (bool), challenge attempts.
- `BlockedAttempt` — timestamp, app/category token, session ID. (Logged from the ShieldAction extension.)
- Store in the App Group container (SwiftData or JSON files). No message content, browsing content, or app content is ever stored.

### 4.4 Backend (only for the get-home-safe check-in)

iOS apps cannot send SMS silently, so the "notify trusted contact" step needs a server:

- **Supabase** (database + Edge Function) + **Twilio** for SMS.
- Flow: app registers a check-in with a deadline → if not confirmed by the deadline, an Edge Function (on a cron/scheduled job) sends an SMS to the trusted contact with a short message and last known location link.
- Fallback if no backend yet: a local notification prompting the user to send a pre-written iMessage themselves (`MFMessageComposeViewController`). Build this fallback first.

### 4.5 Ride deep links

- Uber: `uber://?action=setPickup&pickup=my_location&dropoff[latitude]=LAT&dropoff[longitude]=LNG&dropoff[nickname]=Home`
- Lyft: `lyft://ridetype?id=lyft&destination[latitude]=LAT&destination[longitude]=LNG`
- Fall back to the App Store / web link if the app isn't installed. Add `uber` and `lyft` to `LSApplicationQueriesSchemes`.

---

## 5. Known limitations — Claude Code: verify these against current Apple docs before building

1. **Per-contact blocking in iMessage is not available** through public APIs. Screen Time's native "Communication Limits" isn't exposed to third-party apps. v1 approach:
   - Shield the messaging apps the user chose (WhatsApp, Instagram, Snapchat, etc.). Check whether Apple's Messages app can be shielded via `FamilyActivityPicker` on current iOS; if not, document it in-app.
   - In onboarding, offer a guided walkthrough for setting up iOS's own Communication Limits / Downtime for the Ex List contacts as a complementary layer.
   - The Ex List is still used for the morning recap and for copy ("Nightcap hid [Name]'s chats tonight" only if technically true — don't overclaim).
2. **Apple Pay and saved cards in Safari can't be blocked directly.** Block shopping apps, shopping web domains, and in-app purchases. Be honest in onboarding about what is and isn't covered.
3. **Phone calls can't be shielded** (and shouldn't be — emergency access).
4. **Shield screens can't host custom UI** like the challenge. The shield button sends the user into the main app, where the challenge runs.
5. **Family Controls distribution entitlement** must be requested from Apple before TestFlight/App Store. Development works on-device with the development entitlement. Start the request early.
6. **The simulator does not support Screen Time APIs.** Test on a real iPhone.
7. Location-triggered activation needs "Always" location permission and a clear explanation of why.
8. **Self-confirmed checklist items can't be verified.** Apps can't read other iOS settings, and Apple only allows opening the app's own Settings page (`UIApplication.openSettingsURLString`), not deep links into Screen Time or Wallet. Walkthroughs must use screenshots and exact menu paths. Keep them updated for the current iOS version.
9. **Removing Screen Time permission or deleting the app** lifts the shields. Check whether `.individual` authorization requires Apple ID authentication to revoke on current iOS, and recommend the Screen Time passcode-with-a-friend step either way.
10. **Battery and spending rely on Shortcuts automations** the user must install. Verify on current iOS: that the battery-level and Transaction triggers can run without a confirmation prompt, exactly which fields the Transaction trigger passes (merchant, amount, card), and that App Intents can apply ManagedSettings shields when invoked from Shortcuts in the background.
11. **No source sees every purchase.** Cash, physical card swipes, and cards not in Wallet are invisible. Say so plainly and lean on the manual "add to tab" button.
12. **Contact disguise edits real user data.** Back up before every change, restore defensively, and never ship it without thorough tests of crash/kill-during-session cases.

---

## 6. Build phases

**Phase 1 — Core lock (MVP)**
- Xcode project, App Group, all extension targets
- FamilyControls authorization + FamilyActivityPicker
- Manual Start/Stop with end time; apply/clear ManagedSettings
- Custom shield screen
- Allowlist for ride apps
- Matching website blocks for every blocked app
- Pre-Game Checklist with auto-verified items, self-confirmed items + walkthroughs, the activation gate, and the Protection Score

**Phase 1b — Ex List**
- Contact disguise with backup/restore (opt-in)
- Communication Limits / block-contact walkthroughs

**Phase 2 — Sobriety Challenge**
- Three tests + baseline calibration in onboarding
- Unlock flow from the shield, cooldowns, fail limits

**Phase 3 — Automatic activation**
- DeviceActivity schedules
- CoreLocation saved places + "leaving home after X PM"

**Phase 4 — Safety extras**
- One-tap ride home
- Attempt logging + morning recap (including loophole events)
- Afternoon "checklist incomplete" reminders before scheduled sessions
- App Intents + shareable Shortcut bundle
- Battery Guard tiers and Battery Lockdown
- Tab Watch: budget, purchase logging, The Roast (three heat levels, 30+ lines each), spend in morning recap
- (v2) FinanceKit integration
- Check-in with local fallback, then Supabase + Twilio backend

**Phase 5 — Polish**
- Full onboarding flow, settings, visual design pass, copy pass, App Store assets

---

## 7. Privacy principles

- Everything stays on device except the check-in (deadline, trusted contact phone number, last location — deleted after the check-in resolves).
- No message content, browsing history, or purchase details are ever read or stored.
- No analytics in v1.

## 8. Open questions for later

- Monetization (free / one-time purchase / subscription)?
- Android version?
- "Buddy mode": friends can see each other's Nightcap status?
- Ability for a friend to trigger Nightcap Mode remotely?
