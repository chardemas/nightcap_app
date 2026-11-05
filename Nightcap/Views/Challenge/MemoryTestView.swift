import NightcapCore
import SwiftUI

/// Simon-style: watch the pads light up, then repeat the sequence.
/// One wrong tap fails the test.
struct MemoryTestView: View {
    let length: Int
    let onFinish: (_ passed: Bool) -> Void

    private struct Pad {
        let color: Color
        let symbol: String
        let name: String
    }

    // Each pad has a symbol too, so color isn't the only cue.
    private let pads = [
        Pad(color: Theme.amber, symbol: "moon.fill", name: "Moon"),
        Pad(color: Color(red: 0.30, green: 0.78, blue: 0.76), symbol: "star.fill", name: "Star"),
        Pad(color: Color(red: 0.93, green: 0.42, blue: 0.55), symbol: "wineglass.fill", name: "Glass"),
        Pad(color: Color(red: 0.58, green: 0.48, blue: 0.95), symbol: "music.note", name: "Note"),
    ]

    @State private var sequence: [Int] = []
    @State private var lit: Int?
    @State private var accepting = false
    @State private var position = 0

    var body: some View {
        VStack(spacing: 24) {
            Text(accepting ? "Your turn: \(position)/\(length)" : "Watch closely…")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.moonlight)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                ForEach(pads.indices, id: \.self) { index in
                    padButton(index)
                }
            }
        }
        .padding(24)
        .task { await play() }
    }

    private func padButton(_ index: Int) -> some View {
        let pad = pads[index]
        let isLit = lit == index
        return Button { tap(index) } label: {
            Image(systemName: pad.symbol)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Theme.midnight.opacity(isLit ? 1 : 0.5))
                .frame(maxWidth: .infinity, minHeight: 130)
                .background(pad.color.opacity(isLit ? 1 : 0.3), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: isLit ? pad.color.opacity(0.7) : .clear, radius: 20)
                .scaleEffect(isLit ? 1.04 : 1)
                .animation(.easeOut(duration: 0.12), value: isLit)
        }
        .buttonStyle(.plain)
        .disabled(!accepting)
        .accessibilityLabel(pad.name)
    }

    private func play() async {
        sequence = ChallengeRules.memorySequence(length: length, pads: pads.count)
        try? await Task.sleep(for: .milliseconds(900))
        for index in sequence {
            lit = index
            try? await Task.sleep(for: .milliseconds(550))
            lit = nil
            try? await Task.sleep(for: .milliseconds(250))
        }
        accepting = true
    }

    private func tap(_ index: Int) {
        guard accepting else { return }
        flash(index)
        guard sequence[position] == index else {
            accepting = false
            onFinish(false)
            return
        }
        position += 1
        if position == sequence.count {
            accepting = false
            onFinish(true)
        }
    }

    private func flash(_ index: Int) {
        lit = index
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            if lit == index { lit = nil }
        }
    }
}
