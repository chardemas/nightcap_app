import DeviceActivity
import NightcapCore

/// Runs in its own process when a DeviceActivity interval starts or ends, even
/// if Nightcap itself isn't running. Phase 1 only schedules `.manualSession`;
/// Phase 3 adds recurring schedules here.
final class NightcapMonitor: DeviceActivityMonitor {
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // The app already applied shields when the user tapped Start; this
        // re-applies in case that process was killed mid-start.
        guard activity == .manualSession, SessionLedger.current() != nil else { return }
        ShieldController.apply()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == .manualSession else { return }
        ShieldController.clear()
        SessionLedger.finish()
    }
}
