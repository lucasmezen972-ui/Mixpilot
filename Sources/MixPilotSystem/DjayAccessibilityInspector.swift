#if os(macOS)
import AppKit
@preconcurrency import ApplicationServices
import Foundation
import MixPilotCore

public struct DjayAccessibilityCapture: Codable, Hashable, Sendable {
    public var capturedAt: Date
    public var isRunning: Bool
    public var processIdentifier: Int32?
    public var applicationName: String?
    public var bundleIdentifier: String?
    public var accessibilityGranted: Bool
    public var windowTitle: String?
    public var nodes: [DjayAccessibilityNode]
    public var truncated: Bool
    public var failureReason: String?

    public init(
        capturedAt: Date = Date(),
        isRunning: Bool,
        processIdentifier: Int32?,
        applicationName: String?,
        bundleIdentifier: String?,
        accessibilityGranted: Bool,
        windowTitle: String?,
        nodes: [DjayAccessibilityNode],
        truncated: Bool,
        failureReason: String?
    ) {
        self.capturedAt = capturedAt
        self.isRunning = isRunning
        self.processIdentifier = processIdentifier
        self.applicationName = applicationName
        self.bundleIdentifier = bundleIdentifier
        self.accessibilityGranted = accessibilityGranted
        self.windowTitle = windowTitle
        self.nodes = nodes
        self.truncated = truncated
        self.failureReason = failureReason
    }
}

@MainActor
public final class DjayAccessibilityInspector {
    public init() {}

    public func capture(maxDepth: Int = 14, maximumElements: Int = 2_000) -> DjayAccessibilityCapture {
        guard let application = runningApplication() else {
            return DjayAccessibilityCapture(
                isRunning: false,
                processIdentifier: nil,
                applicationName: nil,
                bundleIdentifier: nil,
                accessibilityGranted: AXIsProcessTrusted(),
                windowTitle: nil,
                nodes: [],
                truncated: false,
                failureReason: "djay Pro n’est pas lancé."
            )
        }

        guard AXIsProcessTrusted() else {
            return DjayAccessibilityCapture(
                isRunning: true,
                processIdentifier: application.processIdentifier,
                applicationName: application.localizedName,
                bundleIdentifier: application.bundleIdentifier,
                accessibilityGranted: false,
                windowTitle: nil,
                nodes: [],
                truncated: false,
                failureReason: "La permission Accessibilité n’est pas accordée à MixPilot."
            )
        }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let window = preferredWindow(for: appElement) else {
            return DjayAccessibilityCapture(
                isRunning: true,
                processIdentifier: application.processIdentifier,
                applicationName: application.localizedName,
                bundleIdentifier: application.bundleIdentifier,
                accessibilityGranted: true,
                windowTitle: nil,
                nodes: [],
                truncated: false,
                failureReason: "Aucune fenêtre djay accessible n’a été trouvée."
            )
        }

        let limit = max(1, maximumElements)
        var nodes: [DjayAccessibilityNode] = []
        collect(
            element: window,
            path: "window[0]",
            depth: 0,
            maxDepth: max(1, maxDepth),
            maximumElements: limit,
            context: [],
            into: &nodes
        )

        return DjayAccessibilityCapture(
            isRunning: true,
            processIdentifier: application.processIdentifier,
            applicationName: application.localizedName,
            bundleIdentifier: application.bundleIdentifier,
            accessibilityGranted: true,
            windowTitle: stringAttribute(window, attribute: kAXTitleAttribute),
            nodes: nodes,
            truncated: nodes.count >= limit,
            failureReason: nodes.isEmpty ? "La fenêtre est visible, mais aucun élément accessible n’a été exposé." : nil
        )
    }

    private func runningApplication() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { application in
            DjayApplicationMatcher.matches(name: application.localizedName) ||
                (application.bundleIdentifier?.lowercased().contains("algoriddim.djay") == true)
        }
    }

    private func preferredWindow(for appElement: AXUIElement) -> AXUIElement? {
        elementAttribute(appElement, attribute: kAXFocusedWindowAttribute) ??
            elementAttribute(appElement, attribute: kAXMainWindowAttribute)
    }

    private func collect(
        element: AXUIElement,
        path: String,
        depth: Int,
        maxDepth: Int,
        maximumElements: Int,
        context: [String],
        into nodes: inout [DjayAccessibilityNode]
    ) {
        guard depth <= maxDepth, nodes.count < maximumElements else { return }

        let role = stringAttribute(element, attribute: kAXRoleAttribute) ?? "AXUnknown"
        let title = stringAttribute(element, attribute: kAXTitleAttribute)
        let value = stringAttribute(element, attribute: kAXValueAttribute)
        let description = stringAttribute(element, attribute: kAXDescriptionAttribute)
        let help = stringAttribute(element, attribute: kAXHelpAttribute)
        let identifier = stringAttribute(element, attribute: kAXIdentifierAttribute)
        let localLabels = normalizedStrings([title, value, description, help, identifier].compactMap { $0 })
        let compactContext = Array(context.suffix(8))

        nodes.append(DjayAccessibilityNode(
            path: path,
            depth: depth,
            role: role,
            subrole: stringAttribute(element, attribute: kAXSubroleAttribute),
            identifier: identifier,
            title: title,
            value: value,
            nodeDescription: description,
            help: help,
            enabled: boolAttribute(element, attribute: kAXEnabledAttribute),
            focused: boolAttribute(element, attribute: kAXFocusedAttribute),
            selected: boolAttribute(element, attribute: kAXSelectedAttribute),
            actions: actionNames(for: element),
            context: compactContext
        ))

        guard nodes.count < maximumElements,
              let children = arrayAttribute(element, attribute: kAXChildrenAttribute) else { return }

        let nextContext = Array((context + localLabels).suffix(8))
        for (index, child) in children.enumerated() {
            guard nodes.count < maximumElements else { return }
            let childRole = stringAttribute(child, attribute: kAXRoleAttribute) ?? "AXUnknown"
            collect(
                element: child,
                path: "\(path)/\(childRole)[\(index)]",
                depth: depth + 1,
                maxDepth: maxDepth,
                maximumElements: maximumElements,
                context: nextContext,
                into: &nodes
            )
        }
    }

    private func actionNames(for element: AXUIElement) -> [String] {
        var value: CFArray?
        guard AXUIElementCopyActionNames(element, &value) == .success,
              let value else { return [] }
        return (value as? [String] ?? []).sorted()
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
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value else { return nil }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    private func boolAttribute(_ element: AXUIElement, attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value else { return nil }
        if let boolean = value as? Bool { return boolean }
        if let number = value as? NSNumber { return number.boolValue }
        return nil
    }

    private func arrayAttribute(_ element: AXUIElement, attribute: String) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? [AXUIElement]
    }

    private func normalizedStrings(_ strings: [String]) -> [String] {
        var seen = Set<String>()
        return strings.compactMap { value in
            let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty, seen.insert(cleaned).inserted else { return nil }
            return cleaned
        }
    }
}
#endif
