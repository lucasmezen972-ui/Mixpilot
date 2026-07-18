#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

manifest_json="$(mktemp)"
trap 'rm -f "$manifest_json"' EXIT

swift package dump-package > "$manifest_json"

python3 - "$manifest_json" "$(uname -s)" <<'PY'
import json
import sys
from pathlib import Path

path, host = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as handle:
    package = json.load(handle)

targets = {target["name"] for target in package.get("targets", [])}
products = {product["name"] for product in package.get("products", [])}

required_shared_targets = {
    "MixPilotCore",
    "MixPilotHelp",
    "MixPilotRemoteProtocol",
    "MixPilotSimulatorCLI",
    "MixPilotMappingPublisherCLI",
    "MixPilotCoreTests",
    "MixPilotHelpTests",
    "MixPilotRemoteProtocolTests",
}
required_shared_products = {
    "MixPilotCore",
    "MixPilotHelp",
    "MixPilotRemoteProtocol",
    "MixPilotSimulatorCLI",
    "MixPilotMappingPublisherCLI",
}

missing_targets = required_shared_targets - targets
missing_products = required_shared_products - products
if missing_targets or missing_products:
    raise SystemExit(
        "Package manifest is missing shared entries: "
        f"targets={sorted(missing_targets)}, products={sorted(missing_products)}"
    )

core_target = next(
    (target for target in package.get("targets", []) if target.get("name") == "MixPilotCore"),
    None,
)
if core_target is None:
    raise SystemExit("MixPilotCore target is missing")

core_products = {
    dependency.get("product", [None])[0]
    for dependency in core_target.get("dependencies", [])
    if "product" in dependency
}
if "Crypto" not in core_products:
    raise SystemExit("MixPilotCore must depend on Swift Crypto for Linux-compatible SHA-256 support.")

help_target = next(
    (target for target in package.get("targets", []) if target.get("name") == "MixPilotHelp"),
    None,
)
if help_target is None or not help_target.get("resources"):
    raise SystemExit("MixPilotHelp must process its offline localization resources.")

platform_names = {platform.get("platformName") for platform in package.get("platforms", [])}
if not {"macos", "ios"}.issubset(platform_names):
    raise SystemExit("The shared help product must be available to both macOS and iOS.")


def remote_url(dependency: dict) -> str:
    source_controls = dependency.get("sourceControl") or []
    if not source_controls:
        return ""
    location = source_controls[0].get("location") or {}
    remotes = location.get("remote") or []
    if not remotes:
        return ""
    return remotes[0].get("urlString", "")


mac_targets = {
    "MixPilotMIDI",
    "MixPilotSystem",
    "MixPilotRuntime",
    "MixPilotRemoteBridge",
    "MixPilotHardwareProbeCLI",
    "MixPilotApp",
    "MixPilotRemoteBridgeTests",
    "MixPilotSystemTests",
    "MixPilotRuntimeTests",
}
mac_products = {
    "MixPilotMIDI",
    "MixPilotSystem",
    "MixPilotRuntime",
    "MixPilotRemoteBridge",
    "MixPilotAutopilot",
    "MixPilotHardwareProbeCLI",
}

# These filenames are the current safety-critical runtime suite. Keep this list
# aligned with check_runtime_safety.sh so renamed or removed tests cannot make the
# package graph check fail for stale historical names.
runtime_test_sources = {
    "BackendCommandQueueSafetyTests.swift",
    "BackendCommandCadenceTests.swift",
    "TransitionTriggerVerificationTests.swift",
    "TransitionFrameCoalescingTests.swift",
}

if host == "Darwin":
    missing_mac_targets = mac_targets - targets
    missing_mac_products = mac_products - products
    if missing_mac_targets or missing_mac_products:
        raise SystemExit(
            "Package manifest is missing macOS entries: "
            f"targets={sorted(missing_mac_targets)}, products={sorted(missing_mac_products)}"
        )

    runtime_test_dir = Path("Tests/MixPilotRuntimeTests")
    present_runtime_tests = {path.name for path in runtime_test_dir.glob("*.swift")}
    missing_runtime_tests = runtime_test_sources - present_runtime_tests
    if missing_runtime_tests:
        raise SystemExit(
            "MixPilotRuntimeTests is missing expected runtime safety sources: "
            f"{sorted(missing_runtime_tests)}"
        )

    core_mock = Path("Tests/MixPilotCoreTests/MockDJBackends.swift")
    if not core_mock.is_file():
        raise SystemExit("The multi-backend core mock file is missing: Tests/MixPilotCoreTests/MockDJBackends.swift")
else:
    unexpected = mac_targets & targets
    if unexpected:
        raise SystemExit(
            "The cross-platform graph unexpectedly contains macOS-only targets: "
            f"{sorted(unexpected)}"
        )
    dependency_urls = {remote_url(dependency) for dependency in package.get("dependencies", [])}
    if any("supabase-swift" in url for url in dependency_urls):
        raise SystemExit("The Linux package graph must not resolve the macOS-only Supabase dependency.")
    if not any("swift-crypto" in url for url in dependency_urls):
        raise SystemExit("The Linux package graph must resolve Swift Crypto for portable hashing.")

print(f"Package manifest consistency: OK ({host})")
PY
