import DeviceActivity
import Foundation

extension DeviceActivityName {
    /// The end-time timer for a manual session. Its intervalDidEnd in
    /// NightcapMonitor clears shields even if the app never runs again.
    static let manualSession = Self("nightcap.manual")
    /// Ends when a "just that app" unlock expires; NightcapMonitor re-shields.
    static let briefUnlock = Self("nightcap.unlock")
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
        DeviceActivityCenter().stopMonitoring([.manualSession, .briefUnlock])
    }

    /// Schedules the re-shield for a brief unlock and returns when it will
    /// actually happen. DeviceActivity intervals must be at least 15 minutes,
    /// so the interval is backdated to end on time; if iOS rejects a start in
    /// the past, it falls back to a 15-minute unlock.
    static func scheduleReshield(at end: Date, now: Date = .now, calendar: Calendar = .current) -> Date {
        let center = DeviceActivityCenter()
        center.stopMonitoring([.briefUnlock])
        let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        func schedule(_ start: Date, _ end: Date) -> DeviceActivitySchedule {
            DeviceActivitySchedule(
                intervalStart: calendar.dateComponents(fields, from: start),
                intervalEnd: calendar.dateComponents(fields, from: end),
                repeats: false
            )
        }
        let minimum: TimeInterval = 15 * 60
        if (try? center.startMonitoring(.briefUnlock, during: schedule(end.addingTimeInterval(-minimum), end))) != nil {
            return end
        }
        let fallbackEnd = now.addingTimeInterval(minimum)
        try? center.startMonitoring(.briefUnlock, during: schedule(now, fallbackEnd))
        return fallbackEnd
    }
}
