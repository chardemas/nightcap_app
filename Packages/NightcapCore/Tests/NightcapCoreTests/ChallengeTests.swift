import XCTest
@testable import NightcapCore

final class ChallengeTests: XCTestCase {
    private let baseline = ChallengeBaseline(reactionMedian: 0.28, typingCharsPerSecond: 4.0, takenAt: .distantPast)

    private func scores(reaction: TimeInterval = 0.28, falseStarts: Int = 0, cps: Double = 4.0, accuracy: Double = 1, pasted: Bool = false, memory: Bool = true) -> ChallengeScores {
        ChallengeScores(
            reactionTimes: Array(repeating: reaction, count: ChallengeRules.reactionRounds),
            falseStarts: falseStarts,
            typingCharsPerSecond: cps,
            typingAccuracy: accuracy,
            typingPasted: pasted,
            memoryPassed: memory
        )
    }

    func testSoberScoresPass() {
        XCTAssertTrue(ChallengeRules.evaluate(scores(), baseline: baseline, difficulty: .standard).passed)
    }

    func testReactionMayBe25PercentSlowerOnStandard() {
        XCTAssertTrue(ChallengeRules.evaluate(scores(reaction: 0.34), baseline: baseline, difficulty: .standard).passed)
        XCTAssertEqual(ChallengeRules.evaluate(scores(reaction: 0.36), baseline: baseline, difficulty: .standard).failed, [.reaction])
    }

    func testSandbaggedBaselineStillHitsAbsoluteLimits() {
        let lazy = ChallengeBaseline(reactionMedian: 0.9, typingCharsPerSecond: 0.5, takenAt: .distantPast)
        XCTAssertEqual(ChallengeRules.reactionLimit(baseline: lazy, difficulty: .relaxed), ChallengeRules.reactionCeiling)
        XCTAssertEqual(ChallengeRules.minimumTypingSpeed(baseline: lazy, difficulty: .relaxed), ChallengeRules.typingFloorCharsPerSecond)
    }

    func testEveryFailureIsReported() {
        let verdict = ChallengeRules.evaluate(scores(falseStarts: 3, accuracy: 0.8, memory: false), baseline: baseline, difficulty: .standard)
        XCTAssertEqual(verdict.failed, [.reaction, .typing, .memory])
    }

    func testPastingFailsTyping() {
        XCTAssertEqual(ChallengeRules.evaluate(scores(pasted: true), baseline: baseline, difficulty: .relaxed).failed, [.typing])
    }

    func testMissingReactionRoundsFail() {
        var partial = scores()
        partial.reactionTimes.removeLast()
        XCTAssertEqual(ChallengeRules.evaluate(partial, baseline: baseline, difficulty: .relaxed).failed, [.reaction])
    }

    func testBaselineMustClearAbsoluteLimits() {
        XCTAssertEqual(ChallengeRules.baselineProblems(scores()), [])
        XCTAssertEqual(ChallengeRules.baselineProblems(scores(reaction: 0.7, cps: 1.0)), [.reaction, .typing])
    }

    func testTypingAccuracy() {
        XCTAssertEqual(ChallengeRules.accuracy(typed: "  Hello World ", target: "hello world"), 1)
        XCTAssertEqual(ChallengeRules.accuracy(typed: "hello wrld", target: "hello world"), 1 - 1.0 / 11, accuracy: 0.0001)
        XCTAssertEqual(ChallengeRules.accuracy(typed: "", target: "hello"), 0)
    }

    func testTypingTimeLimitScalesWithSentence() {
        let sentence = String(repeating: "a", count: 40)
        XCTAssertEqual(ChallengeRules.typingTimeLimit(for: sentence, baseline: nil, difficulty: .standard), 40 / 1.5, accuracy: 0.001)
        XCTAssertEqual(ChallengeRules.typingTimeLimit(for: sentence, baseline: baseline, difficulty: .standard), 40 / (4.0 / 1.4), accuracy: 0.001)
    }

    func testMemorySequence() {
        let sequence = ChallengeRules.memorySequence(length: 6)
        XCTAssertEqual(sequence.count, 6)
        XCTAssertTrue(sequence.allSatisfy { (0..<4).contains($0) })
    }

    func testCooldownThenLockAfterThreeFailures() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var session = Session(start: start, plannedEnd: start.addingTimeInterval(6 * 3600), trigger: .manual)
        XCTAssertEqual(ChallengeRules.gate(for: session, now: start), .open)

        let fail1 = start.addingTimeInterval(600)
        session.challengeFailures = [fail1]
        XCTAssertEqual(ChallengeRules.gate(for: session, now: fail1.addingTimeInterval(60)), .coolingDown(until: fail1.addingTimeInterval(ChallengeRules.cooldown)))
        XCTAssertEqual(ChallengeRules.gate(for: session, now: fail1.addingTimeInterval(ChallengeRules.cooldown)), .open)

        session.challengeFailures += [fail1.addingTimeInterval(1000), fail1.addingTimeInterval(2000)]
        XCTAssertEqual(ChallengeRules.gate(for: session, now: fail1.addingTimeInterval(9000)), .lockedForNight(until: session.plannedEnd))
    }

    func testSentencesAreTypeable() {
        for sentence in ChallengeRules.sentences {
            XCTAssertEqual(sentence, sentence.lowercased())
            XCTAssertTrue((35...55).contains(sentence.count), sentence)
        }
    }
}
