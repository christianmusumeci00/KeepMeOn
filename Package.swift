// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeepMeOn",
    platforms: [.macOS(.v13)],
    targets: [
        // Logica pura (fascia oraria, stato): nessuna dipendenza da AppKit o IOKit, testabile.
        .target(name: "KeepMeOnCore"),
        // App da barra dei menu: UI, timer, eventi di sistema, IOKit.
        .executableTarget(name: "KeepMeOn", dependencies: ["KeepMeOnCore"]),
        .testTarget(name: "KeepMeOnCoreTests", dependencies: ["KeepMeOnCore"]),
    ]
)
