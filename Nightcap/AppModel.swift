import CoreLocation
import FamilyControls
import NightcapCore
import Observation
import UIKit
import UserNotifications

@MainActor
@Observable
final class AppModel {
    enum Route: Hashable, Identifiable {
        case challenge(ChallengeOrigin)
        var id: Self { self }
    }

    enum ChallengeOrigin: Hashable {
        /// "I'm sober — let me prove it" on a shield.
        case shield
        /// "End early" on the home screen.
        case endEarly
        /// Sober calibration, from the checklist or Settings.
        case baseline
    }

    enum ChallengeOutcome {
        case unlockedSession
        case unlockedBriefly(until: Date)
        case failed(ChallengeVerdict, ChallengeGate)
    }

    enum StartError: LocalizedError {
        case checklistIncomplete
        case schedulingFailed(Error)

        var errorDescription: String? {
            switch self {
            case .checklistIncomplete: "A few things on the Pre-Game Checklist still need doing."
            case .schedulingFailed(let error): "Couldn't set the end-time timer: \(error.localizedDescription)"
            }
        }
    }

    var settings: NightcapSettings {
        didSet { try? NightcapFiles.settings.save(settings) }
    }

    var selections: BlockSelections {
        didSet { try? BlockSelections.file.save(selections) }
    }

    private(set) var session: Session?
    private(set) var authorizationStatus: AuthorizationStatus = .notDetermined
    private(set) var rideAppInstalled = false
    var route: Route?

    init() {
        settings = NightcapFiles.settings.load() ?? NightcapSettings()
        selections = BlockSelections.load()
        refresh()
    }

    /// Re-read everything that can change behind our back: the monitor
    /// extension ending a session, Screen Time permission, ride app installs.
    func refresh() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        SessionLedger.finishIfExpired()
        session = SessionLedger.current()
        // Belt and braces: no active session means no shields, whatever happened while we were gone.
        if session == nil { ShieldController.clear() }
        // Backup for the monitor extension: put back a shield whose brief unlock ran out.
        if let unlock = session?.temporaryUnlock, unlock.until <= .now {
            SessionLedger.update { $0.temporaryUnlock = nil }
            session = SessionLedger.current()
            ShieldController.apply(settings: settings, selections: selections)
        }
        rideAppInstalled = UIApplication.shared.canOpenURL(settings.rideApp.probeURL)
    }

    // MARK: - Checklist

    var checklist: ChecklistReport {
        ChecklistReport(ChecklistContext(
            screenTimeAuthorized: authorizationStatus == .approved,
            hasBlockSelection: selections.hasAnythingBlocked,
            homeSaved: settings.home != nil,
            rideAppInstalled: rideAppInstalled,
            baselineTaken: settings.baseline != nil,
            exListCount: settings.exListContactIDs.count,
            contactDisguiseEnabled: settings.contactDisguiseEnabled,
            confirmations: settings.selfConfirmations
        ))
    }

    func confirm(_ items: [ChecklistItem]) {
        let now = Date.now
        for item in items { settings.selfConfirmations[item] = now }
    }

    // MARK: - Session

    var isLocked: Bool { session != nil }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            // The user said no, or Screen Time is restricted. Status below says which.
        }
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    func startSession(until end: Date) async throws {
        guard checklist.blockers.isEmpty else { throw StartError.checklistIncomplete }
        // The shield's "prove it" button reaches the app through a notification.
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])

        let started = try SessionLedger.begin(trigger: .manual, plannedEnd: end)
        do {
            try SessionScheduler.scheduleManualSession(from: started.start, to: started.plannedEnd)
        } catch {
            // Without the timer nothing would lift the shields if the app is killed. Don't start.
            NightcapFiles.currentSession.delete()
            throw StartError.schedulingFailed(error)
        }
        ShieldController.apply(settings: settings, selections: selections)
        session = started
    }

    private func endSessionEarly() {
        SessionScheduler.cancelManualSession()
        ShieldController.clear()
        SessionLedger.finish(unlockedEarly: true)
        session = nil
    }

    // MARK: - Sobriety Challenge

    /// nil when there's no session to unlock.
    var challengeGate: ChallengeGate? {
        session.map { ChallengeRules.gate(for: $0, now: .now) }
    }

    func finishChallenge(_ scores: ChallengeScores, origin: ChallengeOrigin) -> ChallengeOutcome? {
        guard let baseline = settings.baseline, session != nil else { return nil }
        let verdict = ChallengeRules.evaluate(scores, baseline: baseline, difficulty: settings.challengeDifficulty)
        SessionLedger.recordChallenge(verdict)
        session = SessionLedger.current()

        guard verdict.passed else {
            let gate = challengeGate ?? .open
            if case .coolingDown(let until) = gate { notifyCooldownOver(at: until) }
            return .failed(verdict, gate)
        }

        // "Just that app" only makes sense when the user came from a shield.
        if origin == .shield, settings.unlockScope == .oneAppBriefly, let pending = takePendingUnlock() {
            let until = SessionScheduler.scheduleReshield(at: .now.addingTimeInterval(ChallengeRules.briefUnlockDuration))
            SessionLedger.update { $0.temporaryUnlock = TemporaryUnlock(target: pending.target, tokenData: pending.tokenData, until: until) }
            session = SessionLedger.current()
            ShieldController.apply(settings: settings, selections: selections)
            return .unlockedBriefly(until: until)
        }
        endSessionEarly()
        return .unlockedSession
    }

    /// Saves the sober baseline unless it misses the absolute limits; returns what to redo.
    func saveBaseline(_ scores: ChallengeScores) -> Set<ChallengeCheck> {
        let problems = ChallengeRules.baselineProblems(scores)
        if problems.isEmpty {
            settings.baseline = ChallengeBaseline(
                reactionMedian: scores.reactionMedian,
                typingCharsPerSecond: scores.typingCharsPerSecond,
                takenAt: .now
            )
        }
        return problems
    }

    /// The shield the user tapped "prove it" on, if it was recent enough to be this attempt's.
    private func takePendingUnlock() -> PendingUnlock? {
        defer { NightcapFiles.pendingUnlock.delete() }
        guard let pending = NightcapFiles.pendingUnlock.load(),
              Date.now.timeIntervalSince(pending.requestedAt) < 30 * 60 else { return nil }
        return pending
    }

    private func notifyCooldownOver(at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Cooldown's over"
        content.body = "You can try the challenge again. Or, hear us out: water."
        content.userInfo = ["deeplink": "nightcap://challenge"]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "nightcap.cooldown", content: content, trigger: trigger))
    }

    // MARK: - Ride home

    func setRideApp(_ app: RideApp) {
        settings.rideApp = app
        rideAppInstalled = UIApplication.shared.canOpenURL(app.probeURL)
    }

    func saveHome(address: String) async throws {
        let placemarks = try await CLGeocoder().geocodeAddressString(address)
        guard let location = placemarks.first?.location else {
            throw CLError(.geocodeFoundNoResult)
        }
        settings.home = HomeAddress(
            label: address,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    func rideHome() {
        let app = settings.rideApp
        if rideAppInstalled, let home = settings.home, let url = app.rideHomeURL(to: home) {
            UIApplication.shared.open(url)
        } else if rideAppInstalled {
            UIApplication.shared.open(app.probeURL)
        } else {
            UIApplication.shared.open(app.appStoreURL)
        }
    }

    // MARK: - Deep links

    func handle(url: URL) {
        guard url.scheme == "nightcap" else { return }
        if url.host() == "challenge" { route = .challenge(.shield) }
    }
}
