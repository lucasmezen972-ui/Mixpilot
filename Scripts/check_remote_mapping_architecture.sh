#!/usr/bin/env bash
set -euo pipefail

service="Sources/MixPilotSystem/MixPilotRemoteMappingService.swift"
installer="Sources/MixPilotSystem/MixPilotRemoteMappingInstaller.swift"
coordinator="Sources/MixPilotApp/MixPilotCloudCoordinator.swift"
core="Sources/MixPilotCore/RemoteMappingUpdates.swift"
provenance="Sources/MixPilotCore/MappingProvenance.swift"
publisher="Sources/MixPilotMappingPublisherCLI/main.swift"
migration="supabase/migrations/20260717173000_generic_remote_mapping_versions.sql"

for file in "$service" "$installer" "$coordinator" "$core" "$provenance" "$publisher" "$migration"; do
  test -f "$file" || {
    echo "Remote mapping architecture check failed: missing $file" >&2
    exit 1
  }
done

if grep -n 'value: "eq\.rekordbox"' "$service"; then
  echo 'Remote mapping architecture check failed: cloud queries still hardcode rekordbox' >&2
  exit 1
fi

if grep -n 'backend\.identifier == \.rekordbox' "$coordinator"; then
  echo 'Remote mapping architecture check failed: the cloud coordinator still excludes djay or Serato' >&2
  exit 1
fi

grep -q 'backend: DJBackendIdentifier' "$service" || {
  echo 'Remote mapping architecture check failed: service methods do not receive the active backend' >&2
  exit 1
}

grep -q 'softwareVersion: String?' "$service" || {
  echo 'Remote mapping architecture check failed: service methods still use a rekordbox-only version parameter' >&2
  exit 1
}

grep -q 'case \.djay, \.serato' "$core" || {
  echo 'Remote mapping architecture check failed: profile-only validation for djay and Serato is missing' >&2
  exit 1
}

grep -q 'case \.rekordboxCSV' "$installer" || {
  echo 'Remote mapping architecture check failed: rekordbox CSV persistence is missing' >&2
  exit 1
}

grep -q 'generatedArtifactURL: URL?' "$installer" || {
  echo 'Remote mapping architecture check failed: generated files must remain optional for profile-only backends' >&2
  exit 1
}

grep -q 'generatedArtifactSHA256: String?' "$provenance" || {
  echo 'Remote mapping architecture check failed: provenance still requires a generated CSV hash' >&2
  exit 1
}

grep -q 'argument("--backend")' "$publisher" || {
  echo 'Remote mapping architecture check failed: publisher CLI cannot select a backend' >&2
  exit 1
}

grep -q 'minimum_software_version' "$migration" || {
  echo 'Remote mapping architecture check failed: generic software-version migration is missing' >&2
  exit 1
}

grep -q 'generated_artifact_sha256' "$migration" || {
  echo 'Remote mapping architecture check failed: generic artifact digest migration is missing' >&2
  exit 1
}

test -f Tests/MixPilotCoreTests/RemoteMappingMultiBackendTests.swift || {
  echo 'Remote mapping architecture check failed: Core multi-backend tests are missing' >&2
  exit 1
}

grep -q 'djayProfileDoesNotInventGeneratedArtifact' Tests/MixPilotCoreTests/RemoteMappingMultiBackendTests.swift || {
  echo 'Remote mapping architecture check failed: profile-only backend behavior is not tested' >&2
  exit 1
}

echo 'Remote mapping multi-backend architecture: OK'
