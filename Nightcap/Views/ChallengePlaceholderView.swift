import SwiftUI

/// Where the shield's "I'm sober — let me prove it" lands. Phase 2 swaps this
/// for the real three-step Sobriety Challenge.
struct ChallengePlaceholderView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.amber)
            Text("The Sobriety Challenge is still in training")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.moonlight)
            if let session = model.session {
                Text("Until it's ready, Nightcap holds until \(session.plannedEnd.formatted(date: .omitted, time: .shortened)).")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.dusk)
            }
            Spacer()
            Button("Fair enough") { dismiss() }
                .buttonStyle(GlowButtonStyle())
        }
        .padding(24)
        .background(Theme.background.ignoresSafeArea())
    }
}
