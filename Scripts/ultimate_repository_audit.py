#!/usr/bin/env python3
"""Repository-wide static audit for MixPilot.

The audit scans every tracked text file line by line and fails on objective,
high-severity defects. Lower-confidence findings are reported as warnings for
manual review. The script intentionally avoids external dependencies.
"""

from __future__ import annotations

import argparse
import json
import plistlib
import re
import subprocess
from dataclasses import asdict, dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

EXCLUDED_PARTS = {
    ".git", ".build", "build", "DerivedData", ".swiftpm", "Pods",
    "Carthage", "node_modules", ".xcodeproj", ".xcworkspace", ".idea",
    ".vscode", "__pycache__", ".pytest_cache", ".mypy_cache",
}
TEXT_SUFFIXES = {
    ".swift", ".m", ".mm", ".h", ".c", ".cc", ".cpp", ".sh", ".bash",
    ".zsh", ".py", ".rb", ".pl", ".sql", ".yml", ".yaml", ".json",
    ".toml", ".plist", ".xcprivacy", ".strings", ".md", ".txt", ".xml",
    ".entitlements", ".xcconfig", ".pbxproj",
}
GENERATED_PATH_PARTS = {"xcuserdata", "DerivedData", ".build", "build"}
SOURCE_PREFIXES = ("Sources/", "Mobile/", "Shared/")
TEST_PREFIXES = (
    "Tests/", "Mobile/MixPilotRemote/XcodeTests/", "Shared/RemoteProtocolV2/Tests/",
)

SECRET_PATTERNS = [
    ("OpenAI-style API key", re.compile(r"\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b")),
    ("GitHub personal access token", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}\b")),
    ("Slack token", re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{20,}\b")),
    ("Supabase access token", re.compile(r"\bsbp_[A-Za-z0-9_-]{20,}\b")),
    ("Private key", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
    ("AWS access key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
]
SWIFT_HARD_ERRORS = [
    ("forbidden-mainactor-assumption", re.compile(r"\bMainActor\.assumeIsolated\s*\("),
     "Runtime actor assumptions can trap; use explicit isolation."),
    ("forbidden-main-sync", re.compile(r"\bDispatchQueue\.main\.sync\s*[\({]"),
     "Synchronous dispatch to the main queue can deadlock or trap."),
    ("unsafe-bitcast", re.compile(r"\bunsafeBitCast\s*\("),
     "unsafeBitCast is forbidden in production code."),
    ("forced-try", re.compile(r"\btry!\s+"), "Forced try can terminate the process."),
    ("unchecked-continuation", re.compile(r"\bwithUnsafe(?:Throwing)?Continuation\b"),
     "Use checked continuations unless a measured hot path proves otherwise."),
    ("blocking-sleep", re.compile(r"\b(?:Thread\.sleep|Darwin\.sleep|Glibc\.sleep|usleep)\s*\("),
     "Blocking sleeps are forbidden in application/runtime source."),
]
SWIFT_WARNINGS = [
    ("task-detached", re.compile(r"\bTask\.detached\s*[\({]"),
     "Detached tasks lose actor and task-local context; verify ownership and cancellation."),
    ("global-queue", re.compile(r"\bDispatchQueue\.global\s*\("),
     "Prefer structured concurrency over global dispatch queues."),
    ("blocking-file-read", re.compile(r"\b(?:Data|String)\s*\(\s*contentsOf:"),
     "Synchronous file I/O may block the calling actor."),
    ("timer-retention", re.compile(r"\bTimer\.scheduledTimer\s*\("),
     "Verify invalidation and retain-cycle handling."),
    ("dictionary-trap", re.compile(r"\bDictionary\s*\(\s*uniqueKeysWithValues:"),
     "Duplicate keys trap at runtime; prove uniqueness or use conflict resolution."),
    ("forced-cast", re.compile(r"\bas!\s+"),
     "Forced casts can terminate the process; prove the type invariant or replace them."),
    ("fatal-production", re.compile(r"\b(?:fatalError|preconditionFailure)\s*\("),
     "Production fatal termination requires explicit justification."),
    ("try-optional", re.compile(r"\btry\?\s+"),
     "Swallowed errors can hide failures; verify the fallback is intentional."),
    ("debug-print", re.compile(r"(?<![A-Za-z0-9_])print\s*\("),
     "Production print output should normally use structured logging."),
    ("swiftui-self-id", re.compile(r"\bForEach\s*\([^,\n]+,\s*id:\s*\\\.self"),
     "ForEach id: \\.self can produce unstable identity for mutable values."),
]
SHELL_HARD_ERRORS = [
    ("shell-eval", re.compile(r"(^|[;&|]\s*)eval\s+"), "eval is forbidden in release/build scripts."),
    ("curl-pipe-shell", re.compile(r"\bcurl\b[^\n|]*\|\s*(?:ba)?sh\b"),
     "Piping remote content directly to a shell is forbidden."),
    ("unquoted-rm-variable", re.compile(r"\brm\s+-[^\n]*r[^\n]*\s+\$[A-Za-z_]"),
     "Recursive deletion must quote and validate variable paths."),
]
INSECURE_TRANSPORT_PATTERNS = [
    ("insecure-http", re.compile(r'http://(?!localhost\b|127\.0\.0\.1\b|0\.0\.0\.0\b)'),
     "Cleartext HTTP is forbidden outside explicit local-development code."),
    ("trust-all-certificates", re.compile(
        r"(allowsAnyHTTPSCertificateForHost|kCFStreamSSLAllowsAnyRoot|"
        r"SecTrustEvaluate\s*\([^)]*\)\s*==\s*errSecSuccess|"
        r"completionHandler\s*\(\s*\.useCredential)"),
     "Certificate trust bypass detected."),
]

MERGE_START = re.compile(r"^<<<<<<<(?:\s|$)", re.MULTILINE)
MERGE_MIDDLE = re.compile(r"^=======$", re.MULTILINE)
MERGE_END = re.compile(r"^>>>>>>>(?:\s|$)", re.MULTILINE)
ABSOLUTE_USER_PATH = re.compile(r"/Users/[A-Za-z0-9._-]+/")
FORCE_UNWRAP_CANDIDATE = re.compile(
    r"(?:\b(?:first|last|randomElement)\!|\bURL\s*\([^)]*\)\!|"
    r"\b[A-Za-z_][A-Za-z0-9_]*\[[^\]]+\]\!)"
)
EMPTY_CATCH = re.compile(r"catch\s*\{\s*\}", re.MULTILINE)
MUTABLE_STATIC = re.compile(
    r"^\s*(?:public\s+|private\s+|internal\s+|fileprivate\s+)?static\s+var\s+",
    re.MULTILINE,
)

@dataclass(frozen=True)
class Finding:
    severity: str
    rule: str
    path: str
    line: int
    message: str
    excerpt: str


def current_git_head() -> str | None:
    try:
        return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    except Exception:
        return None


def git_tracked_files() -> list[Path]:
    try:
        output = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
        return [ROOT / item for item in output.decode("utf-8").split("\0") if item]
    except Exception:
        return [
            path for path in ROOT.rglob("*")
            if path.is_file() and not any(part in EXCLUDED_PARTS for part in path.parts)
        ]


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def is_text_candidate(path: Path) -> bool:
    rel = relative(path)
    if any(part in EXCLUDED_PARTS for part in Path(rel).parts):
        return False
    return path.suffix.lower() in TEXT_SUFFIXES or path.name in {
        "Package.swift", "Package.resolved", "Dockerfile", "Makefile", ".gitignore",
    }


def read_text(path: Path) -> str | None:
    try:
        raw = path.read_bytes()
    except OSError:
        return None
    if b"\x00" in raw:
        return None
    for encoding in ("utf-8", "utf-8-sig"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            continue
    return None


def add(findings: list[Finding], severity: str, rule: str, path: str, line: int,
        message: str, excerpt: str) -> None:
    findings.append(Finding(severity, rule, path, max(1, line), message, excerpt.strip()[:240]))


def line_number(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def has_safety_comment(lines: list[str], index: int) -> bool:
    context = "\n".join(lines[max(0, index - 4):index + 1]).upper()
    return "SAFETY:" in context and any(word in context for word in ("THREAD", "ACTOR", "IMMUTABLE"))


def scan_common(path: str, text: str, findings: list[Finding]) -> None:
    start, middle, end = MERGE_START.search(text), MERGE_MIDDLE.search(text), MERGE_END.search(text)
    if start and middle and end:
        add(findings, "error", "merge-conflict-marker", path, line_number(text, start.start()),
            "Unresolved merge conflict marker.", start.group(0))
    for name, pattern in SECRET_PATTERNS:
        for match in pattern.finditer(text):
            add(findings, "error", "embedded-secret", path, line_number(text, match.start()),
                f"{name} appears embedded in the repository.", match.group(0))
    for match in ABSOLUTE_USER_PATH.finditer(text):
        severity = "warning" if path.startswith(("Tests/", "Documentation/", "CLAUDE.md")) else "error"
        add(findings, severity, "personal-absolute-path", path, line_number(text, match.start()),
            "Personal absolute path makes builds non-portable.", match.group(0))
    for index, line in enumerate(text.splitlines(), start=1):
        if line != line.rstrip(" \t"):
            add(findings, "warning", "trailing-whitespace", path, index, "Trailing whitespace.", line)
        if len(line) > 240 and not path.endswith((".json", ".strings", ".md")):
            add(findings, "warning", "very-long-line", path, index,
                "Line exceeds 240 characters and is hard to review.", line)


def scan_swift(path: str, text: str, findings: list[Finding]) -> None:
    is_production = path.startswith(SOURCE_PREFIXES) and not path.startswith(TEST_PREFIXES)
    lines = text.splitlines()
    if is_production:
        for rule, pattern, message in SWIFT_HARD_ERRORS:
            for match in pattern.finditer(text):
                add(findings, "error", rule, path, line_number(text, match.start()), message, match.group(0))
    for rule, pattern, message in SWIFT_WARNINGS:
        for match in pattern.finditer(text):
            if rule == "fatal-production" and not is_production:
                continue
            add(findings, "warning", rule, path, line_number(text, match.start()), message, match.group(0))
    for index, line in enumerate(lines):
        if "@unchecked Sendable" in line and not has_safety_comment(lines, index):
            add(findings, "warning", "unchecked-sendable-review", path, index + 1,
                "@unchecked Sendable requires a manual review of every mutable field and callback.", line)
        if "nonisolated(unsafe)" in line and is_production and not has_safety_comment(lines, index):
            known_spotify_bridge = (
                path == "Sources/MixPilotApp/SpotifyLibraryCoordinator.swift"
                and "private final class SpotifyAuthenticationPresentationContext" in text
                and "nonisolated(unsafe) private let anchor: ASPresentationAnchor" in text
                and "nonisolated func presentationAnchor" in text
            )
            if known_spotify_bridge:
                add(findings, "warning", "spotify-presentation-bridge-review", path, index + 1,
                    "Spotify presentation anchor is immutable but uses an unsafe isolation bridge; keep the runtime regression test.", line)
            else:
                add(findings, "error", "unsafe-concurrency-without-proof", path, index + 1,
                    "nonisolated(unsafe) requires a nearby SAFETY comment proving immutability/thread safety.", line)
    for match in EMPTY_CATCH.finditer(text):
        add(findings, "error", "empty-catch", path, line_number(text, match.start()),
            "Empty catch block silently hides every failure.", match.group(0))
    for match in FORCE_UNWRAP_CANDIDATE.finditer(text):
        add(findings, "warning", "force-unwrap-candidate", path, line_number(text, match.start()),
            "Potential force unwrap; verify a local invariant proves safety.", match.group(0))
    for match in MUTABLE_STATIC.finditer(text):
        add(findings, "warning", "mutable-global-state", path, line_number(text, match.start()),
            "Mutable static state needs actor or lock protection.", match.group(0))
    if is_production:
        for rule, pattern, message in INSECURE_TRANSPORT_PATTERNS:
            for match in pattern.finditer(text):
                add(findings, "error", rule, path, line_number(text, match.start()), message, match.group(0))
    if text.count("GeometryReader") > 3:
        add(findings, "warning", "geometry-reader-density", path, 1,
            "Multiple GeometryReader uses may cause layout churn; profile this view.", f"count={text.count('GeometryReader')}")
    if "@MainActor" in text and re.search(r"\b(?:Data|String)\s*\(\s*contentsOf:", text):
        add(findings, "warning", "mainactor-blocking-io", path, 1,
            "A @MainActor file performs synchronous file I/O.", "Data/String(contentsOf:)")


def scan_shell(path: str, text: str, findings: list[Finding]) -> None:
    if path.startswith("Scripts/") and not text.startswith("#!"):
        add(findings, "error", "missing-shebang", path, 1, "Executable script is missing a shebang.", text.splitlines()[0] if text else "")
    if path.startswith("Scripts/") and "set -euo pipefail" not in text:
        add(findings, "error", "weak-shell-options", path, 1, "Release/support scripts must enable set -euo pipefail.", "")
    for rule, pattern, message in SHELL_HARD_ERRORS:
        for match in pattern.finditer(text):
            add(findings, "error", rule, path, line_number(text, match.start()), message, match.group(0))
    for rule, pattern, message in INSECURE_TRANSPORT_PATTERNS:
        for match in pattern.finditer(text):
            context = text[max(0, match.start() - 80):match.end() + 80]
            if "http://www.apple.com/DTDs/" in context:
                continue
            add(findings, "error", rule, path, line_number(text, match.start()), message, match.group(0))


def scan_sql(path: str, text: str, findings: list[Finding]) -> None:
    lower = text.lower()
    for match in re.finditer(r"\bgrant\s+all\b", lower):
        add(findings, "error", "sql-grant-all", path, line_number(text, match.start()),
            "GRANT ALL violates least privilege.", text.splitlines()[line_number(text, match.start()) - 1])
    function_pattern = re.compile(
        r"create\s+(?:or\s+replace\s+)?function\b(?P<body>.*?)(?:\$\$\s*;)",
        re.IGNORECASE | re.DOTALL,
    )
    for function_match in function_pattern.finditer(text):
        body = function_match.group("body").lower()
        if "security definer" in body and "set search_path" not in body:
            offset = function_match.start() + body.index("security definer")
            add(findings, "error", "security-definer-search-path", path, line_number(text, offset),
                "SECURITY DEFINER function must pin search_path.", "security definer")
    for match in re.finditer(r"\busing\s*\(\s*true\s*\)", lower):
        add(findings, "warning", "permissive-rls-policy", path, line_number(text, match.start()),
            "RLS policy USING (true) deserves explicit review.", "USING (true)")


def scan_plist(path: Path, rel: str, findings: list[Finding]) -> None:
    try:
        payload = plistlib.loads(path.read_bytes())
    except Exception as error:
        add(findings, "error", "invalid-plist", rel, 1, f"Invalid property list: {error}", "")
        return
    if rel.endswith("Info.plist"):
        ats = payload.get("NSAppTransportSecurity", {})
        if isinstance(ats, dict) and ats.get("NSAllowsArbitraryLoads") is True:
            add(findings, "error", "ats-arbitrary-loads", rel, 1, "NSAllowsArbitraryLoads must not be enabled.", "NSAllowsArbitraryLoads")
    if rel.endswith("PrivacyInfo.xcprivacy") and not isinstance(payload, dict):
        add(findings, "error", "invalid-privacy-manifest", rel, 1, "Privacy manifest root must be a dictionary.", "")


def scan_repository_invariants(paths: list[Path], findings: list[Finding]) -> None:
    rels = [relative(path) for path in paths]
    for rel in rels:
        parts = set(Path(rel).parts)
        if parts & GENERATED_PATH_PARTS or rel.endswith((".xcuserstate", ".DS_Store")):
            add(findings, "error", "tracked-generated-file", rel, 1, "Generated/user-specific file is tracked.", rel)
    migration_prefixes: dict[str, str] = {}
    for rel in rels:
        if rel.startswith("supabase/migrations/") and rel.endswith(".sql"):
            prefix = Path(rel).name.split("_", 1)[0]
            previous = migration_prefixes.get(prefix)
            if previous:
                add(findings, "error", "duplicate-migration-prefix", rel, 1, f"Migration timestamp collides with {previous}.", prefix)
            migration_prefixes[prefix] = rel
    swift_files = [rel for rel in rels if rel.endswith(".swift")]
    if "Mobile/MixPilotRemote/Sources/RemoteConnection.swift" in swift_files:
        info = ROOT / "Mobile/MixPilotRemote/Sources/Info.plist"
        if not info.exists():
            add(findings, "error", "missing-ios-info-plist", "Mobile/MixPilotRemote", 1, "iOS Remote has no Info.plist.", "")
        else:
            try:
                payload = plistlib.loads(info.read_bytes())
                if not payload.get("NSLocalNetworkUsageDescription"):
                    add(findings, "error", "missing-local-network-purpose", relative(info), 1, "Bonjour app needs NSLocalNetworkUsageDescription.", "")
                if "_mixpilot._tcp" not in payload.get("NSBonjourServices", []):
                    add(findings, "error", "missing-bonjour-service", relative(info), 1, "Info.plist does not register _mixpilot._tcp.", "")
            except Exception:
                pass
    uses_user_defaults_mobile = any(
        "UserDefaults" in (read_text(ROOT / rel) or "") or "@AppStorage" in (read_text(ROOT / rel) or "")
        for rel in swift_files if rel.startswith("Mobile/MixPilotRemote/")
    )
    privacy = ROOT / "Mobile/MixPilotRemote/Sources/PrivacyInfo.xcprivacy"
    if uses_user_defaults_mobile and not privacy.exists():
        add(findings, "error", "missing-ios-privacy-manifest", "Mobile/MixPilotRemote/Sources", 1,
            "The iOS app uses UserDefaults but has no PrivacyInfo.xcprivacy declaring an approved reason.", "")
    if privacy.exists():
        try:
            payload = plistlib.loads(privacy.read_bytes())
            reasons = {
                entry.get("NSPrivacyAccessedAPIType"): set(entry.get("NSPrivacyAccessedAPITypeReasons", []))
                for entry in payload.get("NSPrivacyAccessedAPITypes", []) if isinstance(entry, dict)
            }
            if uses_user_defaults_mobile and "CA92.1" not in reasons.get("NSPrivacyAccessedAPICategoryUserDefaults", set()):
                add(findings, "error", "missing-userdefaults-reason", relative(privacy), 1,
                    "Privacy manifest must declare CA92.1 for app-only UserDefaults.", "")
        except Exception as error:
            add(findings, "error", "invalid-privacy-manifest", relative(privacy), 1,
                f"Privacy manifest could not be parsed: {error}", "")
    project_yml = ROOT / "Mobile/MixPilotRemote/project.yml"
    if project_yml.exists():
        text = read_text(project_yml) or ""
        if "SWIFT_VERSION: 6.0" not in text:
            add(findings, "error", "ios-swift-version", relative(project_yml), 1, "iOS target must compile in Swift 6 mode.", "")
        if "ENABLE_USER_SCRIPT_SANDBOXING: YES" not in text:
            add(findings, "error", "ios-script-sandbox", relative(project_yml), 1, "User script sandboxing must stay enabled.", "")
    package = ROOT / "Package.swift"
    if package.exists():
        text = read_text(package) or ""
        if ".branch(" in text or ".revision(" in text:
            add(findings, "warning", "unpinned-package-dependency", relative(package), 1,
                "Package dependency is pinned to a branch/revision rather than a stable version.", "")
        if "swift-tools-version: 6.0" not in text:
            add(findings, "error", "swift-tools-version", relative(package), 1, "Package must use Swift tools 6.0.", "")


def write_reports(findings: list[Finding], files: int, lines: int, git_head: str | None,
                  output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    ordered = sorted(findings, key=lambda item: (0 if item.severity == "error" else 1, item.path, item.line, item.rule))
    payload = {
        "summary": {
            "git_head": git_head,
            "files_scanned": files,
            "lines_scanned": lines,
            "errors": sum(item.severity == "error" for item in ordered),
            "warnings": sum(item.severity == "warning" for item in ordered),
        },
        "findings": [asdict(item) for item in ordered],
    }
    (output_dir / "ultimate-audit.json").write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    rows = [
        "# MixPilot ultimate repository audit", "", f"- Git head: `{git_head or 'unknown'}`",
        f"- Files scanned: {files}", f"- Lines scanned: {lines}",
        f"- Errors: {payload['summary']['errors']}", f"- Warnings: {payload['summary']['warnings']}", "",
    ]
    for item in ordered:
        rows.extend([
            f"## {item.severity.upper()} · {item.rule}", f"- Location: `{item.path}:{item.line}`",
            f"- {item.message}", f"- Excerpt: `{item.excerpt.replace('`', chr(39))}`" if item.excerpt else "", "",
        ])
    (output_dir / "ultimate-audit.md").write_text("\n".join(rows), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", default="ultimate-audit")
    parser.add_argument("--fail-on-warnings", action="store_true")
    args = parser.parse_args()
    tracked = git_tracked_files()
    findings: list[Finding] = []
    files_scanned = 0
    lines_scanned = 0
    for path in tracked:
        if not path.exists() or not is_text_candidate(path):
            continue
        rel = relative(path)
        text = read_text(path)
        if text is None:
            if path.suffix.lower() in TEXT_SUFFIXES:
                add(findings, "error", "unreadable-text-file", rel, 1, "Expected text file is binary or not UTF-8.", "")
            continue
        files_scanned += 1
        lines_scanned += text.count("\n") + (1 if text else 0)
        scan_common(rel, text, findings)
        suffix = path.suffix.lower()
        if suffix == ".swift": scan_swift(rel, text, findings)
        elif suffix in {".sh", ".bash", ".zsh"}: scan_shell(rel, text, findings)
        elif suffix == ".sql": scan_sql(rel, text, findings)
        if suffix in {".plist", ".xcprivacy"}: scan_plist(path, rel, findings)
    scan_repository_invariants(tracked, findings)
    git_head = current_git_head()
    write_reports(findings, files_scanned, lines_scanned, git_head, ROOT / args.output_dir)
    errors = [item for item in findings if item.severity == "error"]
    warnings = [item for item in findings if item.severity == "warning"]
    print(f"Ultimate audit scanned {files_scanned} files / {lines_scanned} lines at {git_head or 'unknown HEAD'}: {len(errors)} errors, {len(warnings)} warnings.")
    for item in sorted(errors + warnings, key=lambda value: (0 if value.severity == "error" else 1, value.path, value.line)):
        print(f"{item.severity.upper()} {item.path}:{item.line} [{item.rule}] {item.message}")
    return 1 if errors or (args.fail_on_warnings and warnings) else 0


if __name__ == "__main__":
    raise SystemExit(main())
