import Foundation

/// Features that ship in later phases. A checklist item tied to a feature that
/// isn't built yet is "not applicable" instead of blocking every session.
public enum Feature: String, CaseIterable, Sendable {
    case sobrietyChallenge, exList, shortcutBundle, tabWatch, locationTrigger, checkIn

    /// Flip these on as each phase lands.
    public static let shipped: Set<Feature> = [.sobrietyChallenge]
}

/// Every Pre-Game Checklist item from SPEC §2.5.
public enum ChecklistItem: String, Codable, CodingKeyRepresentable, CaseIterable, Identifiable, Sendable {
    case screenTimeAuthorized
    case blockListSelected
    case homeAndRideApp
    case soberBaseline
    case exListProtected
    case safariCardAutofillOff
    case appStorePasswordAlways
    case walletDoubleClickOff
    case screenTimePasscodeWithFriend
    case shortcutBundleInstalled
    case nightlyBudgetSet
    case locationAlways
    case trustedContactSet

    public enum Kind: Sendable { case auto, selfConfirmed }

    public var id: String { rawValue }

    public var kind: Kind {
        switch self {
        case .exListProtected, .safariCardAutofillOff, .appStorePasswordAlways,
             .walletDoubleClickOff, .screenTimePasscodeWithFriend, .shortcutBundleInstalled:
            .selfConfirmed
        default:
            .auto
        }
    }

    public var title: String {
        switch self {
        case .screenTimeAuthorized: "Screen Time access"
        case .blockListSelected: "Something to block"
        case .homeAndRideApp: "Home address + ride app"
        case .soberBaseline: "Sober baseline taken"
        case .exListProtected: "Ex List locked down"
        case .safariCardAutofillOff: "Safari card AutoFill off"
        case .appStorePasswordAlways: "App Store always asks for password"
        case .walletDoubleClickOff: "Wallet off the side button"
        case .screenTimePasscodeWithFriend: "Screen Time passcode with a friend"
        case .shortcutBundleInstalled: "Nightcap Shortcuts installed"
        case .nightlyBudgetSet: "Nightly budget set"
        case .locationAlways: "Location set to Always"
        case .trustedContactSet: "Trusted contact picked"
        }
    }

    public var blurb: String {
        switch self {
        case .screenTimeAuthorized: "Nightcap needs this to put shields on apps."
        case .blockListSelected: "Pick at least one app, category, or site to shield."
        case .homeAndRideApp: "So the ride home is one tap, not a puzzle."
        case .soberBaseline: "Your sober scores are the bar you'll have to hit later."
        case .exListProtected: "iMessage can't be blocked per person, so iOS has to help."
        case .safariCardAutofillOff: "Otherwise a saved card is two taps from a 1 AM cart."
        case .appStorePasswordAlways: "Makes every in-app purchase stop and ask."
        case .walletDoubleClickOff: "Apple Pay shouldn't be one squeeze away."
        case .screenTimePasscodeWithFriend: "Stops Night You from switching Screen Time off."
        case .shortcutBundleInstalled: "Powers Battery Guard and Tab Watch."
        case .nightlyBudgetSet: "So Tab Watch knows when to start roasting."
        case .locationAlways: "Needed to start Nightcap when you arrive somewhere."
        case .trustedContactSet: "Who to ping if you don't check in."
        }
    }

    /// Self-confirmed items go stale: settings drift and people undo things.
    public static let confirmationLifetime: TimeInterval = 14 * 24 * 60 * 60
}

/// Facts the app gathers (some need iOS frameworks) and hands to the checklist.
public struct ChecklistContext: Sendable {
    public var now: Date
    public var shippedFeatures: Set<Feature>
    public var screenTimeAuthorized: Bool
    public var hasBlockSelection: Bool
    public var homeSaved: Bool
    public var rideAppInstalled: Bool
    public var baselineTaken: Bool
    public var exListCount: Int
    public var contactDisguiseEnabled: Bool
    public var shortcutIntentHasFired: Bool
    public var budgetSet: Bool
    public var usesLocationTrigger: Bool
    public var locationAlwaysGranted: Bool
    public var usesCheckIn: Bool
    public var trustedContactSet: Bool
    public var confirmations: [ChecklistItem: Date]

    public init(
        now: Date = .now,
        shippedFeatures: Set<Feature> = Feature.shipped,
        screenTimeAuthorized: Bool = false,
        hasBlockSelection: Bool = false,
        homeSaved: Bool = false,
        rideAppInstalled: Bool = false,
        baselineTaken: Bool = false,
        exListCount: Int = 0,
        contactDisguiseEnabled: Bool = false,
        shortcutIntentHasFired: Bool = false,
        budgetSet: Bool = false,
        usesLocationTrigger: Bool = false,
        locationAlwaysGranted: Bool = false,
        usesCheckIn: Bool = false,
        trustedContactSet: Bool = false,
        confirmations: [ChecklistItem: Date] = [:]
    ) {
        self.now = now
        self.shippedFeatures = shippedFeatures
        self.screenTimeAuthorized = screenTimeAuthorized
        self.hasBlockSelection = hasBlockSelection
        self.homeSaved = homeSaved
        self.rideAppInstalled = rideAppInstalled
        self.baselineTaken = baselineTaken
        self.exListCount = exListCount
        self.contactDisguiseEnabled = contactDisguiseEnabled
        self.shortcutIntentHasFired = shortcutIntentHasFired
        self.budgetSet = budgetSet
        self.usesLocationTrigger = usesLocationTrigger
        self.locationAlwaysGranted = locationAlwaysGranted
        self.usesCheckIn = usesCheckIn
        self.trustedContactSet = trustedContactSet
        self.confirmations = confirmations
    }
}

public struct ChecklistEntry: Identifiable, Equatable, Sendable {
    public enum Level: Sendable { case required, recommended }

    public enum Status: Equatable, Sendable {
        case done
        case missing
        /// Was self-confirmed, but more than 14 days ago.
        case expired(confirmedAt: Date)
    }

    public let item: ChecklistItem
    public let level: Level
    public let status: Status

    public var id: ChecklistItem { item }
    public var isDone: Bool { status == .done }
}

public struct ChecklistReport: Sendable {
    /// Applicable items only, required first.
    public let entries: [ChecklistEntry]

    public init(_ context: ChecklistContext) {
        entries = ChecklistItem.allCases
            .compactMap { item in
                level(of: item, in: context).map { ChecklistEntry(item: item, level: $0, status: status(of: item, in: context)) }
            }
            .sorted { lhs, rhs in lhs.level == .required && rhs.level == .recommended }
    }

    /// Protection Score numerator / denominator, e.g. "7/9 covered".
    public var covered: Int { entries.filter(\.isDone).count }
    public var total: Int { entries.count }

    /// Required items that aren't done. Any of these block a manual start.
    public var blockers: [ChecklistEntry] { entries.filter { $0.level == .required && !$0.isDone } }

    /// True when the only blockers are stale self-confirmations, which the
    /// pre-session "Still set up?" hold can renew in one go.
    public var blockedOnlyByExpiry: Bool {
        !blockers.isEmpty && blockers.allSatisfy { if case .expired = $0.status { true } else { false } }
    }

    /// Self-confirmed items the user has confirmed at some point (current or
    /// stale). These are what the pre-session quick screen re-confirms.
    public var reconfirmable: [ChecklistItem] {
        entries.filter { entry in
            guard entry.item.kind == .selfConfirmed else { return false }
            switch entry.status {
            case .expired: return true
            case .done: return true
            case .missing: return false
            }
        }.map(\.item)
    }

    /// Whether the user may start a session after holding to re-confirm.
    public var canStartAfterReconfirm: Bool { blockers.isEmpty || blockedOnlyByExpiry }
}

// MARK: - Rules

/// nil means the item doesn't apply right now (feature not shipped or not in use).
private func level(of item: ChecklistItem, in c: ChecklistContext) -> ChecklistEntry.Level? {
    func ifShipped(_ feature: Feature, _ level: ChecklistEntry.Level) -> ChecklistEntry.Level? {
        c.shippedFeatures.contains(feature) ? level : nil
    }
    switch item {
    case .screenTimeAuthorized, .blockListSelected, .homeAndRideApp,
         .safariCardAutofillOff, .appStorePasswordAlways:
        return .required
    case .walletDoubleClickOff, .screenTimePasscodeWithFriend:
        return .recommended
    case .soberBaseline:
        return ifShipped(.sobrietyChallenge, .required)
    case .exListProtected:
        return c.exListCount > 0 ? ifShipped(.exList, .required) : nil
    case .shortcutBundleInstalled:
        return ifShipped(.shortcutBundle, .recommended)
    case .nightlyBudgetSet:
        return ifShipped(.tabWatch, .recommended)
    case .locationAlways:
        return c.usesLocationTrigger ? ifShipped(.locationTrigger, .required) : nil
    case .trustedContactSet:
        return c.usesCheckIn ? ifShipped(.checkIn, .required) : nil
    }
}

private func status(of item: ChecklistItem, in c: ChecklistContext) -> ChecklistEntry.Status {
    func auto(_ ok: Bool) -> ChecklistEntry.Status { ok ? .done : .missing }

    switch item {
    case .screenTimeAuthorized: return auto(c.screenTimeAuthorized)
    case .blockListSelected: return auto(c.hasBlockSelection)
    case .homeAndRideApp: return auto(c.homeSaved && c.rideAppInstalled)
    case .soberBaseline: return auto(c.baselineTaken)
    case .nightlyBudgetSet: return auto(c.budgetSet)
    case .locationAlways: return auto(c.locationAlwaysGranted)
    case .trustedContactSet: return auto(c.trustedContactSet)
    // Hybrid items: auto-verified when Nightcap can see it, otherwise self-confirmed.
    case .exListProtected where c.contactDisguiseEnabled: return .done
    case .shortcutBundleInstalled where c.shortcutIntentHasFired: return .done
    case .exListProtected, .shortcutBundleInstalled, .safariCardAutofillOff,
         .appStorePasswordAlways, .walletDoubleClickOff, .screenTimePasscodeWithFriend:
        guard let confirmedAt = c.confirmations[item] else { return .missing }
        return c.now.timeIntervalSince(confirmedAt) < ChecklistItem.confirmationLifetime ? .done : .expired(confirmedAt: confirmedAt)
    }
}
