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
        switch activity {
        case .manualSession:
            ShieldController.clear()
            SessionLedger.finish()
        case .briefUnlock:
            // The "just that app" unlock is over: put its shield back.
            guard SessionLedger.current() != nil else { return }
            SessionLedger.update { $0.temporaryUnlock = nil }
            ShieldController.apply()
        default:
            break
        }
    }
}
