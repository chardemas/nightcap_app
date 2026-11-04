import Foundation

public struct Session: Codable, Identifiable, Equatable, Sendable {
    public enum Trigger: String, Codable, Sendable {
        case manual, schedule, location
    }

    public var id: UUID
    public var start: Date
    public var plannedEnd: Date
    public var actualEnd: Date?
    public var trigger: Trigger
    public var unlockedEarly: Bool
    public var challengeAttempts: Int

    public init(id: UUID = UUID(), start: Date, plannedEnd: Date, trigger: Trigger) {
        self.id = id
        self.start = start
        self.plannedEnd = plannedEnd
        self.trigger = trigger
        actualEnd = nil
        unlockedEarly = false
        challengeAttempts = 0
    }

    public func isActive(at date: Date) -> Bool {
        actualEnd == nil && date >= start && date < plannedEnd
    }
}

extension Session {
    /// DeviceActivity won't schedule an interval shorter than 15 minutes.
    public static let minimumDuration: TimeInterval = 15 * 60
    /// A night out, not a lifestyle.
    public static let maximumDuration: TimeInterval = 24 * 60 * 60

    /// "Default: 6:00 AM next morning" — the next 6:00 AM strictly after `now`.
    public static func defaultEnd(after now: Date, calendar: Calendar = .current) -> Date {
        let sixAM = DateComponents(hour: 6, minute: 0, second: 0)
        return calendar.nextDate(after: now, matching: sixAM, matchingPolicy: .nextTime) ?? now.addingTimeInterval(8 * 60 * 60)
    }

    /// Clamps a user-picked end time into the range DeviceActivity (and sanity) allow.
    public static func clampedEnd(_ requested: Date, now: Date) -> Date {
        min(max(requested, now.addingTimeInterval(minimumDuration)), now.addingTimeInterval(maximumDuration))
    }
}

/// One tap on a shielded app/site, logged by the ShieldAction extension for the recap.
public struct BlockedAttempt: Codable, Identifiable, Equatable, Sendable {
    public enum Target: String, Codable, Sendable { case application, webDomain, category }
    public enum Choice: String, Codable, Sendable { case wantsChallenge, gaveUp, overrodeFoodCap }

    public var id: UUID
    public var timestamp: Date
    public var sessionID: UUID?
    public var target: Target
    /// The opaque, JSON-encoded Screen Time token. Never a name, URL, or content.
    public var tokenData: Data?
    public var choice: Choice

    public init(timestamp: Date, sessionID: UUID?, target: Target, tokenData: Data?, choice: Choice) {
        id = UUID()
        self.timestamp = timestamp
        self.sessionID = sessionID
        self.target = target
        self.tokenData = tokenData
        self.choice = choice
    }
}

/// Session bookkeeping on top of the App Group files. Usable from any target.
public enum SessionLedger {
    public static func current(at date: Date = .now) -> Session? {
        guard let session = NightcapFiles.currentSession.load(), session.isActive(at: date) else { return nil }
        return session
    }

    @discardableResult
    public static func begin(trigger: Session.Trigger, plannedEnd: Date, now: Date = .now) throws -> Session {
        let session = Session(start: now, plannedEnd: Session.clampedEnd(plannedEnd, now: now), trigger: trigger)
        try NightcapFiles.currentSession.save(session)
        return session
    }

    /// Moves the current session into history. Safe to call twice (app and monitor
    /// extension can both notice the end); the second call is a no-op.
    public static func finish(at date: Date = .now, unlockedEarly: Bool = false) {
        guard var session = NightcapFiles.currentSession.load() else { return }
        session.actualEnd = min(date, session.plannedEnd)
        session.unlockedEarly = unlockedEarly
        try? NightcapFiles.sessionHistory.update(default: []) { $0.append(session) }
        NightcapFiles.currentSession.delete()
    }

    /// If a session's planned end passed while nothing was running to notice,
    /// close it out. Returns true if it did.
    @discardableResult
    public static func finishIfExpired(now: Date = .now) -> Bool {
        guard let session = NightcapFiles.currentSession.load(), session.actualEnd == nil, now >= session.plannedEnd else { return false }
        finish(at: session.plannedEnd)
        return true
    }

    public static func logAttempt(target: BlockedAttempt.Target, tokenData: Data?, choice: BlockedAttempt.Choice, at date: Date = .now) {
        let attempt = BlockedAttempt(timestamp: date, sessionID: current(at: date)?.id, target: target, tokenData: tokenData, choice: choice)
        try? NightcapFiles.attempts.update(default: []) { $0.append(attempt) }
    }
}
