import FamilyControls
import ManagedSettings
import NightcapCore

/// The user's FamilyActivityPicker choices. Lives beside NightcapSettings in the
/// App Group so the monitor and shield extensions can read it.
struct BlockSelections: Codable, Equatable {
    /// Apps, categories, and sites to shield during a session.
    var blocked = FamilyActivitySelection()
    /// Always allowed, even inside a blocked category: Uber, Lyft, Maps, transit, Nightcap.
    var allowed = FamilyActivitySelection()
    /// Food delivery apps, handled by `NightcapSettings.foodDelivery`.
    var foodDelivery = FamilyActivitySelection()

    static var file: JSONFile<BlockSelections> { JSONFile("selections.json") }

    static func load() -> BlockSelections { file.load() ?? BlockSelections() }

    var hasAnythingBlocked: Bool {
        !blocked.applicationTokens.isEmpty || !blocked.categoryTokens.isEmpty || !blocked.webDomainTokens.isEmpty
    }

    func isFoodApp(_ token: ApplicationToken) -> Bool {
        foodDelivery.applicationTokens.contains(token)
    }
}

extension FamilyActivitySelection {
    var itemCount: Int { applicationTokens.count + categoryTokens.count + webDomainTokens.count }
}
