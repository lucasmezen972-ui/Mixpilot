#!/usr/bin/env python3
"""Portable final repository audit for MixPilot.

This script deliberately avoids Xcode-only dependencies. It validates repository
hygiene and policies that must remain true even while GitHub-hosted runners are
unavailable. It does not claim Apple builds, hardware validation or CI success.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import sys
from dataclasses import dataclass, asdict

ROOT = pathlib.Path(__file__).resolve().parents[1]
WORKFLOW_ROOT = ROOT / ".github" / "workflows"

TEXT_SUFFIXES = {
    ".c", ".cc", ".cpp", ".css", ".entitlements", ".h", ".html", ".json",
    ".md", ".m", ".mm", ".plist", ".py", ".sh", ".sql", ".strings",
    ".swift", ".toml", ".txt", ".xcconfig", ".xml", ".yaml", ".yml",
}
GENERATED_PARTS = {
    ".build", ".DS_Store", ".pytest_cache", ".swiftpm", "DerivedData",
    "__pycache__", "xcuserdata",
}
GENERATED_SUFFIXES = {
    ".bak", ".dmg", ".log", ".orig", ".pyc", ".swp", ".tmp", ".xcresult",
}
AUTOMATIC_WORKFLOW_EVENTS = {
    "push", "pull_request", "pull_request_target", "schedule", "workflow_run",
    "repository_dispatch",
}
GENERIC_USERNAMES = {"dj", "example", "runner", "test", "user"}
CRITICAL_UI_FILES = (
    pathlib.Path("Sources/MixPilotApp/MixPilotMainShellView.swift"),
    pathlib.Path("Sources/MixPilotApp/DJSoftwareSettingsView.swift"),
    pathlib.Path("Sources/MixPilotApp/UnifiedWorkspaceView.swift"),
)
ALLOWED_UI_LITERALS = {"MIXPILOT"}

PRIVATE_KEY_RE = re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----")
TOKEN_PATTERNS = (
    re.compile(r"\bgithub_pat_[A-Za-z0-9_]{30,}\b"),
    re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}\b"),
    re.compile(r"\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b"),
    re.compile(r"\bsbp_[A-Za-z0-9]{20,}\b"),
)
LOCAL_PATH_RE = re.compile(
    r"(?:/Users/(?P<mac>[A-Za-z0-9._-]+)/|/home/(?P<linux>[A-Za-z0-9._-]+)/|"
    r"(?P<windows>[A-Za-z]):\\Users\\(?P<winuser>[^\\\s]+)\\)"
)
MARKER_RE = re.compile(r"\b(?:TODO|FIXME|HACK|XXX)\b")
UI_LITERAL_RE = re.compile(
    r"\b(?:Text|Button|Label|Toggle|Picker|Section|TextField|SecureField)"
    r"\(\s*\"([^\"\\]*(?:\\.[^\"\\]*)*)\""
)
HELP_LITERAL_RE = re.compile(r"\.help\(\s*\"([^\"\\]*(?:\\.[^\"\\]*)*)\"")


@dataclass(frozen=True, order=True)
class Finding:
    category: str
    path: str
    detail: str


def tracked_files() -> list[pathlib.Path]:
    try:
        completed = subprocess.run(
            ["git", "ls-files", "-z"],
            cwd=ROOT,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        return [ROOT / item.decode("utf-8") for item in completed.stdout.split(b"\0") if item]
    except (OSError, subprocess.CalledProcessError):
        return [path for path in ROOT.rglob("*") if path.is_file() and ".git" not in path.parts]


def relative(path: pathlib.Path) -> str:
    return str(path.relative_to(ROOT))


def read_text(path: pathlib.Path) -> str | None:
    if path.suffix not in TEXT_SUFFIXES and path.name not in {"Package.swift", "Package.resolved"}:
        return None
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return None


def audit_workflows(findings: list[Finding]) -> None:
    if not WORKFLOW_ROOT.is_dir():
        findings.append(Finding("workflow", ".github/workflows", "workflow directory is missing"))
        return

    workflows = sorted([*WORKFLOW_ROOT.glob("*.yml"), *WORKFLOW_ROOT.glob("*.yaml")])
    if not workflows:
        findings.append(Finding("workflow", ".github/workflows", "no workflow file found"))
        return

    for path in workflows:
        text = path.read_text(encoding="utf-8")
        has_manual_dispatch = bool(
            re.search(r"(?m)^\s{2}workflow_dispatch\s*:", text)
            or re.search(r"(?m)^on\s*:\s*workflow_dispatch\s*$", text)
            or re.search(r"(?m)^on\s*:\s*\[[^\]]*workflow_dispatch[^\]]*\]\s*$", text)
        )
        if not has_manual_dispatch:
            findings.append(Finding(
                "workflow",
                relative(path),
                "workflow_dispatch is required while hosted runners fail before checkout",
            ))

        for event in sorted(AUTOMATIC_WORKFLOW_EVENTS):
            if re.search(rf"(?m)^\s{{2}}{re.escape(event)}\s*:", text):
                findings.append(Finding(
                    "workflow",
                    relative(path),
                    f"automatic trigger '{event}' must remain disabled",
                ))


def audit_paths(files: list[pathlib.Path], findings: list[Finding]) -> None:
    for path in files:
        rel = path.relative_to(ROOT)
        if any(part in GENERATED_PARTS for part in rel.parts) or path.suffix in GENERATED_SUFFIXES:
            findings.append(Finding("generated-artifact", str(rel), "generated artifact is tracked"))
        if path.name.startswith(".env") and path.name not in {".env.example", ".env.sample"}:
            findings.append(Finding("secret-file", str(rel), "environment file must not be tracked"))


def audit_text(files: list[pathlib.Path], findings: list[Finding]) -> None:
    for path in files:
        text = read_text(path)
        if text is None:
            continue
        rel = path.relative_to(ROOT)

        if PRIVATE_KEY_RE.search(text):
            findings.append(Finding("secret", str(rel), "private key material detected"))

        for pattern in TOKEN_PATTERNS:
            for match in pattern.finditer(text):
                token = match.group(0)
                if "example" not in token.lower() and "test" not in token.lower():
                    findings.append(Finding("secret", str(rel), "credential-like token detected"))
                    break

        for match in LOCAL_PATH_RE.finditer(text):
            username = match.group("mac") or match.group("linux") or match.group("winuser") or ""
            if username.lower() not in GENERIC_USERNAMES:
                findings.append(Finding(
                    "local-path",
                    str(rel),
                    f"machine-specific home path detected for user '{username}'",
                ))

        marker_scope = rel.parts and rel.parts[0] in {"Sources", "Shared", "Mobile", "Scripts"}
        if marker_scope and path.name != pathlib.Path(__file__).name and MARKER_RE.search(text):
            findings.append(Finding("unfinished-marker", str(rel), "TODO/FIXME/HACK/XXX marker detected"))


def audit_ui_literals(findings: list[Finding]) -> None:
    for rel in CRITICAL_UI_FILES:
        path = ROOT / rel
        if not path.is_file():
            findings.append(Finding("ui-localization", str(rel), "critical UI source is missing"))
            continue
        text = path.read_text(encoding="utf-8")
        literals = UI_LITERAL_RE.findall(text) + HELP_LITERAL_RE.findall(text)
        for literal in sorted(set(literals)):
            if literal in ALLOWED_UI_LITERALS:
                continue
            if not re.search(r"[A-Za-zÀ-ÿ]", literal):
                continue
            if literal.startswith("\\("):
                continue
            findings.append(Finding(
                "ui-localization",
                str(rel),
                f"user-visible literal must use a stable localization key: {literal!r}",
            ))


def audit_required_files(findings: list[Finding]) -> None:
    required = (
        "Documentation/TECHNICAL_BENCHMARK_AND_PRIOR_ART.md",
        "Documentation/RELIABILITY_HARDENING_REPORT.md",
        "Sources/MixPilotHelp/Resources/fr.lproj/Workspace.strings",
        "Sources/MixPilotHelp/Resources/en.lproj/Workspace.strings",
        "Sources/MixPilotHelp/Resources/es.lproj/Workspace.strings",
        "Scripts/check_localization_consistency.py",
    )
    for value in required:
        if not (ROOT / value).is_file():
            findings.append(Finding("required-file", value, "required final-phase file is missing"))


def run_audit() -> list[Finding]:
    files = tracked_files()
    findings: list[Finding] = []
    audit_workflows(findings)
    audit_paths(files, findings)
    audit_text(files, findings)
    audit_ui_literals(findings)
    audit_required_files(findings)
    return sorted(set(findings))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=pathlib.Path)
    parser.add_argument(
        "--strict",
        action="store_true",
        help="return a non-zero exit code when any finding exists",
    )
    args = parser.parse_args()

    findings = run_audit()
    payload = {
        "status": "passed" if not findings else "failed",
        "finding_count": len(findings),
        "findings": [asdict(finding) for finding in findings],
        "limitations": [
            "No Apple build or hardware validation is performed by this portable audit.",
            "GitHub Actions success is not claimed until a runner executes the workflow.",
        ],
    }

    rendered = json.dumps(payload, ensure_ascii=False, indent=2)
    print(rendered)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + "\n", encoding="utf-8")

    if findings and args.strict:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
