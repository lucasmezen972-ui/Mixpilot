# MixPilot Cloud Observability

GitHub stores the source code and SQL migrations. A dedicated Supabase project supplies the managed PostgreSQL database, authentication, Realtime and Edge Functions.

## Why not a SQL database directly in GitHub?

A Git repository is an append-oriented source-control system, not a transactional database. Storing mutable telemetry as JSON/SQLite commits would create conflicts, expose secrets, consume API limits and make Realtime unreliable.

## Data model

- `mixpilot_devices`: one row per authenticated installation.
- `mixpilot_sessions`: app and Live sessions.
- `mixpilot_events`: append-only telemetry with client-generated idempotency keys.
- `rekordbox_validation_reports`: versioned compatibility certificates.
- `mixpilot_commands`: short-lived, allowlisted remote requests.
- `mixpilot_device_health`: security-invoker health view.

## Privacy defaults

The client must never upload track titles, artists, file paths, playlist names, audio, Spotify URLs, credentials or raw Accessibility text by default. Payloads should contain only technical state such as app version, command identifier, latency, outcome and sanitized error codes.

Telemetry is opt-in. Local buffering remains available when offline. Events are retried with their `client_event_id`, so reconnecting cannot duplicate an event.

## Security

- publishable key only in the macOS client;
- no `service_role` key in the app or repository;
- authenticated users only;
- RLS ownership checks on every exposed table;
- remote command insertion restricted to a protected dashboard or Edge Function;
- commands expire and the desktop client must maintain a strict allowlist;
- no remote start of a Live set without a local, visible confirmation.

## Deployment

1. Create a dedicated Supabase project for MixPilot.
2. Link the repository with the Supabase CLI or GitHub integration.
3. Apply the migration under `supabase/migrations`.
4. Configure macOS with the project URL and publishable key through a local configuration file or build secret.
5. Enable Realtime only for the tables actually needed.
6. Run Supabase security and performance advisors after deployment.

## Monitoring model

The cloud can show whether MixPilot is online, its app/rekordbox version, validation progress, sanitized incidents and Live state. It does not give an assistant unrestricted access to the computer. Monitoring can be inspected on demand, through a dashboard, or through explicit scheduled alerts.
