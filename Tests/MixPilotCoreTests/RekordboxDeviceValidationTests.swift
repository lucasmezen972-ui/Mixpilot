import Foundation
import Testing
@testable import MixPilotCore

struct RekordboxDeviceValidationTests {
    @Test func semanticVersionsCompareNumerically() {
        #expect(RekordboxSemanticVersion("7.2.3")! > RekordboxSemanticVersion("7.1.9")!)
        #expect(RekordboxSemanticVersion("6.7.4 build 123") == RekordboxSemanticVersion(major: 6, minor: 7, patch: 4))
        #expect(RekordboxSemanticVersion("7.0") == RekordboxSemanticVersion(major: 7, minor: 0, patch: 0))
    }

    @Test func planIncludesAdvancedCommandsAndStableSignature() throws {
        let profile = MIDIMappingProfile.developmentDefault
        let date = Date(timeIntervalSince1970: 1_000)
        let builder = RekordboxDeviceValidationPlanBuilder()
        let first = try builder.make(profile: profile, installedVersion: "7.2.3", generatedAt: date)
        let second = try builder.make(profile: profile, installedVersion: "7.2.3", generatedAt: date.addingTimeInterval(50))

        #expect(first.target.presetSignature == second.target.presetSignature)
        #expect(first.commands.contains { $0.action == .browserFocus && $0.csvName == "SwitchActiveWindow" })
        #expect(first.commands.contains { $0.action == .filterA && $0.csvName == "CFXParameterCH1" })
        #expect(first.commands.contains { $0.action == .filterB && $0.csvName == "CFXParameterCH2" })
        #expect(first.commands.allSatisfy { !$0.midiHex.isEmpty })
    }

    @Test func signatureChangesWithVersionOrMapping() throws {
        var profile = MIDIMappingProfile.developmentDefault
        let builder = RekordboxDeviceValidationPlanBuilder()
        let first = try builder.make(profile: profile, installedVersion: "7.2.3")
        let versionChanged = try builder.make(profile: profile, installedVersion: "7.2.4")
        profile[.playA] = MIDIMessageMapping(kind: .note, number: 99, isMomentary: true)
        let mappingChanged = try builder.make(profile: profile, installedVersion: "7.2.3")

        #expect(first.target.presetSignature != versionChanged.target.presetSignature)
        #expect(first.target.presetSignature != mappingChanged.target.presetSignature)
    }

    @Test func oldVersionsMarkNewerCommandsUnavailable() throws {
        let plan = try RekordboxDeviceValidationPlanBuilder().make(
            profile: .developmentDefault,
            installedVersion: "6.6.3"
        )
        #expect(plan.commands.first { $0.action == .browserFocus }?.isAvailableForInstalledVersion == true)
        #expect(plan.commands.first { $0.action == .filterA }?.isAvailableForInstalledVersion == false)
        #expect(plan.commands.first { $0.action == .filterB }?.isAvailableForInstalledVersion == false)
    }

    @Test func reportTracksCriticalReadiness() throws {
        let plan = try RekordboxDeviceValidationPlanBuilder().make(
            profile: .developmentDefault,
            installedVersion: "7.2.3"
        )
        var report = RekordboxDeviceValidationReport(plan: plan)
        #expect(report.completionRatio(for: plan) == 0)
        #expect(report.criticalCommandsPassed(in: plan) == false)

        for command in plan.commands where command.isCritical && command.isAvailableForInstalledVersion {
            report.record(.passed, for: command.id)
        }

        #expect(report.criticalCommandsPassed(in: plan))
        #expect(report.passedCount > 0)
    }

    @Test func duplicateCommandIdentifiersDoNotTrap() throws {
        var plan = try RekordboxDeviceValidationPlanBuilder().make(
            profile: .developmentDefault,
            installedVersion: "7.2.3"
        )
        let first = try #require(plan.commands.first)
        plan.commands.append(first)

        let report = RekordboxDeviceValidationReport(plan: plan)

        #expect(report.records.count == Set(plan.commands.map(\.id)).count)
        #expect(report.records[first.id]?.commandID == first.id)
    }

    @Test func storeRoundTripsAtomically() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MixPilotValidationTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let plan = try RekordboxDeviceValidationPlanBuilder().make(
            profile: .developmentDefault,
            installedVersion: "7.2.3"
        )
        var report = RekordboxDeviceValidationReport(plan: plan)
        let first = try #require(plan.commands.first)
        report.record(.passed, for: first.id, note: "Réaction confirmée")

        let store = RekordboxDeviceValidationStore(directory: directory)
        let url = try store.save(report)
        let loadedOptional = try store.load(for: plan.target)
        let loaded = try #require(loadedOptional)

        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(loaded.target == report.target)
        #expect(loaded[first.id].outcome == .passed)
        #expect(loaded[first.id].note == "Réaction confirmée")
    }
}
