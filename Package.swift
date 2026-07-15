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
products.append(.executable(name: "MixPilotHardwareProbeCLI", targets: ["MixPilotHardwareProbeCLI"]))
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
            .linkedFramework("Network"),
            .linkedFramework("IOKit"),
        ]
    )
)
targets.append(
    .target(
        name: "MixPilotRuntime",
        dependencies: ["MixPilotCore", "MixPilotMIDI", "MixPilotSystem"]
    )
)
targets.append(
    .target(
        name: "MixPilotRemoteBridge",
        dependencies: ["MixPilotCore"],
        linkerSettings: [
            .linkedFramework("Network"),
            .linkedFramework("Security"),
        ]
    )
)
targets.append(
    .executableTarget(
        name: "MixPilotHardwareProbeCLI",
        dependencies: ["MixPilotCore", "MixPilotMIDI", "MixPilotSystem"]
    )
)
targets.append(
    .executableTarget(
        name: "MixPilotApp",
        dependencies: [
            "MixPilotCore",
            "MixPilotMIDI",
            "MixPilotSystem",
            "MixPilotRuntime",
            "MixPilotRemoteBridge",
        ],
        linkerSettings: [
            .linkedFramework("SwiftUI"),
            .linkedFramework("AppKit"),
        ]
    )
)
targets.append(
    .testTarget(
        name: "MixPilotRemoteBridgeTests",
        dependencies: ["MixPilotRemoteBridge"]
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
