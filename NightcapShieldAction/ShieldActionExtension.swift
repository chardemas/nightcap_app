import Foundation
import ManagedSettings
import NightcapCore
import UserNotifications

/// Handles taps on the shield's two buttons and logs each attempt for the
/// morning recap. Shield extensions can't open the app directly, so the
/// "prove it" button posts a notification that deep-links into the challenge.
final class ShieldActionExtension: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        let settings = NightcapFiles.settings.load() ?? NightcapSettings()
        let isFoodCap = settings.foodDelivery == .cap && BlockSelections.load().isFoodApp(application)

        if isFoodCap {
            // Food shield: primary = "Nah, I'm good", secondary = "Yes, I'm sure".
            if action == .secondaryButtonPressed {
                log(.application, application, .overrodeFoodCap)
                ShieldController.liftFoodCap()
                completionHandler(.defer)
            } else {
                log(.application, application, .gaveUp)
                completionHandler(.close)
            }
            return
        }
        respond(to: action, target: .application, token: application, completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, target: .webDomain, token: webDomain, completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(to: action, target: .category, token: category, completionHandler)
    }

    // MARK: -

    private func respond<Token: Encodable>(to action: ShieldAction, target: BlockedAttempt.Target, token: Token, _ completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            log(target, token, .wantsChallenge)
            postChallengeNotification { completionHandler(.close) }
        case .secondaryButtonPressed:
            log(target, token, .gaveUp)
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    private func log<Token: Encodable>(_ target: BlockedAttempt.Target, _ token: Token, _ choice: BlockedAttempt.Choice) {
        SessionLedger.logAttempt(target: target, tokenData: try? JSONEncoder().encode(token), choice: choice)
    }

    private func postChallengeNotification(then done: @escaping () -> Void) {
        let content = UNMutableNotificationContent()
        content.title = "Think you're sober?"
        content.body = "Tap to take the challenge. No pressure. (Some pressure.)"
        content.userInfo = ["deeplink": "nightcap://challenge"]
        let request = UNNotificationRequest(identifier: "nightcap.challenge", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in done() }
    }
}
