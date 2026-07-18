#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"
SHA_REF = re.compile(r"^\s*-?\s*uses:\s*([^\s@]+)@([0-9a-f]{40})(?:\s+#.*)?$")
USES = re.compile(r"^\s*-?\s*uses:\s*([^\s@]+)@([^\s#]+)")

failures: list[str] = []
for workflow in sorted(WORKFLOWS.glob("*.yml")) + sorted(WORKFLOWS.glob("*.yaml")):
    text = workflow.read_text(encoding="utf-8")
    for number, line in enumerate(text.splitlines(), start=1):
        match = USES.match(line)
        if match and not SHA_REF.match(line):
            failures.append(
                f"{workflow.relative_to(ROOT)}:{number}: action must use a full 40-character commit SHA: {line.strip()}"
            )
    if "brew install xcodegen" in text:
        failures.append(
            f"{workflow.relative_to(ROOT)}: mutable Homebrew XcodeGen install is forbidden; use Scripts/install_xcodegen.sh"
        )

package = (ROOT / "Package.swift").read_text(encoding="utf-8")
if 'url: "https://github.com/apple/swift-crypto.git",\n        exact: "3.15.1"' not in package:
    failures.append("Package.swift: swift-crypto must remain pinned exactly to 3.15.1")
if 'url: "https://github.com/supabase/supabase-swift.git",\n        exact: "2.46.0"' not in package:
    failures.append("Package.swift: supabase-swift must remain pinned exactly to 2.46.0")

installer = (ROOT / "Scripts" / "install_xcodegen.sh").read_text(encoding="utf-8")
if 'XCODEGEN_COMMIT="24c60c314676f5fa176d7659c6679927db21f255"' not in installer:
    failures.append("Scripts/install_xcodegen.sh: XcodeGen commit changed without policy update")

if failures:
    print("CI dependency pinning check failed:", file=sys.stderr)
    for failure in failures:
        print(f"- {failure}", file=sys.stderr)
    raise SystemExit(1)

print("CI dependency pinning: OK")
