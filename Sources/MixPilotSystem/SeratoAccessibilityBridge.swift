#if os(macOS)
import AppKit
import ApplicationServices
import Foundation

public struct SeratoWindowObservation: Hashable, Sendable {
    public var isRunning: Bool
    public var processIdentifier: Int32?
    public var windowTitle: String?
    public var visibleText: [String]
    public var accessibilityGranted: Bool
    public var observedAt: Date

    public init(
        isRunning: Bool,
        processIdentifier: Int32?,
        windowTitle: String?,
        visibleText: [String],
        accessibilityGranted: Bool,
        observedAt: Date = Date()
    ) {
        self.isRunning = isRunning
        self.processIdentifier = processIdentifier
        self.windowTitle = windowTitle
        self.visibleText = visibleText
        self.accessibilityGranted = accessibilityGranted
        self.observedAt = observedAt
    }

    public func contains(text: String) -> Bool {
        let needle = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return visibleText.contains { candidate in
            candidate.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .contains(needle)
        }
    }
}

public enum SeratoAccessibilityError: Error, LocalizedError {
    case seratoNotRunning
    case accessibilityNotGranted
    case activationFailed

    public var errorDescription: String? {
        switch self {
        case .seratoNotRunning: "Serato DJ Pro n'est pas lancé."
        case .accessibilityNotGranted: "La permission Accessibilité n'est pas accordée à MixPilot."
        case .activationFailed: "Impossible d'activer la fenêtre Serato DJ Pro."
        }
    }
}

@MainActor
public final class SeratoAccessibilityBridge {
    public init() {}

    public func requestAccessibilityPrompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    public func activateSerato() throws {
        guard let application = seratoApplication() else {
            throw SeratoAccessibilityError.seratoNotRunning
        }
        guard application.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) else {
            throw SeratoAccessibilityError.activationFailed
        }
    }

    public func observe(maxDepth: Int = 5, maximumStrings: Int = 250) -> SeratoWindowObservation {
        guard let application = seratoApplication() else {
            return SeratoWindowObservation(
                isRunning: false,
                processIdentifier: nil,
                windowTitle: nil,
                visibleText: [],
                accessibilityGranted: AXIsProcessTrusted()
            )
        }

        guard AXIsProcessTrusted() else {
            return SeratoWindowObservation(
                isRunning: true,
                processIdentifier: application.processIdentifier,
                windowTitle: nil,
                visibleText: [],
                accessibilityGranted: false
            )
        }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        let focusedWindow = elementAttribute(appElement, attribute: kAXFocusedWindowAttribute)
        let mainWindow = focusedWindow ?? elementAttribute(appElement, attribute: kAXMainWindowAttribute)
        let title = mainWindow.flatMap { stringAttribute($0, attribute: kAXTitleAttribute) }

        var strings: [String] = []
        if let mainWindow {
            collectStrings(
                from: mainWindow,
                depth: 0,
                maxDepth: max(1, maxDepth),
                maximumStrings: max(1, maximumStrings),
                into: &strings
            )
        }

        let normalized = Array(Set(strings.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }))
            .sorted()

        return SeratoWindowObservation(
            isRunning: true,
            processIdentifier: application.processIdentifier,
            windowTitle: title,
            visibleText: normalized,
            accessibilityGranted: true
        )
    }

    private func seratoApplication() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { application in
            let name = application.localizedName?.lowercased() ?? ""
            let bundle = application.bundleIdentifier?.lowercased() ?? ""
            return name.contains("serato dj pro") || name == "serato dj" || bundle.contains("serato")
        }
    }

    private func collectStrings(
        from element: AXUIElement,
        depth: Int,
        maxDepth: Int,
        maximumStrings: Int,
        into strings: inout [String]
    ) {
        guard depth <= maxDepth, strings.count < maximumStrings else { return }

        for attribute in [kAXTitleAttribute, kAXValueAttribute, kAXDescriptionAttribute, kAXHelpAttribute] {
            if let value = stringAttribute(element, attribute: attribute), !value.isEmpty {
                strings.append(value)
                if strings.count >= maximumStrings { return }
            }
        }

        guard let children = arrayAttribute(element, attribute: kAXChildrenAttribute) else { return }
        for child in children {
            collectStrings(
                from: child,
                depth: depth + 1,
                maxDepth: maxDepth,
                maximumStrings: maximumStrings,
                into: &strings
            )
            if strings.count >= maximumStrings { return }
        }
    }

    private func elementAttribute(_ element: AXUIElement, attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as! AXUIElement?
    }

    private func stringAttribute(_ element: AXUIElement, attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private func arrayAttribute(_ element: AXUIElement, attribute: String) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? [AXUIElement]
    }
}
#endif
