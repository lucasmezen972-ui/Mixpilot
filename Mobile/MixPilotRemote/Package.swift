// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MixPilotRemoteAppModels",
    platforms: [.macOS(.v14), .iOS(.v17)],
    dependencies: [
        .package(path: "../../Shared/RemoteProtocolV2"),
    ],
    targets: [
        .target(
            name: "MixPilotRemoteAppModels",
            dependencies: [
                .product(name: "MixPilotRemoteProtocol", package: "RemoteProtocolV2"),
            ],
            path: "Sources",
            sources: [
                "RemoteModels.swift",
                "RemoteSnapshotSequencePolicy.swift",
            ]
        ),
        .testTarget(
            name: "MixPilotRemoteProtocolTests",
            dependencies: [
                "MixPilotRemoteAppModels",
                .product(name: "MixPilotRemoteProtocol", package: "RemoteProtocolV2"),
            ],
            path: "Tests"
        ),
    ]
)
