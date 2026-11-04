import CoreLocation
import FamilyControls
import NightcapCore
import Observation
import UIKit
import UserNotifications

@MainActor
@Observable
final class AppModel {
    enum Route: Identifiable {
        case challenge
        var id: Self { self }
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
        rideAppInstalled = UIApplication.shared.canOpenURL(settings.rideApp.probeURL)
    }

    // MARK: - Checklist

    var checklist: ChecklistReport {
        ChecklistReport(ChecklistContext(
            screenTimeAuthorized: authorizationStatus == .approved,
            hasBlockSelection: selections.hasAnythingBlocked,
            homeSaved: settings.home != nil,
            rideAppInstalled: rideAppInstalled,
            baselineTaken: settings.baselineTaken,
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

    /// Phase 1: ends immediately. Phase 2 puts the sobriety challenge in front of this.
    func stopSession() {
        SessionScheduler.cancelManualSession()
        ShieldController.clear()
        SessionLedger.finish(unlockedEarly: true)
        session = nil
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
        if url.host() == "challenge" { route = .challenge }
    }
}
