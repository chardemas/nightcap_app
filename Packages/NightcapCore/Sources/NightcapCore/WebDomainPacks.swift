import Foundation

/// The "web loophole closer" (SPEC §2.2).
///
/// Screen Time tokens are opaque, so Nightcap can't look up a blocked app's
/// website. Two layers cover it instead:
///  1. Blocked *categories* are also applied to `shield.webDomainCategories`
///     (category tokens cover both apps and sites).
///  2. These curated packs go into `webContent.blockedByFilter`, which takes
///     plain domain strings.
///
/// Apple documents a 50-domain cap on the filter; developers report 49 in
/// practice, so `domains(for:)` stops at 49. Order inside each pack is priority.
public enum WebDomainPack: String, Codable, CaseIterable, Identifiable, Sendable {
    case social, shopping, dating, money, gambling, work, foodDelivery

    public static let defaultOn: Set<WebDomainPack> = [.social, .shopping, .dating, .money, .gambling]
    public static let filterLimit = 49

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .social: "Social media"
        case .shopping: "Shopping"
        case .dating: "Dating"
        case .money: "Money apps"
        case .gambling: "Betting & trading"
        case .work: "Work"
        case .foodDelivery: "Food delivery"
        }
    }

    public var domains: [String] {
        switch self {
        case .social: ["instagram.com", "x.com", "twitter.com", "tiktok.com", "facebook.com", "snapchat.com", "threads.net", "reddit.com", "linkedin.com"]
        case .shopping: ["amazon.com", "ebay.com", "etsy.com", "shein.com", "temu.com", "walmart.com", "target.com", "aliexpress.com"]
        case .dating: ["tinder.com", "bumble.com", "hinge.co", "grindr.com", "okcupid.com", "match.com", "raya.app"]
        case .money: ["venmo.com", "cash.app", "paypal.com", "zellepay.com"]
        case .gambling: ["draftkings.com", "fanduel.com", "betmgm.com", "caesars.com", "robinhood.com", "coinbase.com", "kalshi.com", "polymarket.com"]
        case .work: ["slack.com", "mail.google.com", "outlook.office.com", "outlook.live.com", "teams.microsoft.com"]
        case .foodDelivery: ["doordash.com", "ubereats.com", "grubhub.com", "postmates.com", "seamless.com", "instacart.com", "gopuff.com"]
        }
    }

    /// Domains to filter for the chosen packs, deduplicated and capped at `filterLimit`.
    public static func domains(for packs: Set<WebDomainPack>) -> [String] {
        var seen = Set<String>()
        let ordered = allCases.filter(packs.contains).flatMap(\.domains).filter { seen.insert($0).inserted }
        return Array(ordered.prefix(filterLimit))
    }

    /// Sites that stay reachable even in Strict mode, when every other website is blocked.
    public static let strictModeExceptions = ["uber.com", "m.uber.com", "lyft.com", "ride.lyft.com", "maps.apple.com", "maps.google.com"]
}
