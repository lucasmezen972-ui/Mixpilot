#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_ROOT = ROOT / "Sources" / "MixPilotHelp" / "Resources"
LANGUAGES = ("fr", "en", "es")
KEY_PATTERN = re.compile(r'^\s*"([^"]+)"\s*=\s*"(?:[^"\\]|\\.)*"\s*;\s*$', re.MULTILINE)


def keys_for(language: str) -> set[str]:
    path = RESOURCE_ROOT / f"{language}.lproj" / "Localizable.strings"
    if not path.is_file():
        raise SystemExit(f"Missing help localization: {path}")
    text = path.read_text(encoding="utf-8")
    keys = KEY_PATTERN.findall(text)
    if len(keys) != len(set(keys)):
        raise SystemExit(f"Duplicate localization key in {path}")
    return set(keys)


reference = keys_for("fr")
if not reference:
    raise SystemExit("French help localization is empty")

for language in LANGUAGES[1:]:
    current = keys_for(language)
    missing = sorted(reference - current)
    extra = sorted(current - reference)
    if missing or extra:
        raise SystemExit(
            f"Help localization mismatch for {language}: missing={missing}, extra={extra}"
        )

required_ui_keys = {
    "help.center.title",
    "help.center.search",
    "help.center.no_result",
    "help.center.all_categories",
    "help.center.offline_note",
    "help.center.close",
}
missing_ui = sorted(required_ui_keys - reference)
if missing_ui:
    raise SystemExit(f"Missing help UI keys: {missing_ui}")

article_source = (ROOT / "Sources" / "MixPilotHelp" / "HelpCenter.swift").read_text(encoding="utf-8")
article_ids = re.findall(r'article\("([^"]+)"', article_source)
if len(article_ids) != 11 or len(article_ids) != len(set(article_ids)):
    raise SystemExit(f"Expected 11 unique help articles, found {article_ids}")

for key in reference:
    if key.startswith("help.") and not key.strip():
        raise SystemExit("Empty help key")

print(f"Help localization consistency: OK ({len(reference)} keys, {len(article_ids)} articles)")
