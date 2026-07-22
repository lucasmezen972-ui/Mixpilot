#!/usr/bin/env python3
"""Independent architecture, security and release counter-audit for MixPilot.

This pass deliberately differs from ``ultimate_repository_audit.py``. It checks
cross-file contracts and counts every assertion it performs. A report with very
few checks is itself a blocking failure, preventing an empty audit from looking
successful.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]
MINIMUM_CHECKS = 50
CHECKS_EXECUTED = 0
TEXT_SUFFIXES = {
    ".swift", ".sh", ".py", ".yml", ".yaml", ".json", ".plist", ".sql", ".md",
}
TEST_PREFIXES = ("Tests/", "XcodeTests/")
SELF_AUDIT_PATHS = {
    "Scripts/architecture_counter_audit.py",
    "Scripts/ultimate_repository_audit.py",
}


@dataclass(frozen=True)
class Finding:
    severity: str
    rule: str
    path: str
    line: int
    message: str
    excerpt: str = ""


def mark_check(count: int = 1) -> None:
    global CHECKS_EXECUTED
    CHECKS_EXECUTED += count


def git_head() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip()
    except Exception:
        return ""


def tracked_paths() -> list[Path]:
    output = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    return [ROOT / value for value in output.decode("utf-8").split("\0") if value]


def tracked_text_paths() -> Iterable[Path]:
    for path in tracked_paths():
        if path.suffix.lower() in TEXT_SUFFIXES and path.is_file():
            yield path


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def read(path: str | Path) -> str:
    candidate = ROOT / path if isinstance(path, str) else path
    try:
        return candidate.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return ""


def line_for(text: str, token: str) -> int:
    offset = text.find(token)
    return 1 if offset < 0 else text.count("\n", 0, offset) + 1


def add(
    findings: list[Finding],
    severity: str,
    rule: str,
    path: str,
    message: str,
    token: str = "",
    excerpt: str = "",
) -> None:
    text = read(path)
    findings.append(
        Finding(
            severity=severity,
            rule=rule,
            path=path,
            line=line_for(text, token or excerpt) if text else 1,
            message=message,
            excerpt=(excerpt or token)[:240],
        )
    )


def require_file(findings: list[Finding], path: str) -> bool:
    mark_check()
    if (ROOT / path).is_file():
        return True
    add(findings, "error", "required-file-missing", path, "Required release file is missing.")
    return False


def require_contains(
    findings: list[Finding], path: str, token: str, rule: str, message: str
) -> None:
    mark_check()
    if token not in read(path):
        add(findings, "error", rule, path, message, token)


def forbid_contains(
    findings: list[Finding], path: str, token: str, rule: str, message: str
) -> None:
    mark_check()
    if token in read(path):
        add(findings, "error", rule, path, message, token)


def check_release_contracts(findings: list[Finding]) -> None:
    build = "Scripts/build_release.sh"
    package = "Scripts/package_dmg.sh"
    hygiene = "Scripts/verify_release_hygiene.sh"
    workflow = ".github/workflows/final-pr-validation.yml"
    manifest = "Package.swift"

    for path in (build, package, hygiene, workflow, manifest):
        require_file(findings, path)

    contracts = (
        (build, "swift build -c release", "release-build-missing", "Release build is not explicit."),
        (build, "/usr/bin/strip -S", "release-strip-missing", "Release executable must be stripped before signing."),
        (build, "mixpilot-spotify", "spotify-scheme-not-packaged", "Spotify callback scheme is not packaged."),
        (build, "mixpilot-autopilot", "account-scheme-not-packaged", "MixPilot account callback scheme is not packaged."),
        (build, "codesign --verify --deep --strict", "codesign-verification-missing", "App signature is not verified."),
        (build, "architecture-counter-audit.json", "counter-audit-gate-missing", "Release build does not require the counter-audit."),
        (build, "summary.get(\"checks\")", "counter-audit-coverage-gate-missing", "Release build does not validate counter-audit coverage."),
        (package, "--noextattr", "dmg-xattr-sanitization-missing", "DMG staging does not omit extended attributes."),
        (package, "COPYFILE_DISABLE=1", "dmg-copyfile-sanitization-missing", "DMG staging does not disable AppleDouble metadata."),
        (package, "verify_release_hygiene.sh", "dmg-hygiene-gate-missing", "Packaged DMG is not inspected."),
        (package, "shasum -a 256", "dmg-checksum-missing", "DMG checksum is not generated."),
        (workflow, "summary.get(\"checks\")", "workflow-counter-coverage-missing", "Final validation does not verify counter-audit coverage."),
        (workflow, "verify_release_hygiene.sh", "workflow-hygiene-gate-missing", "Final validation does not inspect the DMG payload."),
        (workflow, "Fresh Supabase migrations", "fresh-database-gate-missing", "Final validation does not rebuild Supabase migrations."),
        (workflow, "Complete Swift test suite", "swift-test-gate-missing", "Final validation does not run the complete Swift suite."),
        (workflow, "Build and XCTest iPhone Remote", "iphone-test-gate-missing", "Final validation does not test the iPhone Remote."),
        (hygiene, "/Users/", "home-path-scan-missing", "Release hygiene does not scan for user-home paths."),
        (hygiene, "codesign --verify --deep --strict", "mounted-signature-check-missing", "Mounted DMG application signature is not verified."),
    )
    for path, token, rule, message in contracts:
        require_contains(findings, path, token, rule, message)

    forbid_contains(
        findings,
        manifest,
        ".unsafeFlags(",
        "unsafe-swift-flags",
        "Swift package manifest contains unsafe compiler flags.",
    )


def check_spotify_contracts(findings: list[Finding]) -> None:
    path = "Sources/MixPilotApp/SpotifyLibraryCoordinator.swift"
    tests = "Tests/MixPilotSystemTests/SpotifyAuthenticationPresentationTests.swift"
    require_file(findings, path)
    require_file(findings, tests)
    contracts = (
        ("SpotifyAuthenticationCallbackRelay: @unchecked Sendable", "spotify-relay-missing", "Spotify callback relay is missing."),
        ("// SAFETY:", "spotify-relay-safety-undocumented", "The unchecked Sendable relay lacks a local safety proof."),
        ("SpotifyWebAuthenticationSessionFactory", "spotify-session-factory-missing", "AuthenticationServices callback is not created outside MainActor."),
        ("webAuthenticationSessionID", "spotify-session-id-missing", "Spotify callbacks are not bound to a session identifier."),
        ("guard webAuthenticationSessionID == sessionID", "spotify-stale-callback-guard-missing", "Stale Spotify callbacks are not rejected."),
        ("prefersEphemeralWebBrowserSession = true", "spotify-ephemeral-session-missing", "Spotify browser session is not ephemeral."),
        ("SpotifyPKCE.challenge", "spotify-pkce-missing", "Spotify OAuth PKCE is missing."),
    )
    for token, rule, message in contracts:
        require_contains(findings, path, token, rule, message)
    forbid_contains(
        findings,
        path,
        ") { [weak self] callbackURL, error in",
        "spotify-mainactor-callback-regression",
        "ASWebAuthenticationSession callback captures the MainActor coordinator directly.",
    )


def check_cloud_identity_contracts(findings: list[Finding]) -> None:
    service = "Sources/MixPilotSystem/MixPilotCloudService.swift"
    mapping = "Sources/MixPilotSystem/MixPilotRemoteMappingService.swift"
    identity = "Sources/MixPilotSystem/MixPilotCloudIdentity.swift"
    coordinator = "Sources/MixPilotApp/MixPilotCloudCoordinator.swift"
    app = "Sources/MixPilotApp/MixPilotApp.swift"
    view = "Sources/MixPilotApp/MixPilotCloudAccountView.swift"

    for path in (service, mapping, identity, coordinator, app, view):
        require_file(findings, path)

    for path in (service, mapping):
        forbid_contains(
            findings,
            path,
            "signInAnonymously",
            "anonymous-cloud-authentication",
            "Cloud operations must never create anonymous accounts.",
        )
        require_contains(
            findings,
            path,
            "MixPilotCloudIdentityPolicy.callbackURL",
            "explicit-cloud-callback-missing",
            "Cloud client is not bound to the explicit PKCE callback.",
        )

    contracts = (
        (service, "flowType: .pkce", "cloud-pkce-missing", "Cloud auth does not use PKCE."),
        (service, "requestMagicLink", "magic-link-api-missing", "Magic-link API is missing."),
        (service, "guard supabase.auth.currentSession != nil", "cloud-fail-closed-missing", "Cloud service does not fail closed when signed out."),
        (identity, "normalizedEmail", "cloud-email-validation-missing", "Cloud identity does not normalize and validate e-mail."),
        (identity, "acceptsCallback", "cloud-callback-validation-missing", "Cloud callback is not validated."),
        (coordinator, "identityState", "cloud-identity-state-missing", "UI coordinator does not expose identity state."),
        (app, "cloud.handleAuthenticationCallback(url)", "cloud-callback-routing-missing", "App does not route the cloud callback."),
        (view, "Compte MixPilot", "cloud-account-view-missing", "Account UI is missing."),
    )
    for path, token, rule, message in contracts:
        require_contains(findings, path, token, rule, message)


def check_cloud_database_contracts(findings: list[Finding]) -> None:
    migration_text = "\n".join(
        read(path) for path in tracked_paths() if relative(path).startswith("supabase/migrations/") and path.suffix == ".sql"
    )
    test_text = "\n".join(
        read(path) for path in tracked_paths() if relative(path).startswith("supabase/tests/") and path.suffix == ".sql"
    )
    contracts = (
        (migration_text, "claim_mixpilot_commands", "claim-rpc-missing", "Atomic command-claim RPC is missing."),
        (migration_text, "complete_mixpilot_command", "complete-rpc-missing", "Atomic command-completion RPC is missing."),
        (migration_text.lower(), "revoke update", "command-update-revoke-missing", "Direct command UPDATE privilege is not revoked."),
        (migration_text.lower(), "security definer", "security-definer-missing", "Atomic command RPCs are not security-definer functions."),
        (test_text, "claim_mixpilot_commands", "claim-rpc-test-missing", "Database tests do not exercise command claiming."),
        (test_text, "complete_mixpilot_command", "complete-rpc-test-missing", "Database tests do not exercise command completion."),
    )
    for text, token, rule, message in contracts:
        mark_check()
        if token not in text:
            add(findings, "error", rule, "supabase", message, token)


def check_runtime_safety(findings: list[Finding]) -> None:
    source_paths = [
        path for path in tracked_text_paths() if relative(path).startswith("Sources/") and path.suffix == ".swift"
    ]
    for path in source_paths:
        rel = relative(path)
        text = read(path)

        mark_check()
        if "Dictionary(uniqueKeysWithValues: plan.commands.map" in text:
            add(
                findings,
                "error",
                "duplicate-key-runtime-trap",
                rel,
                "Validation report construction can trap on duplicate command identifiers.",
                "Dictionary(uniqueKeysWithValues: plan.commands.map",
            )

        mark_check()
        if re.search(r"https?://[^\s\"']+", text) and "http://" in text:
            add(
                findings,
                "error",
                "plaintext-production-url",
                rel,
                "Production Swift source contains a plaintext HTTP URL.",
                "http://",
            )

        for match in re.finditer(r"@unchecked\s+Sendable", text):
            mark_check()
            prefix = text[max(0, match.start() - 500):match.start()]
            if "SAFETY:" not in prefix:
                add(
                    findings,
                    "error",
                    "unchecked-sendable-undocumented",
                    rel,
                    "@unchecked Sendable requires a nearby SAFETY invariant.",
                    "@unchecked Sendable",
                )


def check_credentials_and_user_paths(findings: list[Finding]) -> None:
    secret_patterns = (
        (re.compile(r"gh[pousr]_[A-Za-z0-9]{30,}"), "github-token"),
        (re.compile(r"sk-(?:proj-)?[A-Za-z0-9_-]{20,}"), "openai-key"),
        (re.compile(r"BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY"), "private-key"),
    )
    for path in tracked_text_paths():
        rel = relative(path)
        text = read(path)
        if rel in SELF_AUDIT_PATHS:
            continue

        for pattern, label in secret_patterns:
            mark_check()
            match = pattern.search(text)
            if match:
                add(
                    findings,
                    "error",
                    f"credential-{label}",
                    rel,
                    "Credential-like material is committed to the repository.",
                    match.group(0),
                )

        mark_check()
        if rel.startswith(TEST_PREFIXES) and re.search(r"/(?:Users|home)/[A-Za-z0-9._-]+/", text):
            add(
                findings,
                "warning",
                "test-user-home-literal",
                rel,
                "Test fixture contains a user-home path; prefer a neutral temporary path.",
                "/Users/",
            )


def write_reports(findings: list[Finding], output_dir: Path) -> None:
    errors = [finding for finding in findings if finding.severity == "error"]
    warnings = [finding for finding in findings if finding.severity == "warning"]
    summary = {
        "checks": CHECKS_EXECUTED,
        "errors": len(errors),
        "git_head": git_head(),
        "pass": not errors,
        "warnings": len(warnings),
    }
    payload = {"summary": summary, "findings": [asdict(finding) for finding in findings]}
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "architecture-counter-audit.json").write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    lines = [
        "# MixPilot Architecture Counter-Audit",
        "",
        f"- Git head: `{summary['git_head']}`",
        f"- Checks executed: **{CHECKS_EXECUTED}**",
        f"- Errors: **{len(errors)}**",
        f"- Warnings: **{len(warnings)}**",
        f"- Result: **{'PASS' if not errors else 'FAIL'}**",
        "",
    ]
    if findings:
        lines.extend(["## Findings", ""])
        for finding in findings:
            lines.append(
                f"- **{finding.severity.upper()}** `{finding.rule}` — "
                f"`{finding.path}:{finding.line}` — {finding.message}"
            )
    else:
        lines.append("No findings.")
    (output_dir / "architecture-counter-audit.md").write_text(
        "\n".join(lines) + "\n", encoding="utf-8"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", default="architecture-counter-audit")
    args = parser.parse_args()

    findings: list[Finding] = []
    check_release_contracts(findings)
    check_spotify_contracts(findings)
    check_cloud_identity_contracts(findings)
    check_cloud_database_contracts(findings)
    check_runtime_safety(findings)
    check_credentials_and_user_paths(findings)

    if CHECKS_EXECUTED < MINIMUM_CHECKS:
        add(
            findings,
            "error",
            "counter-audit-insufficient-coverage",
            "Scripts/architecture_counter_audit.py",
            f"Only {CHECKS_EXECUTED} checks ran; at least {MINIMUM_CHECKS} are required.",
        )

    write_reports(findings, ROOT / args.output_dir)
    errors = sum(finding.severity == "error" for finding in findings)
    warnings = sum(finding.severity == "warning" for finding in findings)
    print(
        f"Architecture counter-audit: {CHECKS_EXECUTED} check(s), "
        f"{errors} error(s), {warnings} warning(s)."
    )
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
