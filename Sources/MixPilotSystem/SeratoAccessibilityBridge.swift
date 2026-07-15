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

public struct SeratoLibraryRow: Identifiable, Hashable, Sendable {
    public var id: Int { index }
    public var index: Int
    public var fields: [String]

    public init(index: Int, fields: [String]) {
        self.index = index
        self.fields = fields
    }

    public var displayText: String {
        fields.joined(separator: " • ")
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
        let mainWindow = preferredWindow(for: appElement)
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

        let normalized = normalizedStrings(strings)
        return SeratoWindowObservation(
            isRunning: true,
            processIdentifier: application.processIdentifier,
            windowTitle: title,
            visibleText: normalized,
            accessibilityGranted: true
        )
    }

    public func libraryRows(maxRows: Int = 500) -> [SeratoLibraryRow] {
        guard AXIsProcessTrusted(), let application = seratoApplication() else { return [] }
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let window = preferredWindow(for: appElement) else { return [] }

        var rowElements: [AXUIElement] = []
        collectRows(
            from: window,
            depth: 0,
            maxDepth: 12,
            maxRows: max(1, maxRows),
            into: &rowElements
        )

        return rowElements.enumerated().compactMap { index, element in
            var strings: [String] = []
            collectStrings(
                from: element,
                depth: 0,
                maxDepth: 5,
                maximumStrings: 30,
                into: &strings
            )
            let fields = normalizedStrings(strings)
            guard !fields.isEmpty else { return nil }
            return SeratoLibraryRow(index: index, fields: fields)
        }
    }

    private func seratoApplication() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { application in
            let name = application.localizedName?.lowercased() ?? ""
            let bundle = application.bundleIdentifier?.lowercased() ?? ""
            return name.contains("serato dj pro") || name == "serato dj" || bundle.contains("serato")
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
            if rows.count >= maxRows { return }
        }
        guard let children = arrayAttribute(element, attribute: kAXChildrenAttribute) else { return }
        for child in children {
            collectRows(
                from: child,
                depth: depth + 1,
                maxDepth: maxDepth,
                maxRows: maxRows,
                into: &rows
            )
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

    private func normalizedStrings(_ strings: [String]) -> [String] {
        var seen = Set<String>()
        return strings.compactMap { value in
            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty, seen.insert(cleaned).inserted else { return nil }
            return cleaned
        }
    }

    private func elementAttribute(_ element: AXUIElement, attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeBitCast(value, to: AXUIElement.self)
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
