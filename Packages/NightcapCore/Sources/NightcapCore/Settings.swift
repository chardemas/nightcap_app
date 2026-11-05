import Foundation

/// Everything about the user's setup that isn't a FamilyControls selection.
/// (App/category selections live in `BlockSelections` in the iOS-only Shared
/// folder, because `FamilyActivitySelection` only exists on iOS.)
public struct NightcapSettings: Codable, Equatable, Sendable {
    public var home: HomeAddress?
    public var rideApp: RideApp
    public var webPacks: Set<WebDomainPack>
    public var strictMode: Bool
    public var denyInAppPurchases: Bool
    public var denyAppRemoval: Bool
    public var foodDelivery: FoodDeliveryPolicy
    /// When the user last hold-confirmed each self-confirmed checklist item.
    public var selfConfirmations: [ChecklistItem: Date]

    public var baseline: ChallengeBaseline?
    public var challengeDifficulty: ChallengeDifficulty
    public var unlockScope: UnlockScope

    // Placeholders for later phases, so the checklist can already reason about them.
    public var exListContactIDs: [String]
    public var contactDisguiseEnabled: Bool

    public init(
        home: HomeAddress? = nil,
        rideApp: RideApp = .uber,
        webPacks: Set<WebDomainPack> = WebDomainPack.defaultOn,
        strictMode: Bool = false,
        denyInAppPurchases: Bool = true,
        denyAppRemoval: Bool = true,
        foodDelivery: FoodDeliveryPolicy = .cap,
        selfConfirmations: [ChecklistItem: Date] = [:],
        baseline: ChallengeBaseline? = nil,
        challengeDifficulty: ChallengeDifficulty = .standard,
        unlockScope: UnlockScope = .wholeSession,
        exListContactIDs: [String] = [],
        contactDisguiseEnabled: Bool = false
    ) {
        self.home = home
        self.rideApp = rideApp
        self.webPacks = webPacks
        self.strictMode = strictMode
        self.denyInAppPurchases = denyInAppPurchases
        self.denyAppRemoval = denyAppRemoval
        self.foodDelivery = foodDelivery
        self.selfConfirmations = selfConfirmations
        self.baseline = baseline
        self.challengeDifficulty = challengeDifficulty
        self.unlockScope = unlockScope
        self.exListContactIDs = exListContactIDs
        self.contactDisguiseEnabled = contactDisguiseEnabled
    }

    // Decode field-by-field with defaults so settings saved by an older build
    // still load after new fields are added.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = NightcapSettings()
        home = try c.decodeIfPresent(HomeAddress.self, forKey: .home)
        rideApp = try c.decodeIfPresent(RideApp.self, forKey: .rideApp) ?? d.rideApp
        webPacks = try c.decodeIfPresent(Set<WebDomainPack>.self, forKey: .webPacks) ?? d.webPacks
        strictMode = try c.decodeIfPresent(Bool.self, forKey: .strictMode) ?? d.strictMode
        denyInAppPurchases = try c.decodeIfPresent(Bool.self, forKey: .denyInAppPurchases) ?? d.denyInAppPurchases
        denyAppRemoval = try c.decodeIfPresent(Bool.self, forKey: .denyAppRemoval) ?? d.denyAppRemoval
        foodDelivery = try c.decodeIfPresent(FoodDeliveryPolicy.self, forKey: .foodDelivery) ?? d.foodDelivery
        selfConfirmations = try c.decodeIfPresent([ChecklistItem: Date].self, forKey: .selfConfirmations) ?? d.selfConfirmations
        baseline = try c.decodeIfPresent(ChallengeBaseline.self, forKey: .baseline)
        challengeDifficulty = try c.decodeIfPresent(ChallengeDifficulty.self, forKey: .challengeDifficulty) ?? d.challengeDifficulty
        unlockScope = try c.decodeIfPresent(UnlockScope.self, forKey: .unlockScope) ?? d.unlockScope
        exListContactIDs = try c.decodeIfPresent([String].self, forKey: .exListContactIDs) ?? d.exListContactIDs
        contactDisguiseEnabled = try c.decodeIfPresent(Bool.self, forKey: .contactDisguiseEnabled) ?? d.contactDisguiseEnabled
    }
}

public struct HomeAddress: Codable, Equatable, Sendable {
    public var label: String
    public var latitude: Double
    public var longitude: Double

    public init(label: String, latitude: Double, longitude: Double) {
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
    }
}

public enum FoodDeliveryPolicy: String, Codable, CaseIterable, Sendable {
    /// Food apps work normally.
    case allow
    /// Food apps are shielded like everything else.
    case block
    /// Food apps show a "you sure?" shield; confirming opens them for the rest of the session.
    case cap

    public var title: String {
        switch self {
        case .allow: "Allow"
        case .block: "Block"
        case .cap: "Ask first"
        }
    }
}
