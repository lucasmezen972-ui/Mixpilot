#if os(macOS)
import AppKit
import ApplicationServices
import AVFoundation
import Foundation

public struct SeratoProbeResult: Sendable {
    public var isRunning: Bool
    public var processIdentifier: Int32?
    public var accessibilityGranted: Bool
    public var audioPermission: String

    public init(isRunning: Bool, processIdentifier: Int32?, accessibilityGranted: Bool, audioPermission: String) {
        self.isRunning = isRunning
        self.processIdentifier = processIdentifier
        self.accessibilityGranted = accessibilityGranted
        self.audioPermission = audioPermission
    }
}

public struct SeratoEnvironmentProbe: Sendable {
    public init() {}

    @MainActor
    public func probe() -> SeratoProbeResult {
        let serato = NSWorkspace.shared.runningApplications.first { application in
            let name = application.localizedName?.lowercased() ?? ""
            return name.contains("serato dj pro") || name == "serato dj"
        }

        return SeratoProbeResult(
            isRunning: serato != nil,
            processIdentifier: serato?.processIdentifier,
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
#endif
