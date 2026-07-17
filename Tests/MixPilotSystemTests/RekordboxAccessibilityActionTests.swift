#if os(macOS)
import ApplicationServices
import Testing
@testable import MixPilotSystem

@Test("Only the guarded Accessibility actions are allowed")
func rekordboxAllowedAccessibilityActions() {
    #expect(RekordboxActionSafetyPolicy.isAllowed(action: kAXPressAction as String))
    #expect(RekordboxActionSafetyPolicy.isAllowed(action: kAXConfirmAction as String))
    #expect(RekordboxActionSafetyPolicy.isAllowed(action: kAXIncrementAction as String))
    #expect(RekordboxActionSafetyPolicy.isAllowed(action: kAXDecrementAction as String))
    #expect(RekordboxActionSafetyPolicy.isAllowed(action: kAXShowMenuAction as String))
    #expect(!RekordboxActionSafetyPolicy.isAllowed(action: "AXSetValue"))
    #expect(!RekordboxActionSafetyPolicy.isAllowed(action: "AXDelete"))
}

@Test("Potentially destructive labels require confirmation in several languages")
func rekordboxDestructiveLabels() {
    #expect(RekordboxActionSafetyPolicy.isPotentiallyDestructive("Delete playlist"))
    #expect(RekordboxActionSafetyPolicy.isPotentiallyDestructive("Supprimer de la collection"))
    #expect(RekordboxActionSafetyPolicy.isPotentiallyDestructive("Borrar lista"))
    #expect(RekordboxActionSafetyPolicy.isPotentiallyDestructive("Aus Playlist entfernen"))
    #expect(!RekordboxActionSafetyPolicy.isPotentiallyDestructive("Create playlist"))
    #expect(!RekordboxActionSafetyPolicy.isPotentiallyDestructive("Load Deck 1"))
}

@Test("Actionable elements expose a stable display label")
func rekordboxActionableElementDisplayName() {
    let element = RekordboxActionableElement(
        fingerprint: "button|load",
        path: [1, 2],
        role: "AXButton",
        subrole: nil,
        title: nil,
        value: nil,
        elementDescription: "Load Deck 1",
        help: nil,
        actions: [kAXPressAction as String]
    )
    #expect(element.displayName == "Load Deck 1")
    #expect(!element.isPotentiallyDestructive)
}
#endif
