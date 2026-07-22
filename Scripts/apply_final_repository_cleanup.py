#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(relative_path: str, old: str, new: str) -> None:
    path = ROOT / relative_path
    source = path.read_text(encoding="utf-8")
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"{relative_path}: expected exactly one match, found {count}")
    path.write_text(source.replace(old, new, 1), encoding="utf-8")


replace_once(
    "Sources/MixPilotApp/SpotifyLibraryCoordinator.swift",
    "private final class SpotifyAuthenticationCallbackRelay: @unchecked Sendable {",
    """// SAFETY: The immutable session identifier is shared across threads, while the
// weak coordinator is only copied by the system callback. All coordinator state
// remains isolated to the MainActor and is accessed only inside the scheduled Task.
private final class SpotifyAuthenticationCallbackRelay: @unchecked Sendable {""",
)

replace_once(
    "Sources/MixPilotCore/RekordboxDeviceValidation.swift",
    """        self.records = Dictionary(uniqueKeysWithValues: plan.commands.map {
            ($0.id, RekordboxDeviceValidationRecord(commandID: $0.id))
        })""",
    """        self.records = plan.commands.reduce(into: [:]) { records, command in
            records[command.id] = RekordboxDeviceValidationRecord(commandID: command.id)
        }""",
)

# The explicit identity helper and its workflow remove themselves in the candidate
# commit. These older files are also one-shot scaffolding and must not reach main.
obsolete_paths = (
    ".github/final-release-hardening-pr-trigger.txt",
    ".github/final-release-hardening-trigger-branch.txt",
    ".github/final-release-hardening-trigger.txt",
    ".github/placeholder-final.txt",
    ".github/unused-placeholder.txt",
    ".github/workflows/final-release-hardening-debug.yml",
    ".github/workflows/final-release-hardening-pr.yml",
    "Scripts/apply_final_release_hardening.py",
)
for relative_path in obsolete_paths:
    path = ROOT / relative_path
    if not path.exists():
        raise SystemExit(f"Expected obsolete one-shot file is missing: {relative_path}")
    path.unlink()
