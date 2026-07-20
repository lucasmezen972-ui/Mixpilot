#!/usr/bin/env python3
"""Independent architecture and release counter-audit for MixPilot.

This pass intentionally differs from ultimate_repository_audit.py. It verifies
cross-file contracts, security boundaries, actor assumptions, platform privacy
manifests, OAuth packaging, persistence guarantees, and release gates. It does
not attempt to lint every line; the first audit already owns that responsibility.
"""

from __future__ import annotations

import argparse
import json
import plistlib
import re
import subprocess
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class Finding:
    severity: str
    rule: str
    path: str
    line: int
    message: str
    excerpt: str = ""


def git_head() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip()
    except Exception:
        return ""


def read(path: str) -> str:
    file_path = ROOT / path
    try:
        return file_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return ""


def line_for(text: str, token: str) -> int:
    index = text.find(token)
    return 1 if index < 0 else text.count("\n", 0, index) + 1


def add(
    findings: list[Finding],
    severity: str,
    rule: str,
    path: str,
    message: str,
    excerpt: str = "",
    token: str = "",
) -> None:
    text = read(path)
    findings.append(
        Finding(
            severity=severity,
            rule=rule,
            path=path,
            line=line_for(text, token or excerpt) if text else 1,
            message=message,
            excerpt=excerpt[:240],
        )
    )


def require_file(findings: list[Finding], path: str) -> bool:
    if (ROOT / path).is_file():
        return True
    add(findings, "error", "required-file-missing", path, "Required release file is missing.")
    return False


def require_contains(
    findings: list[Finding],
    path: str,
    token: str,
    rule: str,
    message: str,
) -> None:
    text = read(path)
    if token not in text:
        add(findings, "error", rule, path, message, token, token)


def forbid_contains(
    findings: list[Finding],
    path: str,
    token: str,
    rule: str,
    message: str,
) -> None:
    text = read(path)
    if token in text:
        add(findings, "error", rule, path, message, token, token)


def check_release_gates(findings: list[Finding]) -> None:
    build = "Scripts/build_release.sh"
    package = "Scripts/package_dmg.sh"
    first = "Scripts/ultimate_repository_audit.py"
    second = "Scripts/architecture_counter_audit.py"
    for path in (build, package, first, second):
        require_file(findings, path)

    for path in (build, package):
        require_contains(
            findings,
            path,
            "ultimate_repository_audit.py",
            "missing-first-audit-gate",
            "Release packaging must run or verify the line-by-line audit.",
        )
        require_contains(
            findings,
            path,
            "architecture_counter_audit.py",
            "missing-second-audit-gate",
            "Release packaging must run or verify the independent counter-audit.",
        )
        require_contains(
            findings,
            path,
            "git_head",
            "missing-audit-sha-check",
            "Release packaging must verify that audit reports match the current Git commit.",
        )


def check_spotify_oauth(findings: list[Finding]) -> None:
    path = "Sources/MixPilotApp/SpotifyLibraryCoordinator.swift"
    require_file(findings, path)
    require_contains(
        findings,
        path,
        "@preconcurrency import AuthenticationServices",
        "spotify-auth-preconcurrency-missing",
        "AuthenticationServices must use the compatibility import required by the macOS callback bridge.",
    )
    require_contains(
        findings,
        path,
        "webAuthenticationPresentationContext = presentationContext",
        "spotify-presentation-provider-not-retained",
        "The OAuth presentation provider must be retained for the full authentication session.",
    )
    require_contains(
        findings,
        path,
        "nonisolated func presentationAnchor",
        "spotify-anchor-isolation-regression",
        "The AuthenticationServices witness must remain nonisolated to avoid the observed Swift actor trap.",
    )
    forbid_contains(
        findings,
        path,
        "MainActor.assumeIsolated",
        "spotify-mainactor-assumption",
        "Runtime actor assumptions can reproduce the OAuth SIGTRAP.",
    )
    forbid_contains(
        findings,
        path,
        "DispatchQueue.main.sync",
        "spotify-main-sync",
        "Synchronous dispatch to the main queue can deadlock or trap.",
    )
    forbid_contains(
        findings,
        path,
        "Dictionary(\n                uniqueKeysWithValues: components.queryItems",
        "spotify-duplicate-callback-query-trap",
        "OAuth callback query parsing must tolerate duplicate parameter names.",
    )

    build = "Scripts/build_release.sh"
    require_contains(
        findings,
        build,
        "mixpilot-spotify",
        "spotify-url-scheme-not-packaged",
        "The macOS application bundle must register the Spotify callback scheme.",
    )


def check_keychain_boundaries(findings: list[Finding]) -> None:
    paths = [
        "Sources/MixPilotApp/SpotifyBridgeSupport.swift",
        "Sources/MixPilotRemoteBridge/RemotePairingAuthority.swift",
        "Mobile/MixPilotRemote/Sources/KeychainStore.swift",
    ]
    for path in paths:
        if not require_file(findings, path):
            continue
        require_contains(
            findings,
            path,
            "kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly",
            "keychain-not-device-bound",
            "Long-lived Spotify or Remote credentials must remain bound to the current device.",
        )


def check_ios_privacy_manifest(findings: list[Finding]) -> None:
    path = "Mobile/MixPilotRemote/Sources/PrivacyInfo.xcprivacy"
    if not require_file(findings, path):
        return
    try:
        payload = plistlib.loads((ROOT / path).read_bytes())
    except Exception as error:
        add(findings, "error", "invalid-privacy-manifest", path, f"Privacy manifest is invalid: {error}")
        return

    reasons: set[str] = set()
    for entry in payload.get("NSPrivacyAccessedAPITypes", []):
        if entry.get("NSPrivacyAccessedAPIType") == "NSPrivacyAccessedAPICategoryUserDefaults":
            reasons.update(entry.get("NSPrivacyAccessedAPITypeReasons", []))
    if "CA92.1" not in reasons:
        add(
            findings,
            "error",
            "userdefaults-reason-missing",
            path,
            "The iPhone Remote privacy manifest must declare the approved UserDefaults reason CA92.1.",
        )


def iter_swift_sources() -> Iterable[Path]:
    for prefix in ("Sources", "Mobile", "Shared"):
        root = ROOT / prefix
        if root.exists():
            yield from root.rglob("*.swift")


def has_safety_proof(lines: list[str], index: int) -> bool:
    start = max(0, index - 6)
    context = "\n".join(lines[start : index + 1]).upper()
    return "SAFETY:" in context and any(
        word in context for word in ("IMMUTABLE", "LOCK", "ACTOR", "SERIAL", "THREAD")
    )


def check_concurrency_boundaries(findings: list[Finding]) -> None:
    for file_path in iter_swift_sources():
        rel = file_path.relative_to(ROOT).as_posix()
        try:
            text = file_path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        lines = text.splitlines()
        for index, line in enumerate(lines):
            if "@unchecked Sendable" in line or "nonisolated(unsafe)" in line:
                if not has_safety_proof(lines, index):
                    findings.append(
                        Finding(
                            severity="error",
                            rule="unsafe-concurrency-without-architecture-proof",
                            path=rel,
                            line=index + 1,
                            message="Every unsafe concurrency escape hatch requires a nearby SAFETY proof.",
                            excerpt=line.strip(),
                        )
                    )

        if "@MainActor" in text and re.search(r"\b(?:Data|String)\s*\(\s*contentsOf:", text):
            add(
                findings,
                "warning",
                "mainactor-file-io",
                rel,
                "A MainActor-isolated file still performs synchronous file I/O; verify the operation is moved off the UI actor.",
                "Data/String(contentsOf:)",
                "contentsOf:",
            )


def check_transport_and_secrets(findings: list[Finding]) -> None:
    secret_patterns = {
        "service-role-key": re.compile(r"service[_-]?role[^\n]{0,60}(?:eyJ|[A-Za-z0-9_-]{32,})", re.I),
        "private-key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
        "github-token": re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}\b"),
    }
    for file_path in ROOT.rglob("*"):
        if not file_path.is_file() or any(part in {".git", ".build", "build"} for part in file_path.parts):
            continue
        if file_path.suffix.lower() not in {".swift", ".sh", ".py", ".yml", ".yaml", ".json", ".plist", ".sql", ".md"}:
            continue
        try:
            text = file_path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        rel = file_path.relative_to(ROOT).as_posix()
        for rule, pattern in secret_patterns.items():
            match = pattern.search(text)
            if match:
                findings.append(
                    Finding("error", rule, rel, line_for(text, match.group(0)), "Sensitive credential material appears in the repository.", match.group(0)[:120])
                )
        for match in re.finditer(r"http://(?!localhost\b|127\.0\.0\.1\b|0\.0\.0\.0\b)", text):
            findings.append(
                Finding("error", "cleartext-transport", rel, line_for(text, match.group(0)), "Non-local network transport must use HTTPS or TLS.", match.group(0))
            )


def check_supabase_security(findings: list[Finding]) -> None:
    migration_root = ROOT / "supabase" / "migrations"
    if not migration_root.exists():
        add(findings, "error", "supabase-migrations-missing", "supabase/migrations", "Supabase migrations directory is missing.")
        return

    for file_path in migration_root.glob("*.sql"):
        text = file_path.read_text(encoding="utf-8")
        lowered = text.lower()
        if "security definer" in lowered and "set search_path" not in lowered:
            findings.append(
                Finding(
                    "error",
                    "security-definer-search-path",
                    file_path.relative_to(ROOT).as_posix(),
                    line_for(lowered, "security definer"),
                    "SECURITY DEFINER functions must pin search_path.",
                    "security definer",
                )
            )


def check_package_contract(findings: list[Finding]) -> None:
    path = "Package.swift"
    if not require_file(findings, path):
        return
    text = read(path)
    if ".unsafeFlags(" in text:
        add(findings, "error", "unsafe-swift-flags", path, "Release targets must not rely on unsafe Swift compiler flags.", ".unsafeFlags(", ".unsafeFlags(")
    require_contains(findings, path, ".macOS(.v14)", "macos-floor-drift", "Package.swift must keep the supported macOS 14 deployment floor.")


def write_reports(findings: list[Finding], output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    head = git_head()
    errors = [item for item in findings if item.severity == "error"]
    warnings = [item for item in findings if item.severity == "warning"]
    report = {
        "summary": {
            "git_head": head,
            "errors": len(errors),
            "warnings": len(warnings),
            "checks": len(findings),
            "pass": not errors,
        },
        "findings": [asdict(item) for item in findings],
    }
    (output_dir / "architecture-counter-audit.json").write_text(
        json.dumps(report, indent=2, sort_keys=True), encoding="utf-8"
    )

    lines = [
        "# MixPilot architecture counter-audit",
        "",
        f"- Git commit: `{head or 'unknown'}`",
        f"- Blocking errors: **{len(errors)}**",
        f"- Warnings: **{len(warnings)}**",
        "",
    ]
    for severity, title in (("error", "Blocking errors"), ("warning", "Warnings")):
        selected = [item for item in findings if item.severity == severity]
        lines.extend([f"## {title}", ""])
        if not selected:
            lines.extend(["None.", ""])
            continue
        for item in selected:
            lines.append(
                f"- `{item.path}:{item.line}` **{item.rule}** — {item.message}"
                + (f" (`{item.excerpt}`)" if item.excerpt else "")
            )
        lines.append("")
    (output_dir / "architecture-counter-audit.md").write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", default="architecture-counter-audit")
    args = parser.parse_args()

    findings: list[Finding] = []
    check_release_gates(findings)
    check_spotify_oauth(findings)
    check_keychain_boundaries(findings)
    check_ios_privacy_manifest(findings)
    check_concurrency_boundaries(findings)
    check_transport_and_secrets(findings)
    check_supabase_security(findings)
    check_package_contract(findings)

    write_reports(findings, ROOT / args.output_dir)
    errors = sum(item.severity == "error" for item in findings)
    warnings = sum(item.severity == "warning" for item in findings)
    print(f"Architecture counter-audit: {errors} error(s), {warnings} warning(s).")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
