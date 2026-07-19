// swift-tools-version: 6.0
import PackageDescription

// Keep the cross-platform test graph independent from macOS-only cloud and
// hardware dependencies. Swift Crypto provides the Crypto module on Linux;
// Apple platforms continue to use CryptoKit from the SDK.
var dependencies: [Package.Dependency] = [
    .package(
        url: "https://github.com/apple/swift-crypto.git",
        from: "3.0.0"
    ),
]

var products: [Product] = [
    .library(name: "MixPilotCore", targets: ["MixPilotCore"]),
    .library(name: "MixPilotHelp", targets: ["MixPilotHelp"]),
    .library(name: "MixPilotRemoteProtocol", targets: ["MixPilotRemoteProtocol"]),
    .executable(name: "MixPilotSimulatorCLI", targets: ["MixPilotSimulatorCLI"]),
    .executable(name: "MixPilotMappingPublisherCLI", targets: ["MixPilotMappingPublisherCLI"]),
]

var targets: [Target] = [
    .target(
        name: "MixPilotCore",
        dependencies: [
            .product(name: "Crypto", package: "swift-crypto"),
        ]
    ),
    .target(
        name: "MixPilotHelp",
        resources: [.process("Resources")]
    ),
    .target(
        name: "MixPilotRemoteProtocol",
        path: "Shared/RemoteProtocolV2/Sources/MixPilotRemoteProtocol"
    ),
    .executableTarget(
        name: "MixPilotSimulatorCLI",
        dependencies: ["MixPilotCore"]
    ),
    .executableTarget(
        name: "MixPilotMappingPublisherCLI",
        dependencies: ["MixPilotCore"]
    ),
    .testTarget(
        name: "MixPilotCoreTests",
        dependencies: ["MixPilotCore"],
        path: "Tests/MixPilotCoreTests"
    ),
    .testTarget(
        name: "MixPilotHelpTests",
        dependencies: ["MixPilotHelp"],
        path: "Tests/MixPilotHelpTests"
    ),
    .testTarget(
        name: "MixPilotRemoteProtocolTests",
        dependencies: ["MixPilotRemoteProtocol"],
        path: "Shared/RemoteProtocolV2/Tests/MixPilotRemoteProtocolTests"
    ),
]

#if os(macOS)
dependencies.append(
    .package(
        url: "https://github.com/supabase/supabase-swift.git",
        exact: "2.46.0"
    )
)

products.append(contentsOf: [
    .library(name: "MixPilotMIDI", targets: ["MixPilotMIDI"]),
    .library(name: "MixPilotSystem", targets: ["MixPilotSystem"]),
    .library(name: "MixPilotRuntime", targets: ["MixPilotRuntime"]),
    .library(name: "MixPilotRemoteBridge", targets: ["MixPilotRemoteBridge"]),
    .executable(name: "MixPilotAutopilot", targets: ["MixPilotApp"]),
    .executable(name: "MixPilotHardwareProbeCLI", targets: ["MixPilotHardwareProbeCLI"]),
])

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
        dependencies: [
            "MixPilotCore",
            "MixPilotMIDI",
            .product(name: "Supabase", package: "supabase-swift"),
        ],
        linkerSettings: [
            .linkedFramework("AppKit"),
            .linkedFramework("ApplicationServices"),
            .linkedFramework("AVFoundation"),
            .linkedFramework("Vision"),
            .linkedFramework("Network"),
            .linkedFramework("IOKit"),
            .linkedFramework("Security"),
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
        dependencies: ["MixPilotCore", "MixPilotRemoteProtocol"],
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
            "MixPilotHelp",
            "MixPilotMIDI",
            "MixPilotSystem",
            "MixPilotRuntime",
            "MixPilotRemoteBridge",
            "MixPilotRemoteProtocol",
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
        dependencies: ["MixPilotRemoteBridge", "MixPilotRemoteProtocol"],
        path: "Tests/MixPilotRemoteBridgeTests"
    )
)
targets.append(
    .testTarget(
        name: "MixPilotSystemTests",
        dependencies: ["MixPilotCore", "MixPilotMIDI", "MixPilotSystem"],
        path: "Tests/MixPilotSystemTests"
    )
)
targets.append(
    .testTarget(
        name: "MixPilotRuntimeTests",
        dependencies: ["MixPilotCore", "MixPilotRuntime"],
        path: "Tests/MixPilotRuntimeTests"
    )
)
#endif

let package = Package(
    name: "MixPilot",
    defaultLocalization: "fr",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: products,
    dependencies: dependencies,
    targets: targets
)
