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

path, host = sys.argv[1], sys.argv[2]
with open(path, encoding="utf-8") as handle:
    package = json.load(handle)

targets = {target["name"] for target in package.get("targets", [])}
products = {product["name"] for product in package.get("products", [])}

required_shared_targets = {
    "MixPilotCore",
    "MixPilotRemoteProtocol",
    "MixPilotSimulatorCLI",
    "MixPilotMappingPublisherCLI",
    "MixPilotCoreTests",
    "MixPilotRemoteProtocolTests",
}
required_shared_products = {
    "MixPilotCore",
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
mac_products = {"MixPilotAutopilot", "MixPilotHardwareProbeCLI"}

if host == "Darwin":
    missing_mac_targets = mac_targets - targets
    missing_mac_products = mac_products - products
    if missing_mac_targets or missing_mac_products:
        raise SystemExit(
            "Package manifest is missing macOS entries: "
            f"targets={sorted(missing_mac_targets)}, products={sorted(missing_mac_products)}"
        )
else:
    unexpected = mac_targets & targets
    if unexpected:
        raise SystemExit(
            "The cross-platform graph unexpectedly contains macOS-only targets: "
            f"{sorted(unexpected)}"
        )
    dependency_urls = {
        dependency.get("sourceControl", [{}])[0].get("location", {}).get("remote", {}).get("urlString", "")
        for dependency in package.get("dependencies", [])
    }
    if any("supabase-swift" in url for url in dependency_urls):
        raise SystemExit("The Linux package graph must not resolve the macOS-only Supabase dependency.")

print(f"Package manifest consistency: OK ({host})")
PY
