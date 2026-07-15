// swift-tools-version: 6.0
import PackageDescription

var products: [Product] = [
    .library(name: "MixPilotCore", targets: ["MixPilotCore"]),
    .executable(name: "MixPilotSimulatorCLI", targets: ["MixPilotSimulatorCLI"]),
]

var targets: [Target] = [
    .target(name: "MixPilotCore"),
    .executableTarget(
        name: "MixPilotSimulatorCLI",
        dependencies: ["MixPilotCore"]
    ),
    .testTarget(
        name: "MixPilotCoreTests",
        dependencies: ["MixPilotCore"]
    ),
]

#if os(macOS)
products.append(.executable(name: "MixPilotAutopilot", targets: ["MixPilotApp"]))
targets.append(
    .target(
        name: "MixPilotMIDI",
        dependencies: ["MixPilotCore"],
        linkerSettings: [.linkedFramework("CoreMIDI")]
    )
)
targets.append(
    .target(
        name: "MixPilotSystem",
        dependencies: ["MixPilotCore"],
        linkerSettings: [
            .linkedFramework("AppKit"),
            .linkedFramework("ApplicationServices"),
            .linkedFramework("AVFoundation"),
        ]
    )
)
targets.append(
    .executableTarget(
        name: "MixPilotApp",
        dependencies: ["MixPilotCore", "MixPilotMIDI", "MixPilotSystem"],
        linkerSettings: [
            .linkedFramework("SwiftUI"),
            .linkedFramework("AppKit"),
        ]
    )
)
#endif

let package = Package(
    name: "MixPilot",
    defaultLocalization: "fr",
    platforms: [.macOS(.v14)],
    products: products,
    targets: targets
)
