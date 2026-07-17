#if os(macOS)
import ApplicationServices
import AVFoundation
import Foundation
import MixPilotCore

public struct DJEnvironmentProbeResult: Sendable {
    public var backend: DJBackendIdentifier
    public var softwareVersion: String?
    public var isRunning: Bool
    public var processIdentifier: Int32?
    public var accessibilityGranted: Bool
    public var audioPermission: String

    public init(
        backend: DJBackendIdentifier,
        softwareVersion: String?,
        isRunning: Bool,
        processIdentifier: Int32?,
        accessibilityGranted: Bool,
        audioPermission: String
    ) {
        self.backend = backend
        self.softwareVersion = softwareVersion
        self.isRunning = isRunning
        self.processIdentifier = processIdentifier
        self.accessibilityGranted = accessibilityGranted
        self.audioPermission = audioPermission
    }
}

public struct DJEnvironmentProbe: Sendable {
    public let backend: DJBackendIdentifier
    private let detector: DJApplicationEnvironmentDetector

    public init(
        backend: DJBackendIdentifier,
        detector: DJApplicationEnvironmentDetector = DJApplicationEnvironmentDetector()
    ) {
        self.backend = backend
        self.detector = detector
    }

    @MainActor
    public func probe() -> DJEnvironmentProbeResult {
        let environment = detector.detect(backend)
        return DJEnvironmentProbeResult(
            backend: backend,
            softwareVersion: environment.softwareVersion,
            isRunning: environment.isRunning,
            processIdentifier: environment.processIdentifier,
            accessibilityGranted: AXIsProcessTrusted(),
            audioPermission: audioAuthorizationDescription()
        )
    }

    private func audioAuthorizationDescription() -> String {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: "Autorisée"
        case .denied: "Refusée"
        case .restricted: "Restreinte"
        case .notDetermined: "Non demandée"
        @unknown default: "Inconnue"
        }
    }
}

@available(*, deprecated, renamed: "DJEnvironmentProbeResult")
public typealias SeratoProbeResult = DJEnvironmentProbeResult

@available(*, deprecated, message: "Use DJEnvironmentProbe(backend:) with an explicit backend.")
public struct SeratoEnvironmentProbe: Sendable {
    public init() {}

    @MainActor
    public func probe() -> DJEnvironmentProbeResult {
        DJEnvironmentProbe(backend: .serato).probe()
    }
}
#endif
