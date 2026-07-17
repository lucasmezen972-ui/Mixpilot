# MixPilot cloud security hardening — 2026-07-17

## Applied to Supabase

The following changes were applied successfully to project `cqppkklfugbixpxwitab`:

- maintenance-command idempotency keys and sequence numbers;
- atomic `claim_mixpilot_commands` RPC using `FOR UPDATE SKIP LOCKED`;
- guarded `complete_mixpilot_command` RPC;
- both RPCs run as `SECURITY INVOKER` and therefore remain subject to caller grants and RLS;
- immutable command fields and terminal states protected by a transition trigger;
- JSON payload and result size limits;
- maximum command lifetime of 24 hours;
- telemetry category, name, timestamp and payload limits;
- mapping profile and validation-report size limits;
- app-release and mapping publication guards;
- publisher signature required for every published release or mapping;
- stable mappings require recorded physical-device validation;
- download URLs restricted to official MixPilot GitHub Releases or approved Supabase Storage buckets;
- automatic incident aggregation disabled unless an exact event category/name pair is administratively allowlisted;
- daily batched purge scheduled through `pg_cron` at 04:17 UTC.

The Supabase security advisor reports no remaining security lints after these migrations.

## Apple signing policy

The publisher signatures introduced here are independent application-level signatures. They do not require Apple Developer ID.

Developer/ad hoc macOS builds remain permitted. Apple Developer ID and notarization are not prerequisites for development, testing or merge in this phase.

## Client update protection

`MixPilotCloudRelease` now refuses to offer release metadata when:

- the SHA-256 is malformed;
- the publisher signature is absent or too short;
- the download URL is outside the allowlist;
- the release page URL is outside the allowlist.

An untrusted cloud URL falls back to the official MixPilot GitHub Releases page instead of being opened.

## Known limitation

The current macOS maintenance-command client still uses the legacy table polling path. The new RPCs are available and safe for the client cutover, but the cloud service remains effectively offline because anonymous Supabase sign-ins are disabled and no permanent user login flow has been added yet.

Until the identity flow and client RPC cutover are implemented, the command table must remain limited to the existing low-risk maintenance commands. It must not contain DJ playback, transition, MIDI, keyboard, AppleScript or shell commands.
