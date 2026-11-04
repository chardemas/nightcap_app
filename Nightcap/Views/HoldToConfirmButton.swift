import SwiftUI

/// "Never a single casual tap." The fill grows while held; letting go early
/// resets it. Fires once the hold completes.
struct HoldToConfirmButton: View {
    let title: String
    var duration: Double = 1.5
    let action: () -> Void

    @State private var progress: CGFloat = 0

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Theme.moonlight)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.amber.opacity(0.15))
                        Capsule()
                            .fill(Theme.amber.opacity(0.85))
                            .frame(width: proxy.size.width * progress)
                    }
                }
            }
            .clipShape(Capsule())
            .contentShape(Capsule())
            .onLongPressGesture(minimumDuration: duration, maximumDistance: 40) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                action()
                withAnimation(.easeOut(duration: 0.3)) { progress = 0 }
            } onPressingChanged: { pressing in
                withAnimation(pressing ? .linear(duration: duration) : .easeOut(duration: 0.2)) {
                    progress = pressing ? 1 : 0
                }
            }
            .accessibilityElement()
            .accessibilityLabel(title)
            .accessibilityHint("Double-tap and hold to confirm.")
            .accessibilityAddTraits(.isButton)
    }
}
