// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MixPilotRemoteProtocol",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "MixPilotRemoteProtocol", targets: ["MixPilotRemoteProtocol"]),
    ],
    targets: [
        .target(name: "MixPilotRemoteProtocol"),
        .testTarget(
            name: "MixPilotRemoteProtocolTests",
            dependencies: ["MixPilotRemoteProtocol"]
        ),
    ]
)
