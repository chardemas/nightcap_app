import Foundation

/// The App Group every target shares. Must match `APP_GROUP` in project.yml
/// and the entitlements files.
public enum AppGroup {
    public static let identifier = "group.com.charlottedemas.nightcap"

    public static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return url
        }
        // Only hit outside a signed iOS build (e.g. `swift build` on a Mac).
        let fallback = FileManager.default.temporaryDirectory.appendingPathComponent("nightcap-group", isDirectory: true)
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }
}

/// A Codable value persisted as one JSON file. Writes are atomic and go through
/// NSFileCoordinator because the app and its extensions run in separate processes.
public struct JSONFile<Value: Codable>: Sendable {
    public let url: URL

    public init(_ name: String, in directory: URL = AppGroup.containerURL) {
        url = directory.appendingPathComponent(name)
    }

    public func load() -> Value? {
        var result: Value?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: nil) { readURL in
            guard let data = try? Data(contentsOf: readURL) else { return }
            result = try? Self.decoder.decode(Value.self, from: data)
        }
        return result
    }

    public func save(_ value: Value) throws {
        let data = try Self.encoder.encode(value)
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: nil) { writeURL in
            do { try data.write(to: writeURL, options: .atomic) } catch { writeError = error }
        }
        if let writeError { throw writeError }
    }

    /// Read-modify-write under a single coordinated write, so an extension
    /// appending an attempt can't clobber the app's write (or vice versa).
    public func update(default defaultValue: @autoclosure () -> Value, _ body: (inout Value) -> Void) throws {
        var writeError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forMerging, error: nil) { fileURL in
            var value = (try? Data(contentsOf: fileURL)).flatMap { try? Self.decoder.decode(Value.self, from: $0) } ?? defaultValue()
            body(&value)
            do { try Self.encoder.encode(value).write(to: fileURL, options: .atomic) } catch { writeError = error }
        }
        if let writeError { throw writeError }
    }

    public func delete() {
        try? FileManager.default.removeItem(at: url)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

/// Every file Nightcap keeps in the App Group container.
public enum NightcapFiles {
    public static var settings: JSONFile<NightcapSettings> { JSONFile("settings.json") }
    public static var currentSession: JSONFile<Session> { JSONFile("current-session.json") }
    public static var sessionHistory: JSONFile<[Session]> { JSONFile("sessions.json") }
    public static var attempts: JSONFile<[BlockedAttempt]> { JSONFile("attempts.json") }
}
