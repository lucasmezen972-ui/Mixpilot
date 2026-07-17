#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_ROOT = ROOT / "Sources" / "MixPilotHelp" / "Resources"
LANGUAGES = ("fr", "en", "es")
KEY_PATTERN = re.compile(r'^\s*"([^"]+)"\s*=\s*"(?:[^"\\]|\\.)*"\s*;\s*$', re.MULTILINE)
USED_REMOTE_KEY_PATTERN = re.compile(r'RemoteLocalizedCopy\.(?:text|format)\("([^"]+)"')


def keys_for(language: str, table: str) -> set[str]:
    path = RESOURCE_ROOT / f"{language}.lproj" / f"{table}.strings"
    if not path.is_file():
        raise SystemExit(f"Missing localization table: {path}")
    text = path.read_text(encoding="utf-8")
    keys = KEY_PATTERN.findall(text)
    if len(keys) != len(set(keys)):
        raise SystemExit(f"Duplicate localization key in {path}")
    return set(keys)


def require_parity(table: str) -> set[str]:
    reference = keys_for("fr", table)
    if not reference:
        raise SystemExit(f"French {table} localization is empty")
    for language in LANGUAGES[1:]:
        current = keys_for(language, table)
        missing = sorted(reference - current)
        extra = sorted(current - reference)
        if missing or extra:
            raise SystemExit(
                f"{table} localization mismatch for {language}: "
                f"missing={missing}, extra={extra}"
            )
    return reference


help_keys = require_parity("Localizable")
remote_keys = require_parity("Remote")

required_help_ui_keys = {
    "help.center.title",
    "help.center.search",
    "help.center.no_result",
    "help.center.all_categories",
    "help.center.offline_note",
    "help.center.close",
}
missing_help_ui = sorted(required_help_ui_keys - help_keys)
if missing_help_ui:
    raise SystemExit(f"Missing help UI keys: {missing_help_ui}")

required_remote_keys = {
    "remote.error.protocol_incompatible",
    "remote.error.reconnect_failed",
    "remote.ui.safe_fade_title",
    "remote.ui.manual_title",
    "remote.ui.take_control",
    "remote.demo.command_simulated",
}
missing_remote = sorted(required_remote_keys - remote_keys)
if missing_remote:
    raise SystemExit(f"Missing critical Remote keys: {missing_remote}")

article_source = (ROOT / "Sources" / "MixPilotHelp" / "HelpCenter.swift").read_text(encoding="utf-8")
article_ids = re.findall(r'article\("([^"]+)"', article_source)
if len(article_ids) != 11 or len(article_ids) != len(set(article_ids)):
    raise SystemExit(f"Expected 11 unique help articles, found {article_ids}")

remote_sources = [
    ROOT / "Mobile" / "MixPilotRemote" / "Sources" / "RootView.swift",
    ROOT / "Mobile" / "MixPilotRemote" / "Sources" / "RemoteConnection.swift",
    ROOT / "Mobile" / "MixPilotRemote" / "Sources" / "RemotePresentationCopy.swift",
]
used_remote_keys: set[str] = set()
for source in remote_sources:
    if not source.is_file():
        raise SystemExit(f"Missing localized Remote source: {source}")
    used_remote_keys.update(USED_REMOTE_KEY_PATTERN.findall(source.read_text(encoding="utf-8")))

undefined = sorted(used_remote_keys - remote_keys)
if undefined:
    raise SystemExit(f"Remote source uses undefined localization keys: {undefined}")

print(
    "Localization consistency: OK "
    f"({len(help_keys)} help keys, {len(remote_keys)} Remote keys, "
    f"{len(article_ids)} articles)"
)
