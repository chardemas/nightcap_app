import DeviceActivity
import Foundation

extension DeviceActivityName {
    /// The end-time timer for a manual session. Its intervalDidEnd in
    /// NightcapMonitor clears shields even if the app never runs again.
    static let manualSession = Self("nightcap.manual")
}

enum SessionScheduler {
    static func scheduleManualSession(from start: Date, to end: Date, calendar: Calendar = .current) throws {
        let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(fields, from: start),
            intervalEnd: calendar.dateComponents(fields, from: end),
            repeats: false
        )
        let center = DeviceActivityCenter()
        center.stopMonitoring([.manualSession])
        try center.startMonitoring(.manualSession, during: schedule)
    }

    static func cancelManualSession() {
        DeviceActivityCenter().stopMonitoring([.manualSession])
    }
}
