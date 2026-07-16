import Testing
@testable import MixPilotCore

@Test("djay Automix analyzer recognizes a container, queue rows and controls")
func recognizesAutomixEvidence() {
    let nodes = [
        DjayAccessibilityNode(
            path: "window/group[0]",
            depth: 1,
            role: "AXGroup",
            title: "Automix Queue",
            context: ["djay Pro"]
        ),
        DjayAccessibilityNode(
            path: "window/group[0]/row[0]",
            depth: 2,
            role: "AXRow",
            title: "Water",
            value: "Tyla",
            selected: false,
            context: ["Automix Queue"]
        ),
        DjayAccessibilityNode(
            path: "window/group[0]/button[0]",
            depth: 2,
            role: "AXButton",
            title: "Start Automix",
            actions: ["AXPress"],
            context: ["Automix Queue"]
        ),
        DjayAccessibilityNode(
            path: "window/library/button[4]",
            depth: 3,
            role: "AXButton",
            title: "Add to Automix",
            actions: ["AXPress"],
            context: ["Spotify Library"]
        ),
    ]

    let report = DjayAutomixQueueAnalyzer().analyze(nodes: nodes)

    #expect(report.automixContainers.count == 1)
    #expect(report.queueRows.count == 1)
    #expect(report.controls.count == 2)
    #expect(report.confidence >= 80)
    #expect(report.hasReadOnlyAutomixEvidence)
    #expect(report.validationStatus == .requiresDeviceValidation)
}

@Test("djay Automix analyzer does not claim readiness from unrelated controls")
func rejectsUnrelatedAccessibilityTree() {
    let nodes = [
        DjayAccessibilityNode(
            path: "window/button[0]",
            depth: 1,
            role: "AXButton",
            title: "Settings",
            actions: ["AXPress"]
        ),
        DjayAccessibilityNode(
            path: "window/table[0]/row[0]",
            depth: 2,
            role: "AXRow",
            title: "Track title",
            value: "Artist"
        ),
    ]

    let report = DjayAutomixQueueAnalyzer().analyze(nodes: nodes)

    #expect(report.candidates.isEmpty)
    #expect(report.confidence == 0)
    #expect(!report.hasReadOnlyAutomixEvidence)
    #expect(report.summary.contains("Aucun élément Automix"))
}

@Test("queue rows inherit Automix context from their ancestors")
func usesAncestorContext() {
    let node = DjayAccessibilityNode(
        path: "window/group[2]/row[3]",
        depth: 3,
        role: "AXRow",
        title: "One Track Mind",
        value: "Naïka",
        context: ["Automix", "Up Next"]
    )

    let report = DjayAutomixQueueAnalyzer().analyze(nodes: [node])

    #expect(report.queueRows.count == 1)
    #expect(report.queueRows[0].label == "One Track Mind")
    #expect(report.validationStatus == .requiresDeviceValidation)
}
