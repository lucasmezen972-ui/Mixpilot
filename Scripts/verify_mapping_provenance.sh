#!/usr/bin/env bash
set -euo pipefail

REPOSITORY="lucasmezen972-ui/Mixpilot"
COMMIT_SHA="ac6a1a87e41d5accedcf1a8400ce2cc334e9af1b"
MANIFEST_PATH="MappingReleases/rekordbox/mapping-v450.json"
EXPECTED_SHA256="886517fb36fefc0124924405bd7d90fc91356b3af989161255be3ff365fa09e0"
OUTPUT="${1:-mapping-v450-provenance.json}"
URL="https://raw.githubusercontent.com/${REPOSITORY}/${COMMIT_SHA}/${MANIFEST_PATH}"

curl --fail-with-body --silent --show-error \
  --location \
  --header "Accept: application/json" \
  "$URL" > "$OUTPUT"

ACTUAL_SHA256="$(shasum -a 256 "$OUTPUT" | awk '{print $1}')"
if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
  echo "Manifest digest mismatch: expected ${EXPECTED_SHA256}, got ${ACTUAL_SHA256}" >&2
  exit 1
fi

python3 - "$OUTPUT" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as handle:
    manifest = json.load(handle)
expected = {
    'repository': 'lucasmezen972-ui/Mixpilot',
    'release_id': '036df828-bd1d-4842-aa86-c2ef34ad30c6',
    'mapping_version': 450,
    'profile_sha256': 'f66339b28e9bdeee29fc90d53d029086396de41aa427580386617f95dfc321af',
    'generated_preset_sha256': '18854a58a90132fc8da7c40dfb8ab4d86c32f412b19cc2bd0ca325dee65587af',
}
for key, value in expected.items():
    if manifest.get(key) != value:
        raise SystemExit(f'Invalid manifest field {key}: {manifest.get(key)!r}')
validation = manifest.get('validation', {})
for key in ('unit_tests', 'simulation_50', 'simulation_250', 'release_build', 'dmg_checksum'):
    if validation.get(key) != 'passed':
        raise SystemExit(f'Incomplete manifest validation: {key}')
print(json.dumps({'manifest_sha256': 'verified', 'mapping_version': 450}, sort_keys=True))
PY
