import NightcapCore
import SwiftUI

struct TypingOutcome {
    var charsPerSecond: Double
    var accuracy: Double
    var pasted: Bool
}

/// Type the sentence before the clock runs out. The clock starts on the
/// first keystroke, so reading time doesn't count.
struct TypingTestView: View {
    let sentence: String
    let timeLimit: TimeInterval
    let onFinish: (TypingOutcome) -> Void

    @State private var typed = ""
    @State private var startedAt: Date?
    @State private var pasted = false
    @State private var finished = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Type this exactly")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.dusk)
            Text(sentence)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.moonlight)
                // Copying the sentence would defeat the point.
                .textSelection(.disabled)

            TextField("Start typing…", text: $typed, axis: .vertical)
                .font(.title3)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .focused($focused)
                .padding()
                .background(Theme.navy, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onChange(of: typed) { old, new in
                    if startedAt == nil, !new.isEmpty { startedAt = .now }
                    if new.count - old.count > 3 { pasted = true }
                }

            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                let left = remaining(at: context.date)
                ProgressView(value: left, total: timeLimit)
                    .tint(left < timeLimit * 0.25 ? .red : Theme.amber)
                Text(startedAt == nil ? "\(Int(timeLimit.rounded())) seconds once you start" : "\(Int(left.rounded(.up)))s left")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Theme.dusk)
            }

            Button("Done") { finish() }
                .buttonStyle(GlowButtonStyle())
                .disabled(typed.isEmpty)
        }
        .padding(24)
        .onAppear { focused = true }
        .task {
            // Auto-submit when time runs out.
            while !finished {
                try? await Task.sleep(for: .milliseconds(250))
                if startedAt != nil, remaining(at: .now) <= 0 { finish() }
            }
        }
    }

    private func remaining(at date: Date) -> TimeInterval {
        guard let startedAt else { return timeLimit }
        return max(0, timeLimit - date.timeIntervalSince(startedAt))
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        let elapsed = max(0.5, Date.now.timeIntervalSince(startedAt ?? .now))
        onFinish(TypingOutcome(
            charsPerSecond: Double(sentence.count) / elapsed,
            accuracy: ChallengeRules.accuracy(typed: typed, target: sentence),
            pasted: pasted
        ))
    }
}
