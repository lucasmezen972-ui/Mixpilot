#!/usr/bin/env bash
set -euo pipefail

store=Sources/MixPilotCore/DJCommandValidationStore.swift
tests=Tests/MixPilotCoreTests/DJCommandValidationEvidenceTests.swift

for pattern in operatingSystemVersion hardwareModel appBuild platformContext; do
  grep -q "$pattern" "$store" || {
    echo "Validation context check failed: missing $pattern" >&2
    exit 1
  }
done

grep -q 'key.matches(context)' "$store" || {
  echo 'Validation context check failed: device evidence is not matched to the current platform' >&2
  exit 1
}

grep -q 'Legacy confirmation without platform fields' "$tests" || {
  echo 'Validation context check failed: legacy evidence migration test is missing' >&2
  exit 1
}

grep -q 'Evidence is rejected after the platform context changes' "$tests" || {
  echo 'Validation context check failed: platform invalidation tests are missing' >&2
  exit 1
}

echo 'Validation context consistency: OK'
