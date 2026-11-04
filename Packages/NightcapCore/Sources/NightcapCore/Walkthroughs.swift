import Foundation

/// "Show me how" content for self-confirmed checklist items.
///
/// Apps can't deep-link into Screen Time or Wallet settings (SPEC §5.8), so
/// these are exact menu paths. Paths differ between iOS 17 and iOS 18+ (18
/// moved per-app settings under Settings → Apps), so both are listed where
/// they differ. Re-check every major iOS release.
public struct Walkthrough: Sendable {
    public let item: ChecklistItem
    public let why: String
    public let steps: [String]
    /// Name of a screenshot in the asset catalog, if one has been added.
    public let screenshot: String?
    public let caveat: String?
}

extension ChecklistItem {
    public var walkthrough: Walkthrough? {
        switch self {
        case .safariCardAutofillOff:
            Walkthrough(
                item: self,
                why: "Nightcap can block shopping sites it knows about, but a saved card in Safari works on every other site.",
                steps: [
                    "Open Settings.",
                    "iOS 18 or later: tap Apps, then Safari. iOS 17: scroll down and tap Safari.",
                    "Tap AutoFill.",
                    "Turn off Credit Cards.",
                ],
                screenshot: "walkthrough-safari-autofill",
                caveat: "Cards saved in other browsers (Chrome, etc.) have their own setting. Turn those off too."
            )
        case .appStorePasswordAlways:
            Walkthrough(
                item: self,
                why: "Nightcap already denies in-app purchases during a session. This makes the App Store ask for your password every time, session or not.",
                steps: [
                    "Open Settings → Screen Time.",
                    "Tap Content & Privacy Restrictions and turn it on if it's off.",
                    "Tap App Store, Media, Web & Games (called iTunes & App Store Purchases on older versions).",
                    "Under Require Password, choose Always Require.",
                ],
                screenshot: "walkthrough-appstore-password",
                caveat: nil
            )
        case .walletDoubleClickOff:
            Walkthrough(
                item: self,
                why: "Double-clicking the side button pulls up Apple Pay from the Lock Screen. Nightcap can't block Apple Pay, so take away the shortcut.",
                steps: [
                    "Open Settings → Wallet & Apple Pay.",
                    "Turn off Double-Click Side Button (Double-Click Home Button on iPhones with a Home button).",
                ],
                screenshot: "walkthrough-wallet-doubleclick",
                caveat: "Apple Pay still works from inside the Wallet app. This is a speed bump."
            )
        case .screenTimePasscodeWithFriend:
            Walkthrough(
                item: self,
                why: "Turning off Screen Time lifts every Nightcap shield. A passcode only a friend knows means Night You can't do that.",
                steps: [
                    "Hand your phone to someone you trust.",
                    "Open Settings → Screen Time.",
                    "Tap Lock Screen Time Settings (Use Screen Time Passcode on older versions).",
                    "Have your friend type a passcode you don't know, and keep it.",
                    "If asked for an Apple Account for passcode recovery, you can skip it, or use yours if you want a way back in.",
                ],
                screenshot: "walkthrough-screentime-passcode",
                caveat: "Pick a friend who'll answer the phone on a Sunday when you need it changed."
            )
        case .exListProtected:
            Walkthrough(
                item: self,
                why: "iOS doesn't let apps block one person in Messages. Screen Time's Communication Limits can, so Nightcap walks you through it.",
                steps: [
                    "Open Settings → Screen Time → Downtime and set a schedule that matches your Nightcap nights.",
                    "Go back and tap Communication Limits → During Downtime.",
                    "Choose Specific Contacts, and leave your Ex List people out.",
                    "Or, the nuclear option: open the contact, tap Block Contact.",
                ],
                screenshot: "walkthrough-communication-limits",
                caveat: "Existing Messages threads still exist. Communication Limits blocks new messages during Downtime."
            )
        case .shortcutBundleInstalled:
            Walkthrough(
                item: self,
                why: "Battery Guard and Tab Watch run through Shortcuts automations, because iOS doesn't let apps watch battery or Apple Pay in the background.",
                steps: [
                    "Tap Install Shortcuts in Nightcap and add the shared Shortcut.",
                    "Open Shortcuts → Automation and check each Nightcap automation is set to Run Immediately.",
                ],
                screenshot: nil,
                caveat: nil
            )
        default:
            nil
        }
    }
}
