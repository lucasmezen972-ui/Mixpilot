#!/usr/bin/env python3
"""Apply the final audited release hardening patch exactly once."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, content: str) -> None:
    (ROOT / path).write_text(content, encoding="utf-8")


def replace_once(path: str, old: str, new: str) -> None:
    content = read(path)
    count = content.count(old)
    if count != 1:
        raise SystemExit(f"Expected exactly one match in {path}, found {count}: {old[:100]!r}")
    write(path, content.replace(old, new, 1))


def replace_all(path: str, old: str, new: str, expected: int = 1) -> None:
    content = read(path)
    count = content.count(old)
    if count != expected:
        raise SystemExit(f"Expected {expected} matches in {path}, found {count}: {old!r}")
    write(path, content.replace(old, new))


def harden_counter_audit() -> None:
    path = "Scripts/architecture_counter_audit.py"
    replace_once(
        path,
        'APPLE_XML_DTD = "http://www.apple.com/DTDs/PropertyList-1.0.dtd"\n\n\n@dataclass',
        'APPLE_XML_DTD = "http://www.apple.com/DTDs/PropertyList-1.0.dtd"\nCHECKS_EXECUTED = 0\n\n\ndef mark_check(count: int = 1) -> None:\n    global CHECKS_EXECUTED\n    CHECKS_EXECUTED += count\n\n\n@dataclass',
    )
    replace_once(
        path,
        'def require_file(findings: list[Finding], path: str) -> bool:\n    if (ROOT / path).is_file():',
        'def require_file(findings: list[Finding], path: str) -> bool:\n    mark_check()\n    if (ROOT / path).is_file():',
    )
    replace_once(
        path,
        ') -> None:\n    text = read(path)\n    if token not in text:',
        ') -> None:\n    mark_check()\n    text = read(path)\n    if token not in text:',
    )
    replace_once(
        path,
        'def forbid_contains(\n    findings: list[Finding], path: str, token: str, rule: str, message: str\n) -> None:\n    text = read(path)',
        'def forbid_contains(\n    findings: list[Finding], path: str, token: str, rule: str, message: str\n) -> None:\n    mark_check()\n    text = read(path)',
    )
    replace_once(
        path,
        '    if not require_file(findings, path):\n        return\n    try:\n        payload = plistlib.loads((ROOT / path).read_bytes())',
        '    if not require_file(findings, path):\n        return\n    mark_check()\n    try:\n        payload = plistlib.loads((ROOT / path).read_bytes())',
    )
    replace_once(
        path,
        '    if "CA92.1" not in reasons:',
        '    mark_check()\n    if "CA92.1" not in reasons:',
    )
    replace_once(
        path,
        '        rel = file_path.relative_to(ROOT).as_posix()\n        try:\n            text = file_path.read_text(encoding="utf-8")',
        '        rel = file_path.relative_to(ROOT).as_posix()\n        mark_check(2)\n        try:\n            text = file_path.read_text(encoding="utf-8")',
    )
    replace_once(
        path,
        '        rel = file_path.relative_to(ROOT).as_posix()\n        if rel in SELF_AUDIT_PATHS:',
        '        rel = file_path.relative_to(ROOT).as_posix()\n        mark_check(len(secret_patterns))\n        if rel in SELF_AUDIT_PATHS:',
    )
    replace_once(
        path,
        '        if rel.startswith(TEST_PREFIXES):\n            continue\n        transport_text = text.replace(APPLE_XML_DTD, "")',
        '        if rel.startswith(TEST_PREFIXES):\n            continue\n        mark_check()\n        transport_text = text.replace(APPLE_XML_DTD, "")',
    )
    replace_once(
        path,
        'def check_supabase_security(findings: list[Finding]) -> None:\n    migration_root = ROOT / "supabase" / "migrations"',
        'def check_supabase_security(findings: list[Finding]) -> None:\n    mark_check()\n    migration_root = ROOT / "supabase" / "migrations"',
    )
    replace_once(
        path,
        '    for file_path in migration_root.glob("*.sql"):\n        text = file_path.read_text(encoding="utf-8")',
        '    for file_path in migration_root.glob("*.sql"):\n        mark_check()\n        text = file_path.read_text(encoding="utf-8")',
    )
    replace_once(
        path,
        '    text = read(path)\n    if ".unsafeFlags(" in text:',
        '    text = read(path)\n    mark_check()\n    if ".unsafeFlags(" in text:',
    )
    new_checks = '''\n\ndef check_crash_prone_collections(findings: list[Finding]) -> None:\n    token = "Dictionary(uniqueKeysWithValues:"\n    for file_path in iter_swift_sources():\n        mark_check()\n        rel = file_path.relative_to(ROOT).as_posix()\n        text = file_path.read_text(encoding="utf-8")\n        offset = text.find(token)\n        if offset >= 0:\n            findings.append(\n                Finding(\n                    "error",\n                    "dictionary-duplicate-key-trap",\n                    rel,\n                    line_for_offset(text, offset),\n                    "Production dictionaries built from external or generated arrays must tolerate duplicate keys.",\n                    token,\n                )\n            )\n\n\ndef check_release_hygiene_contract(findings: list[Finding]) -> None:\n    hygiene = "Scripts/verify_release_hygiene.sh"\n    build = "Scripts/build_release.sh"\n    package = "Scripts/package_dmg.sh"\n    workflow = ".github/workflows/final-pr-validation.yml"\n    require_file(findings, hygiene)\n    require_contains(\n        findings, build, "/usr/bin/strip -S", "release-binary-not-stripped",\n        "The release executable must be stripped before signing to remove build-machine paths."\n    )\n    require_contains(\n        findings, package, "--noextattr", "dmg-metadata-not-sanitized",\n        "DMG staging must omit extended attributes and resource metadata."\n    )\n    for path in (package, workflow):\n        require_contains(\n            findings, path, "verify_release_hygiene.sh", "release-hygiene-gate-missing",\n            "Packaging and final validation must inspect the actual app and DMG payload."\n        )\n\n'''
    replace_once(path, '\n\ndef write_reports(findings: list[Finding], output_dir: Path) -> None:', new_checks + 'def write_reports(findings: list[Finding], output_dir: Path) -> None:')
    replace_once(path, '            "checks": len(findings),', '            "checks": CHECKS_EXECUTED,')
    replace_once(
        path,
        '        f"- Warnings: **{len(warnings)}**",\n        "",',
        '        f"- Warnings: **{len(warnings)}**",\n        f"- Checks executed: **{CHECKS_EXECUTED}**",\n        "",',
    )
    replace_once(
        path,
        '    check_supabase_security(findings)\n    check_package_contract(findings)\n\n    write_reports(findings, ROOT / args.output_dir)',
        '    check_supabase_security(findings)\n    check_package_contract(findings)\n    check_crash_prone_collections(findings)\n    check_release_hygiene_contract(findings)\n\n    if CHECKS_EXECUTED < 50:\n        add(\n            findings,\n            "error",\n            "counter-audit-insufficient-coverage",\n            "Scripts/architecture_counter_audit.py",\n            f"Architecture counter-audit executed only {CHECKS_EXECUTED} checks; at least 50 are required.",\n        )\n\n    write_reports(findings, ROOT / args.output_dir)',
    )
    replace_once(
        path,
        '    print(f"Architecture counter-audit: {errors} error(s), {warnings} warning(s).")',
        '    print(\n        f"Architecture counter-audit: {CHECKS_EXECUTED} check(s), "\n        f"{errors} error(s), {warnings} warning(s)."\n    )',
    )


def harden_validation_workflow() -> None:
    path = ".github/workflows/final-pr-validation.yml"
    replace_once(path, "${{ github.event.inputs.version || '0.4.0-dev' }}", "${{ github.event.inputs.version || '0.4.3-final' }}")
    replace_once(
        path,
        '              if summary.get("errors") != 0:\n                  raise SystemExit(f"{report_path} contains blocking errors")\n              if summary.get("git_head") != head:',
        '              if summary.get("errors") != 0:\n                  raise SystemExit(f"{report_path} contains blocking errors")\n              if report_path.name == "architecture-counter-audit.json":\n                  checks = summary.get("checks")\n                  if not isinstance(checks, int) or checks < 50:\n                      raise SystemExit(f"{report_path} executed insufficient checks: {checks!r}")\n              if summary.get("git_head") != head:',
    )
    replace_once(
        path,
        '      - name: Validation summary\n        if: always()',
        '      - name: Verify release hygiene\n        shell: bash\n        run: ./Scripts/verify_release_hygiene.sh\n      - name: Upload clean final DMG\n        uses: actions/upload-artifact@v4\n        with:\n          name: MixPilot-clean-DMG-${{ env.MIXPILOT_VALIDATION_VERSION }}\n          path: |\n            build/MixPilot-Autopilot.dmg\n            build/MixPilot-Autopilot.dmg.sha256\n          if-no-files-found: error\n      - name: Validation summary\n        if: always()',
    )
    replace_once(path, '          name: MixPilot-PR-final-validation', '          name: MixPilot-PR-final-validation-diagnostics')
    replace_once(
        path,
        '            Mobile/MixPilotRemote/iphone-remote-tests.xcresult\n            build/MixPilot-Autopilot.dmg\n            build/MixPilot-Autopilot.dmg.sha256',
        '            Mobile/MixPilotRemote/iphone-remote-tests.xcresult',
    )


def harden_release_scripts() -> None:
    audit_gate = '''        if report_name == "architecture counter-audit":\n            checks = summary.get("checks")\n            if not isinstance(checks, int) or checks < 50:\n                raise SystemExit(\n                    f"The {report_name} executed insufficient checks: {checks!r}."\n                )\n'''
    for path in ("Scripts/build_release.sh", "Scripts/package_dmg.sh"):
        replace_once(
            path,
            '    if summary.get("errors") != 0:\n        raise SystemExit(f"The {report_name} contains blocking errors.")\n    if summary.get("git_head") != expected_head:',
            '    if summary.get("errors") != 0:\n        raise SystemExit(f"The {report_name} contains blocking errors.")\n' + audit_gate + '    if summary.get("git_head") != expected_head:',
        )

    replace_once(
        "Scripts/build_release.sh",
        'cp "$SWIFTPM_BIN_DIR/$EXECUTABLE" "$APP_DIR/Contents/MacOS/$EXECUTABLE"\n\nshopt -s nullglob',
        'cp "$SWIFTPM_BIN_DIR/$EXECUTABLE" "$APP_DIR/Contents/MacOS/$EXECUTABLE"\n/usr/bin/strip -S "$APP_DIR/Contents/MacOS/$EXECUTABLE"\n\nshopt -s nullglob',
    )
    replace_once(
        "Scripts/package_dmg.sh",
        'rm -rf "$STAGING" "$DMG" "$DMG.sha256"\nmkdir -p "$STAGING"\n/usr/bin/ditto "$APP_DIR" "$STAGING/$APP_NAME.app"',
        'rm -rf "$STAGING" "$DMG" "$DMG.sha256"\nmkdir -p "$STAGING"\nfind "$APP_DIR" -name ".DS_Store" -delete\n/usr/bin/xattr -cr "$APP_DIR"\nCOPYFILE_DISABLE=1 /usr/bin/ditto --norsrc --noextattr "$APP_DIR" "$STAGING/$APP_NAME.app"',
    )
    replace_once(
        "Scripts/package_dmg.sh",
        ')\necho "Packaged: $DMG"',
        ')\n"$ROOT/Scripts/verify_release_hygiene.sh"\necho "Packaged: $DMG"',
    )


def fix_runtime_and_test_findings() -> None:
    replace_once(
        "Sources/MixPilotCore/RekordboxDeviceValidation.swift",
        '        self.records = Dictionary(uniqueKeysWithValues: plan.commands.map {\n            ($0.id, RekordboxDeviceValidationRecord(commandID: $0.id))\n        })',
        '        self.records = plan.commands.reduce(into: [:]) { records, command in\n            records[command.id] = RekordboxDeviceValidationRecord(commandID: command.id)\n        }',
    )
    replace_all(
        "Tests/MixPilotCoreTests/CloudObservabilityTests.swift",
        "/Users/lucas/Music/file.mp3",
        "/private/tmp/mixpilot-tests/Music/file.mp3",
    )
    replace_all(
        "Tests/MixPilotCoreTests/DiagnosticsTests.swift",
        "/Users/example/private/path",
        "/private/tmp/mixpilot-tests/private/path",
    )
    replace_all(
        "Tests/MixPilotCoreTests/RekordboxLibraryImportTests.swift",
        "/Users/dj/Library/Pioneer/rekordbox/master.db",
        "/private/tmp/mixpilot-tests/Pioneer/rekordbox/master.db",
    )
    test_path = "Tests/MixPilotCoreTests/RekordboxDeviceValidationTests.swift"
    content = read(test_path)
    marker = '\n    @Test func storeRoundTripsAtomically() throws {'
    if marker not in content:
        raise SystemExit(f"Missing insertion marker in {test_path}")
    duplicate_test = '''\n    @Test func duplicateCommandIdentifiersDoNotTrap() throws {\n        var plan = try RekordboxDeviceValidationPlanBuilder().make(\n            profile: .developmentDefault,\n            installedVersion: "7.2.3"\n        )\n        let first = try #require(plan.commands.first)\n        plan.commands.append(first)\n\n        let report = RekordboxDeviceValidationReport(plan: plan)\n\n        #expect(report.records.count == Set(plan.commands.map(\\.id)).count)\n        #expect(report.records[first.id]?.commandID == first.id)\n    }\n'''
    write(test_path, content.replace(marker, duplicate_test + marker, 1))


def create_hygiene_script() -> None:
    path = ROOT / "Scripts/verify_release_hygiene.sh"
    content = r'''#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Release hygiene verification must run on macOS." >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MixPilot Autopilot"
APP_DIR="$ROOT/build/$APP_NAME.app"
DMG="$ROOT/build/MixPilot-Autopilot.dmg"
EXECUTABLE="$APP_DIR/Contents/MacOS/MixPilotAutopilot"

[[ -d "$APP_DIR" ]] || { echo "Missing app bundle: $APP_DIR" >&2; exit 1; }
[[ -x "$EXECUTABLE" ]] || { echo "Missing app executable: $EXECUTABLE" >&2; exit 1; }
[[ -f "$DMG" ]] || { echo "Missing DMG: $DMG" >&2; exit 1; }

for pattern in '.DS_Store' '*.log' '*.jsonl' '*.sqlite' '*.sqlite3' '*.db-wal' '*.db-shm' '.env' '*.xcuserstate'; do
  if find "$APP_DIR" -name "$pattern" -print -quit | grep -q .; then
    echo "Forbidden generated or user file in application bundle: $pattern" >&2
    exit 1
  fi
done

if find "$APP_DIR" -path '*/xcuserdata/*' -print -quit | grep -q .; then
  echo "Xcode user data leaked into the application bundle." >&2
  exit 1
fi

if /usr/bin/xattr -lr "$APP_DIR" 2>/dev/null | grep -E 'com\.apple\.(quarantine|metadata)' >/dev/null; then
  echo "User-specific extended attributes remain in the application bundle." >&2
  exit 1
fi

SCAN_FILE="$(mktemp "${TMPDIR:-/tmp}/mixpilot-release-strings.XXXXXX")"
MOUNT_POINT="$(mktemp -d "${TMPDIR:-/tmp}/mixpilot-dmg-mount.XXXXXX")"
attached=0
cleanup() {
  if (( attached == 1 )); then
    hdiutil detach "$MOUNT_POINT" -quiet || true
  fi
  rm -f "$SCAN_FILE"
  rmdir "$MOUNT_POINT" 2>/dev/null || true
}
trap cleanup EXIT

find "$APP_DIR" -type f -print0 | while IFS= read -r -d '' file; do
  /usr/bin/strings -a "$file" || true
done > "$SCAN_FILE"

if grep -E '/Users/[A-Za-z0-9._-]+|/home/[A-Za-z0-9._-]+' "$SCAN_FILE" >/dev/null; then
  echo "Absolute build-machine or user-home path found in the release payload." >&2
  grep -E '/Users/[A-Za-z0-9._-]+|/home/[A-Za-z0-9._-]+' "$SCAN_FILE" | head -20 >&2
  exit 1
fi

if grep -E 'gh[pousr]_[A-Za-z0-9]{30,}|sk-(proj-)?[A-Za-z0-9_-]{20,}|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY' "$SCAN_FILE" >/dev/null; then
  echo "Credential-like material found in the release payload." >&2
  exit 1
fi

if /usr/bin/otool -l "$EXECUTABLE" | grep -E '/Users/|/home/' >/dev/null; then
  echo "A load command contains a user-specific path." >&2
  exit 1
fi

hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT_POINT" "$DMG" -quiet
attached=1
[[ -d "$MOUNT_POINT/$APP_NAME.app" ]] || { echo "DMG does not contain the application." >&2; exit 1; }
[[ -L "$MOUNT_POINT/Applications" ]] || { echo "DMG does not contain the Applications shortcut." >&2; exit 1; }

unexpected="$(find "$MOUNT_POINT" -mindepth 1 -maxdepth 1 ! -name "$APP_NAME.app" ! -name Applications -print)"
if [[ -n "$unexpected" ]]; then
  echo "Unexpected top-level DMG payload:" >&2
  echo "$unexpected" >&2
  exit 1
fi

codesign --verify --deep --strict --verbose=2 "$MOUNT_POINT/$APP_NAME.app"
echo "Release hygiene verified: no user data, home paths, credentials or generated runtime files."
'''
    path.write_text(content, encoding="utf-8")
    path.chmod(0o755)


def remove_one_shot_files() -> None:
    for relative in (
        "Scripts/apply_final_release_hardening.py",
        ".github/workflows/final-release-hardening-pr.yml",
    ):
        target = ROOT / relative
        if target.exists():
            target.unlink()


def main() -> None:
    harden_counter_audit()
    create_hygiene_script()
    harden_validation_workflow()
    harden_release_scripts()
    fix_runtime_and_test_findings()
    remove_one_shot_files()
    print("Final release hardening patch applied.")


if __name__ == "__main__":
    main()
