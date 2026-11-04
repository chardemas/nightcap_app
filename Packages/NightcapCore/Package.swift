// swift-tools-version:5.9
import PackageDescription

// Pure Foundation logic shared by the app and every extension.
// No FamilyControls / ManagedSettings here, so it builds and tests anywhere.
let package = Package(
    name: "NightcapCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "NightcapCore", targets: ["NightcapCore"])],
    targets: [
        .target(name: "NightcapCore"),
        .testTarget(name: "NightcapCoreTests", dependencies: ["NightcapCore"]),
    ]
)
