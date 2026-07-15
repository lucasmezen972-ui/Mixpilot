# Changelog

## 0.3.0-rc — autonomous release candidate

### Added

- Native macOS Studio, Live, onboarding, MIDI mapping and blocking preflight.
- Automatic set preparation with cue markers and transition plans.
- Beat-accurate MIDI transition execution for seven transition families.
- Persistent MIDI mapping profiles and the virtual `MixPilot Virtual Controller`.
- Serato accessibility observation and visible playlist import.
- Temporary local PCM analysis for BPM, beat phase, energy and cue refinement.
- Modeled rehearsal comparison and a dedicated transition inspector window.
- Non-destructive playlist optimization suggestions.
- Audio watchdog for silence, clipping and source loss.
- Multi-file local emergency player with duration validation.
- Network, power and sleep-protection monitoring.
- Persistent Live checkpoints and a cautious recovery center.
- Redacted JSON/Markdown diagnostics and rotating incident journal.
- Exhaustive thirteen-scenario unattended failure matrix.
- Fifty-track runtime stress simulation covering all generated control values.
- Hardware probe CLI and self-hosted Serato validation workflow.
- Optional Developer ID signing and Apple notarization pipeline.
- Automated `.app`, `.dmg`, checksum and release-manifest generation.

### Validation status

- Core unit tests: automated.
- Fifty-track simulation: automated.
- Transition runtime stress test: automated.
- Failure matrix: automated.
- macOS Release build and DMG: automated.
- Real Serato, Spotify, MIDI mapping and routed audio: deferred to final hardware validation.

## 0.2 — new workspace shell

- Rebuilt the macOS dashboard around a desktop workspace with top navigation and a right-side drawer.
- Added a populated fallback set so the shell always renders with realistic operational data.
- Added file-backed emergency-audio metadata and native Open Panel selection.
- Added animated system indicators, simulated signal meters, live runtime log filtering, and more detailed deck/playlist cards.
- Added explicit empty/loading/error states and persisted window geometry for the final desktop shell.

## 0.1 — first runnable prototype

- Established the initial Swift package, simulator, native app shell, CoreMIDI bridge, and CI build flow.
