import NightcapCore
import SwiftUI

/// Tap when the screen turns amber, `rounds` times. Tapping early is a false
/// start and the round restarts.
struct ReactionTestView: View {
    let rounds: Int
    let onFinish: (_ times: [TimeInterval], _ falseStarts: Int) -> Void

    private enum Phase: Equatable {
        case ready, waiting, go(Date), tooSoon, result(TimeInterval)
    }

    @State private var phase = Phase.ready
    @State private var times: [TimeInterval] = []
    @State private var falseStarts = 0
    @State private var touching = false
    @State private var timer: Task<Void, Never>?

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Round \(min(times.count + 1, rounds)) of \(rounds)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(foreground.opacity(0.7))
                Text(headline)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(foreground)
                Text(detail)
                    .foregroundStyle(foreground.opacity(0.8))
            }
            .padding(32)
        }
        .contentShape(Rectangle())
        // Register on touch-down, not lift-off, so the timing is honest.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !touching else { return }
                    touching = true
                    handleTouch()
                }
                .onEnded { _ in touching = false }
        )
        .onDisappear { timer?.cancel() }
        .accessibilityElement()
        .accessibilityLabel("\(headline). \(detail)")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    private func handleTouch() {
        switch phase {
        case .ready, .tooSoon, .result:
            startRound()
        case .waiting:
            timer?.cancel()
            falseStarts += 1
            phase = .tooSoon
        case .go(let start):
            let time = Date.now.timeIntervalSince(start)
            times.append(time)
            if times.count == rounds {
                onFinish(times, falseStarts)
            } else {
                phase = .result(time)
            }
        }
    }

    private func startRound() {
        phase = .waiting
        timer = Task {
            try? await Task.sleep(for: .seconds(Double.random(in: 1.5...4.0)))
            guard !Task.isCancelled else { return }
            phase = .go(.now)
        }
    }

    private var background: Color {
        switch phase {
        case .go: Theme.amber
        case .tooSoon: Color(red: 0.55, green: 0.16, blue: 0.22)
        default: Theme.midnight
        }
    }

    private var foreground: Color {
        if case .go = phase { Theme.midnight } else { Theme.moonlight }
    }

    private var headline: String {
        switch phase {
        case .ready: "Tap to start"
        case .waiting: "Wait for it…"
        case .go: "TAP!"
        case .tooSoon: "Too soon!"
        case .result(let time): "\(Int(time * 1000)) ms"
        }
    }

    private var detail: String {
        switch phase {
        case .ready: "Tap the moment the screen turns amber."
        case .waiting: "Eyes on the screen."
        case .go: ""
        case .tooSoon: "Patience. Tap to try that round again."
        case .result: "Tap for the next round."
        }
    }
}
