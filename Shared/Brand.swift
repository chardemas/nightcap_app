import UIKit

/// Brand colors as UIColor, because shield configurations take UIKit colors.
/// The SwiftUI side wraps these in Theme.swift.
enum Brand {
    static let midnight = UIColor(red: 0.04, green: 0.06, blue: 0.16, alpha: 1)
    static let navy = UIColor(red: 0.09, green: 0.12, blue: 0.27, alpha: 1)
    static let amber = UIColor(red: 1.00, green: 0.71, blue: 0.28, alpha: 1)
    static let moonlight = UIColor(red: 0.92, green: 0.91, blue: 0.86, alpha: 1)
    static let dusk = UIColor(red: 0.62, green: 0.65, blue: 0.78, alpha: 1)
}
