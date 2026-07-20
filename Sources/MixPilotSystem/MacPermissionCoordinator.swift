#if os(macOS)
import AppKit
import ApplicationServices
import AVFoundation
import CoreGraphics
import Foundation

public enum MacPermissionKind: String, CaseIterable, Identifiable, Sendable {
    case accessibility
    case screenRecording
    case microphone

    public var id: String { rawValue }
}

public enum MacPermissionState: String, Sendable {
    case authorized
    case actionRequired
    case denied
    case restricted

    public var isAuthorized: Bool { self == .authorized }
}

public struct MacPermissionSnapshot: Sendable, Equatable {
    public var accessibility: MacPermissionState
    public var screenRecording: MacPermissionState
    public var microphone: MacPermissionState

    public init(
        accessibility: MacPermissionState,
        screenRecording: MacPermissionState,
        microphone: MacPermissionState
    ) {
        self.accessibility = accessibility
        self.screenRecording = screenRecording
        self.microphone = microphone
    }

    public static let initial = MacPermissionSnapshot(
        accessibility: .actionRequired,
        screenRecording: .actionRequired,
        microphone: .actionRequired
    )

    public subscript(_ kind: MacPermissionKind) -> MacPermissionState {
        switch kind {
        case .accessibility: accessibility
        case .screenRecording: screenRecording
        case .microphone: microphone
        }
    }

    public var allRecommendedGranted: Bool {
        MacPermissionKind.allCases.allSatisfy { self[$0].isAuthorized }
    }

    public var missingPermissions: [MacPermissionKind] {
        MacPermissionKind.allCases.filter { !self[$0].isAuthorized }
    }
}

@MainActor
public struct MacPermissionCoordinator {
    public init() {}

    public func snapshot() -> MacPermissionSnapshot {
        MacPermissionSnapshot(
            accessibility: AXIsProcessTrusted() ? .authorized : .actionRequired,
            screenRecording: CGPreflightScreenCaptureAccess() ? .authorized : .actionRequired,
            microphone: microphoneState()
        )
    }

    @discardableResult
    public func request(_ kind: MacPermissionKind) async -> MacPermissionSnapshot {
        switch kind {
        case .accessibility:
            let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        case .screenRecording:
            _ = CGRequestScreenCaptureAccess()
        case .microphone:
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        }
        return snapshot()
    }

    public func openSystemSettings(for kind: MacPermissionKind) {
        let pane: String
        switch kind {
        case .accessibility:
            pane = "Privacy_Accessibility"
        case .screenRecording:
            pane = "Privacy_ScreenCapture"
        case .microphone:
            pane = "Privacy_Microphone"
        }
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(pane)"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    private func microphoneState() -> MacPermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .actionRequired
        @unknown default: .actionRequired
        }
    }
}
#endif
