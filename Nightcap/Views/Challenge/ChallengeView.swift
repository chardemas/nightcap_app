import NightcapCore
import SwiftUI

/// Runs reaction → typing → memory, then grades the whole thing. Used both to
/// unlock a session (graded against the baseline) and to record the baseline.
struct ChallengeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let origin: AppModel.ChallengeOrigin

    private enum Step { case intro, reaction, typing, memory, result }

    private enum Result {
        case baselineSaved
        case baselineRetry(Set<ChallengeCheck>)
        case outcome(AppModel.ChallengeOutcome)
    }

    @State private var step = Step.intro
    @State private var reactionTimes: [TimeInterval] = []
    @State private var falseStarts = 0
    @State private var typing: TypingOutcome?
    @State private var result: Result?
    @State private var sentence = ChallengeRules.sentences.randomElement()!

    private var isBaseline: Bool { origin == .baseline }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            content
        }
        .preferredColorScheme(.dark)
        // No swiping away mid-test.
        .interactiveDismissDisabled(step != .intro && step != .result)
    }

    @ViewBuilder
    private var content: some View {
        if let blocker {
            MessageView(symbol: blocker.symbol, title: blocker.title, message: blocker.message, button: "Okay") { dismiss() }
        } else {
            switch step {
            case .intro: intro
            case .reaction:
                ReactionTestView(rounds: ChallengeRules.reactionRounds) { times, falseStarts in
                    reactionTimes = times
                    self.falseStarts = falseStarts
                    step = .typing
                }
            case .typing:
                TypingTestView(sentence: sentence, timeLimit: typingLimit) { outcome in
                    typing = outcome
                    step = .memory
                }
            case .memory:
                MemoryTestView(length: model.settings.challengeDifficulty.memoryLength) { passed in
                    grade(memoryPassed: passed)
                }
            case .result:
                resultView
            }
        }
    }

    // MARK: - Before the test

    private struct Blocker {
        let symbol: String
        let title: String
        let message: String
    }

    /// Reasons not to run the challenge at all.
    private var blocker: Blocker? {
        guard step == .intro else { return nil }
        if isBaseline {
            guard model.session == nil else {
                return Blocker(symbol: "hand.raised.fill", title: "Nice try", message: "Your sober baseline can only be taken when Nightcap is off.")
            }
            return nil
        }
        guard let session = model.session else {
            return Blocker(symbol: "sun.max.fill", title: "Nightcap's off", message: "Nothing to unlock. You're free.")
        }
        if model.settings.baseline == nil {
            return Blocker(symbol: "questionmark.circle", title: "No baseline yet", message: "The challenge needs your sober scores to compare against. Nightcap holds until \(time(session.plannedEnd)).")
        }
        switch model.challengeGate {
        case .coolingDown(let until):
            return Blocker(symbol: "hourglass", title: "Cooling down", message: "Next try at \(time(until)). Maybe a glass of water in the meantime?")
        case .lockedForNight(let until):
            return Blocker(symbol: "lock.fill", title: "That's three", message: "Nightcap's holding until \(time(until)). Sleep is also an option.")
        default:
            return nil
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Image(systemName: isBaseline ? "gauge.with.dots.needle.33percent" : "moon.stars.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.amber)
            Text(isBaseline ? "Set your sober baseline" : "Prove it")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.moonlight)
            Text(isBaseline
                 ? "Take this now, while you're sober and focused. At night you'll need to score close to it."
                 : "Three quick tests. Pass all three and you're out. Fail and it's a 15-minute cooldown.")
                .foregroundStyle(Theme.dusk)
            VStack(alignment: .leading, spacing: 12) {
                Label("Reaction time — tap when it turns amber", systemImage: "bolt.fill")
                Label("Typing — copy a sentence, fast and right", systemImage: "keyboard")
                Label("Memory — repeat a sequence", systemImage: "square.grid.2x2.fill")
            }
            .foregroundStyle(Theme.moonlight)
            .card()
            Spacer()
            Button("Start") { step = .reaction }
                .buttonStyle(GlowButtonStyle())
            Button("Not now") { dismiss() }
                .frame(maxWidth: .infinity)
                .foregroundStyle(Theme.dusk)
        }
        .padding(24)
    }

    private var typingLimit: TimeInterval {
        ChallengeRules.typingTimeLimit(
            for: sentence,
            baseline: isBaseline ? nil : model.settings.baseline,
            difficulty: model.settings.challengeDifficulty
        )
    }

    // MARK: - Grading

    private func grade(memoryPassed: Bool) {
        let scores = ChallengeScores(
            reactionTimes: reactionTimes,
            falseStarts: falseStarts,
            typingCharsPerSecond: typing?.charsPerSecond ?? 0,
            typingAccuracy: typing?.accuracy ?? 0,
            typingPasted: typing?.pasted ?? false,
            memoryPassed: memoryPassed
        )
        if isBaseline {
            let problems = model.saveBaseline(scores)
            result = problems.isEmpty ? .baselineSaved : .baselineRetry(problems)
        } else if let outcome = model.finishChallenge(scores, origin: origin) {
            result = .outcome(outcome)
        }
        step = .result
    }

    @ViewBuilder
    private var resultView: some View {
        switch result {
        case .baselineSaved:
            MessageView(symbol: "checkmark.seal.fill", title: "Baseline saved", message: "Reaction \(ms(reactionMedian)), typing \(String(format: "%.1f", typing?.charsPerSecond ?? 0)) characters a second. Night You has a bar to clear.", button: "Done") { dismiss() }
        case .baselineRetry(let problems):
            MessageView(symbol: "arrow.counterclockwise", title: "Let's run that again", message: "\(names(problems)) came out slower than even a tired night would allow. Take it when you're focused.", button: "Try again", action: restart)
        case .outcome(.unlockedSession):
            MessageView(symbol: "sun.horizon.fill", title: "Okay, you're good", message: "Shields are down for the rest of the night. Get home safe.", button: "Done") { dismiss() }
        case .outcome(.unlockedBriefly(let until)):
            MessageView(symbol: "timer", title: "Unlocked till \(time(until))", message: "That app is open for a bit. Everything else stays locked.", button: "Done") { dismiss() }
        case .outcome(.failed(let verdict, let gate)):
            MessageView(symbol: "moon.zzz.fill", title: "Not tonight", message: "\(names(verdict.failed)) didn't make it. \(gateLine(gate))", button: "Fair enough") { dismiss() }
        case nil:
            EmptyView()
        }
    }

    private func restart() {
        reactionTimes = []
        falseStarts = 0
        typing = nil
        result = nil
        sentence = ChallengeRules.sentences.randomElement()!
        step = .intro
    }

    private var reactionMedian: TimeInterval {
        ChallengeScores(reactionTimes: reactionTimes, falseStarts: 0, typingCharsPerSecond: 0, typingAccuracy: 0, typingPasted: false, memoryPassed: false).reactionMedian
    }

    private func gateLine(_ gate: ChallengeGate) -> String {
        switch gate {
        case .open: "Try again whenever."
        case .coolingDown(let until): "Next try at \(time(until))."
        case .lockedForNight(let until): "That's three strikes. Nightcap's holding until \(time(until))."
        }
    }

    private func names(_ checks: Set<ChallengeCheck>) -> String {
        let ordered = ChallengeCheck.allCases.filter(checks.contains).map { check in
            switch check {
            case .reaction: "Reaction time"
            case .typing: "Typing"
            case .memory: "Memory"
            }
        }
        return ordered.formatted(.list(type: .and))
    }

    private func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
    private func ms(_ seconds: TimeInterval) -> String { "\(Int(seconds * 1000)) ms" }
}

private struct MessageView: View {
    let symbol: String
    let title: String
    let message: String
    let button: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 60))
                .foregroundStyle(Theme.amber)
            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.moonlight)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.dusk)
            Spacer()
            Button(button, action: action)
                .buttonStyle(GlowButtonStyle())
        }
        .padding(24)
    }
}
