import Foundation

public enum RideApp: String, Codable, CaseIterable, Identifiable, Sendable {
    case uber, lyft

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .uber: "Uber"
        case .lyft: "Lyft"
        }
    }

    /// Must be listed in LSApplicationQueriesSchemes for `canOpenURL`.
    public var probeURL: URL { URL(string: "\(rawValue)://")! }

    /// SPEC §4.5 deep links, destination preset to home.
    public func rideHomeURL(to home: HomeAddress) -> URL? {
        let lat = Self.coordinate(home.latitude)
        let lng = Self.coordinate(home.longitude)
        return switch self {
        case .uber:
            URL(string: "uber://?action=setPickup&pickup=my_location&dropoff[latitude]=\(lat)&dropoff[longitude]=\(lng)&dropoff[nickname]=Home")
        case .lyft:
            URL(string: "lyft://ridetype?id=lyft&destination[latitude]=\(lat)&destination[longitude]=\(lng)")
        }
    }

    public var appStoreURL: URL {
        switch self {
        case .uber: URL(string: "https://apps.apple.com/app/id368677368")!
        case .lyft: URL(string: "https://apps.apple.com/app/id529379082")!
        }
    }

    private static func coordinate(_ value: Double) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}
