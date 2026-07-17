#!/usr/bin/env python3
"""Validate MixPilot localization catalogs without requiring Xcode.

The audit is intentionally portable so it can run locally or in a manual CI job.
It verifies key parity, duplicate keys, placeholder compatibility, and literal
localized-key references used by the shared help, macOS app and iPhone Remote.
"""
from __future__ import annotations

import collections
import pathlib
import re
import sys
from dataclasses import dataclass

ROOT = pathlib.Path(__file__).resolve().parents[1]
RESOURCE_ROOT = ROOT / "Sources" / "MixPilotHelp" / "Resources"
LANGUAGES = ("fr", "en", "es")
TABLES = (
    "Localizable.strings",
    "Remote.strings",
    "Workspace.strings",
    "Commands.strings",
    "Status.strings",
    "Technical.strings",
)

ENTRY_RE = re.compile(r'^\s*"((?:\\.|[^"\\])+)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;\s*$')
PLACEHOLDER_RE = re.compile(r'%(?:\d+\$)?(?:[-+0 #]*)(?:\d+|\*)?(?:\.\d+|\.\*)?(?:hh|h|ll|l|L|z|j|t)?[@aAcCdDeEfFgGiIoOsSuUxX]')
REFERENCE_PATTERNS = (
    re.compile(r'RemoteLocalizedCopy\.(?:text|format)\(\s*"([^"]+)"'),
    re.compile(r'AppLocalizedCopy\.(?:text|format|workspace|workspaceFormat|command|commandFormat|status|statusFormat|technical|technicalFormat)\(\s*"([^"]+)"'),
    re.compile(r'catalog\.localized\(\s*"([^"]+)"'),
    re.compile(r'localized\(\s*"([^"]+)"'),
)
STABLE_KEY_RE = re.compile(r'"((?:app|commands|help|remote|status|technical|workspace)\.[A-Za-z0-9_.-]+)"')
SOURCE_ROOTS = (
    ROOT / "Mobile" / "MixPilotRemote" / "Sources",
    ROOT / "Sources" / "MixPilotApp",
    ROOT / "Sources" / "MixPilotHelp",
    ROOT / "Tests" / "MixPilotHelpTests",
)


@dataclass(frozen=True)
class Catalog:
    path: pathlib.Path
    values: dict[str, str]


def parse_catalog(path: pathlib.Path) -> Catalog:
    values: dict[str, str] = {}
    duplicates: list[str] = []

    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        stripped = raw_line.strip()
        if not stripped or stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
            continue
        match = ENTRY_RE.match(raw_line)
        if not match:
            raise ValueError(f"{path.relative_to(ROOT)}:{line_number}: unsupported .strings syntax")
        key, value = match.groups()
        if key in values:
            duplicates.append(key)
        values[key] = value

    if duplicates:
        joined = ", ".join(sorted(set(duplicates)))
        raise ValueError(f"{path.relative_to(ROOT)}: duplicate keys: {joined}")
    return Catalog(path=path, values=values)


def normalized_placeholders(value: str) -> collections.Counter[str]:
    placeholders = []
    for token in PLACEHOLDER_RE.findall(value.replace("%%", "")):
        placeholders.append(re.sub(r'%\d+\$', "%", token))
    return collections.Counter(placeholders)


def collect_literal_references() -> dict[str, set[pathlib.Path]]:
    references: dict[str, set[pathlib.Path]] = collections.defaultdict(set)
    for source_root in SOURCE_ROOTS:
        if not source_root.exists():
            continue
        for path in source_root.rglob("*.swift"):
            text = path.read_text(encoding="utf-8")
            relative_path = path.relative_to(ROOT)
            for pattern in REFERENCE_PATTERNS:
                for key in pattern.findall(text):
                    references[key].add(relative_path)
            for key in STABLE_KEY_RE.findall(text):
                references[key].add(relative_path)
    return references


def main() -> int:
    errors: list[str] = []
    catalogs: dict[tuple[str, str], Catalog] = {}

    for language in LANGUAGES:
        for table in TABLES:
            path = RESOURCE_ROOT / f"{language}.lproj" / table
            if not path.exists():
                errors.append(f"missing catalog: {path.relative_to(ROOT)}")
                continue
            try:
                catalogs[(language, table)] = parse_catalog(path)
            except ValueError as exc:
                errors.append(str(exc))

    for table in TABLES:
        available = {language: catalogs[(language, table)] for language in LANGUAGES if (language, table) in catalogs}
        if len(available) != len(LANGUAGES):
            continue
        reference_keys = set(available["fr"].values)
        for language, catalog in available.items():
            keys = set(catalog.values)
            missing = sorted(reference_keys - keys)
            extra = sorted(keys - reference_keys)
            if missing:
                errors.append(f"{catalog.path.relative_to(ROOT)} missing keys: {', '.join(missing)}")
            if extra:
                errors.append(f"{catalog.path.relative_to(ROOT)} extra keys: {', '.join(extra)}")

        for key in sorted(reference_keys):
            expected = normalized_placeholders(available["fr"].values[key])
            for language in LANGUAGES[1:]:
                actual = normalized_placeholders(available[language].values[key])
                if actual != expected:
                    errors.append(
                        f"placeholder mismatch for {key}: fr={dict(expected)} {language}={dict(actual)}"
                    )

    all_keys = set()
    for catalog in catalogs.values():
        all_keys.update(catalog.values)
    references = collect_literal_references()
    for key, paths in sorted(references.items()):
        if key not in all_keys:
            locations = ", ".join(str(path) for path in sorted(paths))
            errors.append(f"missing localized key {key} referenced by {locations}")

    if errors:
        print("Localization consistency audit failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    key_count = sum(len(catalog.values) for (language, _), catalog in catalogs.items() if language == "fr")
    print(
        "Localization consistency audit passed for "
        f"{len(LANGUAGES)} languages, {len(TABLES)} tables, "
        f"{key_count} reference keys and {len(references)} literal source references."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
