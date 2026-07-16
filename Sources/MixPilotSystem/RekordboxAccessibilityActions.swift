#if os(macOS)
import AppKit
@preconcurrency import ApplicationServices
import Foundation
import MixPilotCore

public struct RekordboxActionableElement: Identifiable, Codable, Hashable, Sendable {
    public var id: String { fingerprint }
    public var fingerprint: String
    public var path: [Int]
    public var role: String
    public var subrole: String?
    public var title: String?
    public var value: String?
    public var elementDescription: String?
    public var help: String?
    public var actions: [String]

    public init(
        fingerprint: String,
        path: [Int],
        role: String,
        subrole: String?,
        title: String?,
        value: String?,
        elementDescription: String?,
        help: String?,
        actions: [String]
    ) {
        self.fingerprint = fingerprint
        self.path = path
        self.role = role
        self.subrole = subrole
        self.title = title
        self.value = value
        self.elementDescription = elementDescription
        self.help = help
        self.actions = actions
    }

    public var displayName: String {
        [title, elementDescription, value, help]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? role
    }

    public var isPotentiallyDestructive: Bool {
        RekordboxActionSafetyPolicy.isPotentiallyDestructive(
            [title, elementDescription, value, help].compactMap { $0 }.joined(separator: " ")
        )
    }
}

public enum RekordboxAccessibilityActionError: Error, LocalizedError {
    case wrongBackend
    case rekordboxNotRunning
    case accessibilityNotGranted
    case elementNoLongerAvailable
    case unsupportedAction(String)
    case confirmationRequired
    case actionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .wrongBackend:
            "Sélectionne rekordbox comme logiciel DJ avant d’envoyer une action."
        case .rekordboxNotRunning:
            "rekordbox n’est pas lancé."
        case .accessibilityNotGranted:
            "La permission Accessibilité est nécessaire pour agir sur rekordbox."
        case .elementNoLongerAvailable:
            "Le contrôle rekordbox a changé ou n’est plus visible. Relance l’inspection."
        case .unsupportedAction(let action):
            "L’action Accessibilité \(action) n’est pas autorisée par MixPilot."
        case .confirmationRequired:
            "Cette action peut modifier ou supprimer des données. Une confirmation explicite est requise."
        case .actionFailed(let action):
            "rekordbox a refusé l’action \(action)."
        }
    }
}

public enum RekordboxActionSafetyPolicy {
    public static let allowedActions: Set<String> = [
        kAXPressAction as String,
        kAXConfirmAction as String,
        kAXIncrementAction as String,
        kAXDecrementAction as String,
        kAXShowMenuAction as String,
    ]

    private static let destructiveTokens = [
        "delete", "remove", "erase", "clear", "trash",
        "supprimer", "retirer", "effacer", "vider", "corbeille",
        "löschen", "entfernen", "eliminar", "borrar",
    ]

    public static func isAllowed(action: String) -> Bool {
        allowedActions.contains(action)
    }

    public static func isPotentiallyDestructive(_ label: String) -> Bool {
        let normalized = label
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        return destructiveTokens.contains { normalized.contains($0) }
    }
}

@MainActor
public final class RekordboxAccessibilityActionBridge {
    public init() {}

    public func inspect(maxDepth: Int = 12, maximumElements: Int = 700) throws -> [RekordboxActionableElement] {
        guard DJSoftwareSelectionStore.current == .rekordbox else {
            throw RekordboxAccessibilityActionError.wrongBackend
        }
        guard AXIsProcessTrusted() else {
            throw RekordboxAccessibilityActionError.accessibilityNotGranted
        }
        guard let application = rekordboxApplication() else {
            throw RekordboxAccessibilityActionError.rekordboxNotRunning
        }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let window = preferredWindow(for: appElement) else { return [] }
        var output: [RekordboxActionableElement] = []
        collectActionableElements(
            from: window,
            path: [],
            depth: 0,
            maxDepth: max(1, maxDepth),
            maximumElements: max(1, maximumElements),
            output: &output
        )
        return output
    }

    public func perform(
        element descriptor: RekordboxActionableElement,
        action: String,
        allowPotentiallyDestructive: Bool = false
    ) throws {
        guard DJSoftwareSelectionStore.current == .rekordbox else {
            throw RekordboxAccessibilityActionError.wrongBackend
        }
        guard AXIsProcessTrusted() else {
            throw RekordboxAccessibilityActionError.accessibilityNotGranted
        }
        guard RekordboxActionSafetyPolicy.isAllowed(action: action), descriptor.actions.contains(action) else {
            throw RekordboxAccessibilityActionError.unsupportedAction(action)
        }
        if descriptor.isPotentiallyDestructive && !allowPotentiallyDestructive {
            throw RekordboxAccessibilityActionError.confirmationRequired
        }
        guard let application = rekordboxApplication() else {
            throw RekordboxAccessibilityActionError.rekordboxNotRunning
        }
        _ = application.activate(options: [.activateAllWindows])

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        guard let window = preferredWindow(for: appElement),
              let element = resolve(path: descriptor.path, from: window),
              fingerprint(for: element, path: descriptor.path) == descriptor.fingerprint else {
            throw RekordboxAccessibilityActionError.elementNoLongerAvailable
        }
        guard AXUIElementPerformAction(element, action as CFString) == .success else {
            throw RekordboxAccessibilityActionError.actionFailed(action)
        }
    }

    private func collectActionableElements(
        from element: AXUIElement,
        path: [Int],
        depth: Int,
        maxDepth: Int,
        maximumElements: Int,
        output: inout [RekordboxActionableElement]
    ) {
        guard depth <= maxDepth, output.count < maximumElements else { return }
        let actions = actionNames(for: element).filter(RekordboxActionSafetyPolicy.isAllowed)
        if !actions.isEmpty {
            output.append(RekordboxActionableElement(
                fingerprint: fingerprint(for: element, path: path),
                path: path,
                role: stringAttribute(element, attribute: kAXRoleAttribute) ?? "AXUnknown",
                subrole: stringAttribute(element, attribute: kAXSubroleAttribute),
                title: stringAttribute(element, attribute: kAXTitleAttribute),
                value: stringAttribute(element, attribute: kAXValueAttribute),
                elementDescription: stringAttribute(element, attribute: kAXDescriptionAttribute),
                help: stringAttribute(element, attribute: kAXHelpAttribute),
                actions: actions.sorted()
            ))
        }

        guard output.count < maximumElements,
              let children = arrayAttribute(element, attribute: kAXChildrenAttribute) else { return }
        for (index, child) in children.enumerated() {
            collectActionableElements(
                from: child,
                path: path + [index],
                depth: depth + 1,
                maxDepth: maxDepth,
                maximumElements: maximumElements,
                output: &output
            )
            if output.count >= maximumElements { return }
        }
    }

    private func resolve(path: [Int], from root: AXUIElement) -> AXUIElement? {
        var current = root
        for index in path {
            guard let children = arrayAttribute(current, attribute: kAXChildrenAttribute),
                  children.indices.contains(index) else { return nil }
            current = children[index]
        }
        return current
    }

    private func fingerprint(for element: AXUIElement, path: [Int]) -> String {
        let parts = [
            stringAttribute(element, attribute: kAXRoleAttribute) ?? "",
            stringAttribute(element, attribute: kAXSubroleAttribute) ?? "",
            stringAttribute(element, attribute: kAXIdentifierAttribute) ?? "",
            stringAttribute(element, attribute: kAXTitleAttribute) ?? "",
            stringAttribute(element, attribute: kAXDescriptionAttribute) ?? "",
            path.map(String.init).joined(separator: "."),
        ]
        return parts.joined(separator: "|")
    }

    private func rekordboxApplication() -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            RekordboxApplicationMatcher.matches(
                name: $0.localizedName,
                bundleIdentifier: $0.bundleIdentifier
            )
        }
    }

    private func preferredWindow(for appElement: AXUIElement) -> AXUIElement? {
        elementAttribute(appElement, attribute: kAXFocusedWindowAttribute) ??
            elementAttribute(appElement, attribute: kAXMainWindowAttribute)
    }

    private func actionNames(for element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
        return names as? [String] ?? []
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
