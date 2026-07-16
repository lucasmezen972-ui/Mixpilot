# MixPilot Cloud Observability

GitHub stores the source code, reviewed fixes, CI results, SQL migrations and future signed releases. The dedicated Supabase project `Mixpilot` (`cqppkklfugbixpxwitab`) supplies managed PostgreSQL, authentication and the online application state.

## Why not a SQL database directly in GitHub?

A Git repository is an append-oriented source-control system, not a transactional database. Storing mutable telemetry as commits would create conflicts, expose operational data, consume API limits and make online health checks unreliable.

## Data model

- `mixpilot_devices`: one row per authenticated installation and heartbeat.
- `mixpilot_sessions`: app and Live sessions.
- `mixpilot_events`: append-only, privacy-filtered telemetry with idempotency keys.
- `rekordbox_validation_reports`: versioned compatibility certificates.
- `mixpilot_commands`: short-lived, allowlisted remote requests.
- `mixpilot_releases`: published versions, checksums, rollout percentage and release notes.
- `mixpilot_incidents`: aggregated error and critical event fingerprints.
- `mixpilot_device_health`: security-invoker health view.
- `mixpilot_latest_releases`: security-invoker update view.

## Runtime connection

The macOS app connects automatically while it is running. Supabase anonymous authentication gives each installation its own persistent user identity without collecting an email address or password. RLS still isolates every device, session, event and validation report by `auth.uid()`.

The app sends a heartbeat every 30 seconds. Every five minutes it checks for a published stable release and polls the strict command allowlist. Offline telemetry remains in a local atomic queue and is retried after reconnection.

Anonymous Sign-Ins must be enabled in Supabase under **Authentication → Providers → Anonymous Sign-Ins**. If it is disabled, MixPilot continues to work locally and displays the cloud as offline.

## Privacy defaults

The client never uploads track titles, artists, albums, file paths, playlist names, audio, Spotify URLs, credentials, tokens, secrets or raw Accessibility text. Payloads contain technical state only: app version/build, safe command identifier, outcome, sanitized error category and runtime state.

This personal MixPilot build enables technical monitoring automatically because continuous support was explicitly requested. A future multi-user distribution must add an onboarding disclosure and telemetry preference before collection.

## Security

- only the publishable key is embedded in the macOS client;
- no `service_role` or secret key exists in the app or repository;
- RLS ownership checks protect every client-facing table;
- the privileged RLS helper cannot be executed by `anon` or `authenticated` roles;
- the incident aggregation function lives in a private schema and is not client-callable;
- remote command insertion remains restricted to an administrative backend;
- the desktop command allowlist is limited to configuration refresh, telemetry flush, diagnostics and update checks;
- remote commands cannot inject Swift, shell commands or arbitrary MIDI actions;
- no remote start of a Live set;
- fixes must pass GitHub CI and become a published release before the app can offer them;
- the app opens the release page/download but never silently installs an unverified binary.

## Update flow

1. A privacy-filtered event reaches Supabase.
2. Error and critical events are aggregated into a stable incident fingerprint.
3. The hourly MixPilot Bug Watch correlates new incidents with GitHub and CI.
4. A clear low-risk fix may be prepared in a draft pull request.
5. Nothing is merged or released without explicit approval.
6. A release record includes version, monotonically increasing build, HTTPS download URL, SHA-256, optional signature, notes and rollout percentage.
7. MixPilot checks the latest published release and displays **Une mise à jour est disponible** when its build is newer and the installation is included in the rollout.

## Deployment state

The schema is deployed to the dedicated Supabase project. Security advisors report no active findings. Source-controlled migrations live under `supabase/migrations`, and the Swift client is pinned to the official Supabase SDK version used by the build.

The cloud does not give an assistant unrestricted access to the Mac. It provides sanitized observability and a controlled release channel; operating-system access and arbitrary code execution remain outside the design.
