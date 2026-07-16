#if os(macOS)
import AppKit
@preconcurrency import ApplicationServices
import Foundation
import MixPilotCore

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
        return visibleText.contains {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .contains(needle)
        }
    }
}

public struct SeratoLibraryRow: Identifiable, Hashable, Sendable {
    public var id: Int { index }
    public var index: Int
    public var fields: [String]

    public init(index: Int, fields: [String]) {
        self.index = index
        self.fields = fields
    }

    public var displayText: String { fields.joined(separator: " • ") }
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
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    public func activateSerato() throws {
        guard let application = application(for: .serato) else {
            throw SeratoAccessibilityError.seratoNotRunning
        }
        guard application.activate(options: [.activateAllWindows]) else {
            throw SeratoAccessibilityError.activationFailed
        }
    }

    public func activate(_ software: DJSoftware? = nil) -> Bool {
        application(for: software ?? DJSoftwareSelectionStore.current)?
            .activate(options: [.activateAllWindows]) == true
    }

    public func observe(
        software: DJSoftware? = nil,
        maxDepth: Int = 5,
        maximumStrings: Int = 250
    ) -> SeratoWindowObservation {
        let resolvedSoftware = software ?? DJSoftwareSelectionStore.current
        guard let application = application(for: resolvedSoftware) else {
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
        let window = preferredWindow(for: appElement)
        var strings: [String] = []
        if let window {
            collectStrings(
                from: window,
                depth: 0,
                maxDepth: max(1, maxDepth),
                maximumStrings: max(1, maximumStrings),
                into: &strings
            )
        }
        return SeratoWindowObservation(
            isRunning: true,
            processIdentifier: application.processIdentifier,
            windowTitle: window.flatMap { stringAttribute($0, attribute: kAXTitleAttribute) },
            visibleText: normalizedStrings(strings),
            accessibilityGranted: true
        )
    }

    public func libraryRows(
        software: DJSoftware? = nil,
        maxRows: Int = 500
    ) -> [SeratoLibraryRow] {
        let resolvedSoftware = software ?? DJSoftwareSelectionStore.current
        guard AXIsProcessTrusted(), let application = application(for: resolvedSoftware) else { return [] }
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let window = preferredWindow(for: appElement) else { return [] }

        var rowElements: [AXUIElement] = []
        collectRows(from: window, depth: 0, maxDepth: 12, maxRows: max(1, maxRows), into: &rowElements)
        return rowElements.enumerated().compactMap { index, element in
            var strings: [String] = []
            collectStrings(from: element, depth: 0, maxDepth: 5, maximumStrings: 30, into: &strings)
            let fields = normalizedStrings(strings)
            return fields.isEmpty ? nil : SeratoLibraryRow(index: index, fields: fields)
        }
    }

    private func application(for software: DJSoftware) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { application in
            let name = application.localizedName?.lowercased() ?? ""
            let bundle = application.bundleIdentifier?.lowercased() ?? ""
            switch software {
            case .serato:
                return name.contains("serato dj pro") || name == "serato dj" || bundle.contains("serato")
            case .djay:
                return DjayApplicationMatcher.matches(name: application.localizedName) || bundle.contains("algoriddim.djay")
            case .rekordbox:
                return RekordboxApplicationMatcher.matches(
                    name: application.localizedName,
                    bundleIdentifier: application.bundleIdentifier
                )
            }
        }
    }

    private func preferredWindow(for appElement: AXUIElement) -> AXUIElement? {
        elementAttribute(appElement, attribute: kAXFocusedWindowAttribute) ??
            elementAttribute(appElement, attribute: kAXMainWindowAttribute)
    }

    private func collectRows(
        from element: AXUIElement,
        depth: Int,
        maxDepth: Int,
        maxRows: Int,
        into rows: inout [AXUIElement]
    ) {
        guard depth <= maxDepth, rows.count < maxRows else { return }
        if stringAttribute(element, attribute: kAXRoleAttribute) == kAXRowRole as String {
            rows.append(element)
        }
        guard rows.count < maxRows,
              let children = arrayAttribute(element, attribute: kAXChildrenAttribute) else { return }
        for child in children {
            collectRows(from: child, depth: depth + 1, maxDepth: maxDepth, maxRows: maxRows, into: &rows)
            if rows.count >= maxRows { return }
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
            }
            if strings.count >= maximumStrings { return }
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

    private func normalizedStrings(_ strings: [String]) -> [String] {
        var seen = Set<String>()
        return strings.compactMap {
            let cleaned = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return !cleaned.isEmpty && seen.insert(cleaned).inserted ? cleaned : nil
        }
    }

    private func elementAttribute(_ element: AXUIElement, attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
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
