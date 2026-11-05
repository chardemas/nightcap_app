import Foundation

/// The Sobriety Challenge rules (SPEC §2.3). Views collect raw scores; this
/// decides pass/fail against the user's own sober baseline.
public enum ChallengeDifficulty: String, Codable, CaseIterable, Identifiable, Sendable {
    case relaxed, standard, strict

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .relaxed: "Relaxed"
        case .standard: "Standard"
        case .strict: "Strict"
        }
    }

    /// How much slower than baseline reaction time may be (0.25 = 25% slower).
    public var reactionSlowdown: Double {
        switch self {
        case .relaxed: 0.40
        case .standard: 0.25
        case .strict: 0.15
        }
    }

    /// How much slower than baseline typing speed may be.
    public var typingSlowdown: Double {
        switch self {
        case .relaxed: 0.60
        case .standard: 0.40
        case .strict: 0.25
        }
    }

    public var minimumAccuracy: Double {
        switch self {
        case .relaxed: 0.90
        case .standard: 0.95
        case .strict: 0.98
        }
    }

    /// "Repeat a 5–6 item sequence."
    public var memoryLength: Int {
        self == .strict ? 6 : 5
    }
}

public enum UnlockScope: String, Codable, CaseIterable, Identifiable, Sendable {
    case wholeSession, oneAppBriefly

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .wholeSession: "Rest of the night"
        case .oneAppBriefly: "Just that app, 10 min"
        }
    }
}

/// Raw results from one run of the three tests.
public struct ChallengeScores: Codable, Equatable, Sendable {
    public var reactionTimes: [TimeInterval]
    public var falseStarts: Int
    public var typingCharsPerSecond: Double
    public var typingAccuracy: Double
    /// More than a few characters arrived at once: pasted, not typed.
    public var typingPasted: Bool
    public var memoryPassed: Bool

    public init(reactionTimes: [TimeInterval], falseStarts: Int, typingCharsPerSecond: Double, typingAccuracy: Double, typingPasted: Bool, memoryPassed: Bool) {
        self.reactionTimes = reactionTimes
        self.falseStarts = falseStarts
        self.typingCharsPerSecond = typingCharsPerSecond
        self.typingAccuracy = typingAccuracy
        self.typingPasted = typingPasted
        self.memoryPassed = memoryPassed
    }

    public var reactionMedian: TimeInterval {
        let sorted = reactionTimes.sorted()
        guard !sorted.isEmpty else { return .infinity }
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}

public struct ChallengeBaseline: Codable, Equatable, Sendable {
    public var reactionMedian: TimeInterval
    public var typingCharsPerSecond: Double
    public var takenAt: Date

    public init(reactionMedian: TimeInterval, typingCharsPerSecond: Double, takenAt: Date) {
        self.reactionMedian = reactionMedian
        self.typingCharsPerSecond = typingCharsPerSecond
        self.takenAt = takenAt
    }
}

public enum ChallengeCheck: String, CaseIterable, Sendable {
    case reaction, typing, memory
}

public struct ChallengeVerdict: Equatable, Sendable {
    public let failed: Set<ChallengeCheck>
    public var passed: Bool { failed.isEmpty }
}

public enum ChallengeGate: Equatable, Sendable {
    case open
    case coolingDown(until: Date)
    case lockedForNight(until: Date)
}

public enum ChallengeRules {
    public static let reactionRounds = 5
    public static let allowedFalseStarts = 2
    public static let cooldown: TimeInterval = 15 * 60
    public static let maxFailures = 3
    public static let briefUnlockDuration: TimeInterval = 10 * 60

    // Absolute limits, so sandbagging the sober baseline can't make the
    // nighttime bar trivially easy.
    public static let reactionCeiling: TimeInterval = 0.5
    public static let typingFloorCharsPerSecond = 1.5

    public static func reactionLimit(baseline: ChallengeBaseline, difficulty: ChallengeDifficulty) -> TimeInterval {
        min(baseline.reactionMedian * (1 + difficulty.reactionSlowdown), reactionCeiling)
    }

    public static func minimumTypingSpeed(baseline: ChallengeBaseline, difficulty: ChallengeDifficulty) -> Double {
        max(baseline.typingCharsPerSecond / (1 + difficulty.typingSlowdown), typingFloorCharsPerSecond)
    }

    /// Seconds allowed to type `sentence`. Without a baseline (i.e. while
    /// taking it) only the absolute floor applies.
    public static func typingTimeLimit(for sentence: String, baseline: ChallengeBaseline?, difficulty: ChallengeDifficulty) -> TimeInterval {
        let speed = baseline.map { minimumTypingSpeed(baseline: $0, difficulty: difficulty) } ?? typingFloorCharsPerSecond
        return Double(sentence.count) / speed
    }

    public static func evaluate(_ scores: ChallengeScores, baseline: ChallengeBaseline, difficulty: ChallengeDifficulty) -> ChallengeVerdict {
        var failed = Set<ChallengeCheck>()
        if scores.reactionTimes.count < reactionRounds
            || scores.falseStarts > allowedFalseStarts
            || scores.reactionMedian > reactionLimit(baseline: baseline, difficulty: difficulty) {
            failed.insert(.reaction)
        }
        if scores.typingPasted
            || scores.typingAccuracy < difficulty.minimumAccuracy
            || scores.typingCharsPerSecond < minimumTypingSpeed(baseline: baseline, difficulty: difficulty) {
            failed.insert(.typing)
        }
        if !scores.memoryPassed { failed.insert(.memory) }
        return ChallengeVerdict(failed: failed)
    }

    /// A sober baseline has to clear the absolute limits, or night-time passing is impossible.
    public static func baselineProblems(_ scores: ChallengeScores) -> Set<ChallengeCheck> {
        var problems = Set<ChallengeCheck>()
        if scores.reactionTimes.count < reactionRounds || scores.reactionMedian > reactionCeiling { problems.insert(.reaction) }
        if scores.typingPasted || scores.typingAccuracy < 0.9 || scores.typingCharsPerSecond < typingFloorCharsPerSecond { problems.insert(.typing) }
        if !scores.memoryPassed { problems.insert(.memory) }
        return problems
    }

    public static func gate(for session: Session, now: Date) -> ChallengeGate {
        if session.challengeFailures.count >= maxFailures { return .lockedForNight(until: session.plannedEnd) }
        if let last = session.challengeFailures.last, now < last.addingTimeInterval(cooldown) {
            return .coolingDown(until: last.addingTimeInterval(cooldown))
        }
        return .open
    }

    /// Typed-vs-target similarity in 0...1 (1 = exact), ignoring case and outer whitespace.
    public static func accuracy(typed: String, target: String) -> Double {
        let a = Array(typed.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
        let b = Array(target.lowercased())
        guard !b.isEmpty else { return a.isEmpty ? 1 : 0 }
        return max(0, 1 - Double(levenshtein(a, b)) / Double(max(a.count, b.count)))
    }

    public static func memorySequence<G: RandomNumberGenerator>(length: Int, pads: Int = 4, using generator: inout G) -> [Int] {
        (0..<length).map { _ in Int.random(in: 0..<pads, using: &generator) }
    }

    public static func memorySequence(length: Int, pads: Int = 4) -> [Int] {
        var generator = SystemRandomNumberGenerator()
        return memorySequence(length: length, pads: pads, using: &generator)
    }

    private static func levenshtein(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        var previous = Array(0...b.count)
        for (i, ca) in a.enumerated() {
            var current = [i + 1]
            for (j, cb) in b.enumerated() {
                current.append(min(previous[j + 1] + 1, current[j] + 1, previous[j] + (ca == cb ? 0 : 1)))
            }
            previous = current
        }
        return previous[b.count]
    }

    /// Sentences for the typing test: ordinary words, no tricky punctuation.
    public static let sentences = [
        "the quick brown fox orders a glass of water",
        "morning me will be very grateful for this",
        "i would like one taxi to my own front door",
        "seven sleepy owls sat on the garden fence",
        "please remember where i parked the bicycle",
        "a calm night is better than a loud morning",
        "the bartender knows my name and that is fine",
        "my keys are in my left pocket where they belong",
        "twelve purple grapes rolled across the table",
        "tomorrow i will thank myself for going home",
        "the moon is out and so is my good judgment",
        "one more song and then i am calling a ride",
        "every penguin wears a tuxedo to the party",
        "i promise to drink a glass of water first",
        "the kitchen light is on and the kettle is warm",
        "a gentle breeze carried the scent of fresh bread",
    ]
}
