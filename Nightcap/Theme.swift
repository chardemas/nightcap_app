import SwiftUI

/// Deep navy/midnight with a warm amber "nightcap glow". Dark mode first.
enum Theme {
    static let midnight = Color(Brand.midnight)
    static let navy = Color(Brand.navy)
    static let amber = Color(Brand.amber)
    static let moonlight = Color(Brand.moonlight)
    static let dusk = Color(Brand.dusk)
    static let good = Color(red: 0.45, green: 0.85, blue: 0.62)

    static let background = LinearGradient(colors: [midnight, navy], startPoint: .top, endPoint: .bottom)
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.navy.opacity(0.7), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.06)))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }

    /// Night background behind a screen, including under Forms and Lists.
    func nightBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
    }
}

/// The big amber call-to-action.
struct GlowButtonStyle: ButtonStyle {
    var filled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(filled ? Theme.midnight : Theme.amber)
            .background {
                Capsule().fill(filled ? AnyShapeStyle(Theme.amber) : AnyShapeStyle(Theme.amber.opacity(0.12)))
            }
            .shadow(color: filled ? Theme.amber.opacity(0.35) : .clear, radius: 16, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}
