import Foundation
import ManagedSettings
import NightcapCore

extension ManagedSettingsStore.Name {
    /// Everything a session restricts. Cleared in one call at session end.
    static let nightcap = Self("nightcap")
    /// Food delivery apps under the "Ask first" policy. Kept separate so the
    /// shield's "I'm sure" button can lift just these.
    static let nightcapFood = Self("nightcap.food")
}

/// The one place that turns settings + selections into ManagedSettings.
/// Called by the app (manual start/stop), the monitor extension (scheduled
/// start/end), and the shield action extension (food cap override).
enum ShieldController {
    static func apply(settings: NightcapSettings = NightcapFiles.settings.load() ?? NightcapSettings(),
                      selections: BlockSelections = .load()) {
        let store = ManagedSettingsStore(named: .nightcap)
        let allowedApps = selections.allowed.applicationTokens
        let allowedSites = selections.allowed.webDomainTokens

        var apps = selections.blocked.applicationTokens
        if settings.foodDelivery == .block { apps.formUnion(selections.foodDelivery.applicationTokens) }
        apps.subtract(allowedApps)
        store.shield.applications = apps.isEmpty ? nil : apps

        // A category shield skips anything on the allowlist, which is how ride
        // apps stay open inside e.g. "Travel" or "Navigation".
        let categories = selections.blocked.categoryTokens
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories, except: allowedApps)
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories, except: allowedSites)

        let sites = selections.blocked.webDomainTokens.subtracting(allowedSites)
        store.shield.webDomains = sites.isEmpty ? nil : sites

        store.webContent.blockedByFilter = webFilter(for: settings)
        store.appStore.denyInAppPurchases = settings.denyInAppPurchases ? true : nil
        // Deleting Nightcap mid-session would lift every shield.
        store.application.denyAppRemoval = settings.denyAppRemoval ? true : nil

        let foodStore = ManagedSettingsStore(named: .nightcapFood)
        let foodApps = selections.foodDelivery.applicationTokens.subtracting(allowedApps)
        foodStore.shield.applications = settings.foodDelivery == .cap && !foodApps.isEmpty ? foodApps : nil
    }

    static func clear() {
        ManagedSettingsStore(named: .nightcap).clearAllSettings()
        ManagedSettingsStore(named: .nightcapFood).clearAllSettings()
    }

    /// "Yes, I'm sure" on the food delivery shield: open food apps for the rest of the session.
    static func liftFoodCap() {
        ManagedSettingsStore(named: .nightcapFood).clearAllSettings()
    }

    private static func webFilter(for settings: NightcapSettings) -> WebContentSettings.FilterPolicy? {
        if settings.strictMode {
            return .all(except: Set(WebDomainPack.strictModeExceptions.map { WebDomain(domain: $0) }))
        }
        var packs = settings.webPacks
        if settings.foodDelivery == .block { packs.insert(.foodDelivery) } else { packs.remove(.foodDelivery) }
        let domains = WebDomainPack.domains(for: packs)
        return domains.isEmpty ? nil : .specific(Set(domains.map { WebDomain(domain: $0) }))
    }
}
