import ManagedSettings
import ManagedSettingsUI
import NightcapCore
import UIKit

/// What a shielded app or site looks like. Shields can't host custom UI
/// (SPEC §5.4): just an icon, two labels, and two buttons.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        if let token = application.token, isFoodCapped(token) {
            return foodCap(appName: application.localizedDisplayName)
        }
        return nightcap(subtitle: line(for: application.localizedDisplayName))
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: application)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        nightcap(subtitle: "\(webDomain.domain ?? "This site") can wait for daylight.")
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        configuration(shielding: webDomain)
    }

    // MARK: -

    private func nightcap(subtitle: String) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: Brand.midnight,
            icon: UIImage(systemName: "moon.stars.fill")?.withTintColor(Brand.amber, renderingMode: .alwaysOriginal),
            title: .init(text: "Nightcap's got you 🌙", color: Brand.moonlight),
            subtitle: .init(text: subtitle, color: Brand.dusk),
            primaryButtonLabel: .init(text: "I'm sober — let me prove it.", color: Brand.midnight),
            primaryButtonBackgroundColor: Brand.amber,
            secondaryButtonLabel: .init(text: "Fair. Never mind.", color: Brand.dusk)
        )
    }

    private func foodCap(appName: String?) -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: Brand.midnight,
            icon: UIImage(systemName: "takeoutbag.and.cup.and.straw.fill")?.withTintColor(Brand.amber, renderingMode: .alwaysOriginal),
            title: .init(text: "Late-night snack?", color: Brand.moonlight),
            subtitle: .init(text: "\(appName ?? "Delivery") at this hour hits different tomorrow. Still want it?", color: Brand.dusk),
            primaryButtonLabel: .init(text: "Nah, I'm good", color: Brand.midnight),
            primaryButtonBackgroundColor: Brand.amber,
            secondaryButtonLabel: .init(text: "Yes, I'm sure", color: Brand.dusk)
        )
    }

    private func line(for appName: String?) -> String {
        let name = appName ?? "That app"
        return [
            "\(name) will still be there in the morning. So will you.",
            "Morning You asked us to hold onto \(name) for a bit.",
            "\(name) is closed for the night. House rules.",
            "Bold of you to try \(name) right now.",
        ].randomElement()!
    }

    private func isFoodCapped(_ token: ApplicationToken) -> Bool {
        let settings = NightcapFiles.settings.load() ?? NightcapSettings()
        return settings.foodDelivery == .cap && BlockSelections.load().isFoodApp(token)
    }
}
