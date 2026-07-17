#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CURRENT_REFERENCES=(
  README.md
  Mobile/MixPilotRemote/README.md
  DEVELOPMENT_STATUS.md
  Documentation/ARCHITECTURE.md
  Documentation/PRODUCT_SPEC.md
  Documentation/PRODUCT_POSITIONING.md
  Documentation/USER_JOURNEY.md
  Documentation/TERMINOLOGY.md
  Documentation/MULTI_BACKEND_ARCHITECTURE.md
  Documentation/MULTI_BACKEND_AUDIT.md
  Documentation/MULTI_BACKEND_REFACTOR_REPORT.md
  Documentation/BACKEND_CAPABILITY_MATRIX.md
  Documentation/DJAY_INTEGRATION.md
  Documentation/REKORDBOX_INTEGRATION.md
  Documentation/SERATO_INTEGRATION.md
  Documentation/MULTI_BACKEND_VALIDATION.md
  Documentation/FINAL_VALIDATION.md
  Documentation/RC_STATUS.md
  Documentation/RELEASE.md
  Documentation/CLOUD_OBSERVABILITY.md
  Documentation/SUPABASE_ADVISOR_REPORT.md
  Documentation/REMOTE_COMPATIBILITY.md
  Documentation/IPHONE_REMOTE_BRIDGE.md
  Documentation/TECHNICAL_BENCHMARK_AND_PRIOR_ART.md
  Documentation/RELIABILITY_HARDENING_REPORT.md
)

for file in "${CURRENT_REFERENCES[@]}"; do
  test -f "$file" || {
    echo "Missing current reference document: $file" >&2
    exit 1
  }
done

for readme in README.md Mobile/MixPilotRemote/README.md; do
  grep -qi "djay Pro" "$readme" || { echo "$readme does not mention djay Pro" >&2; exit 1; }
  grep -qi "rekordbox" "$readme" || { echo "$readme does not mention rekordbox" >&2; exit 1; }
  grep -qi "Serato DJ Pro" "$readme" || { echo "$readme does not mention Serato DJ Pro" >&2; exit 1; }
done

for section in "Préparer" "Vérifier" "Live" "Avancé"; do
  grep -q "$section" README.md || { echo "Root README is missing primary area: $section" >&2; exit 1; }
done

for section in \
  "Architecture avant" \
  "Architecture après" \
  "Résultats CI" \
  "Capacités djay" \
  "Capacités rekordbox" \
  "Capacités Serato" \
  "Risques restants"; do
  grep -q "$section" Documentation/MULTI_BACKEND_REFACTOR_REPORT.md || {
    echo "The refactor report is missing section: $section" >&2
    exit 1
  }
done

for section in \
  "Security Advisor" \
  "Performance Advisor" \
  "Critère de réévaluation" \
  "Aucune migration destructive"; do
  grep -q "$section" Documentation/SUPABASE_ADVISOR_REPORT.md || {
    echo "The Supabase advisor report is missing section or decision: $section" >&2
    exit 1
  }
done

for section in \
  "Résumé exécutif" \
  "Références Apple" \
  "Écarts prioritaires" \
  "Priorités d’implémentation" \
  "Sources principales"; do
  grep -q "$section" Documentation/TECHNICAL_BENCHMARK_AND_PRIOR_ART.md || {
    echo "The technical benchmark is missing section: $section" >&2
    exit 1
  }
done

for section in \
  "Listener Remote Mac" \
  "Reconnexion iPhone" \
  "Changements de configuration audio" \
  "Fraîcheur de l’état backend" \
  "Handoff après panne critique"; do
  grep -q "$section" Documentation/RELIABILITY_HARDENING_REPORT.md || {
    echo "The reliability report is missing section: $section" >&2
    exit 1
  }
done

python3 Scripts/check_help_localizations.py

FORBIDDEN_PATTERN='Serato-only|Serato principal|djay expérimental|rekordbox expérimental|second backend|third backend|Serato source of truth|REQUIRES_SERATO_VALIDATION'
if grep -Ein "$FORBIDDEN_PATTERN" "${CURRENT_REFERENCES[@]}"; then
  echo "Obsolete product positioning found in a current reference document." >&2
  exit 1
fi

if grep -RIn --include='*.swift' --exclude='*Tests.swift' \
  -E 'djBackend[[:space:]]*:[[:space:]]*"rekordbox"|dj_backend[[:space:]]*=[[:space:]]*"rekordbox"' \
  Sources Mobile Shared; then
  echo "A runtime backend is still hardcoded to rekordbox." >&2
  exit 1
fi

if grep -RIn --include='*.swift' \
  -E 'takeManualControl|pauseAutopilot|resumeAutopilot|skipTransition|safeFade' \
  Mobile/MixPilotRemote/Sources/RootView.swift | grep -E 'Text\(|Button\(' ; then
  echo "An internal Remote command name is visible in the iPhone UI." >&2
  exit 1
fi

echo "Documentation and product terminology are consistent."
