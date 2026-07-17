# MixPilot security hardening — 2026-07-17

## Scope delivered in this change

- Restored `Final PR Validation` on pull requests targeting `main`.
- Added Ubuntu and macOS runner smoke tests before expensive validation work.
- Kept development DMG generation compatible with ad hoc signing.
- Explicitly removed Developer ID and notarization as requirements for PR validation.
- Disabled the current unencrypted iPhone remote transport by default in normal app launches.
- Added the explicit development override `MIXPILOT_ALLOW_INSECURE_REMOTE=1` for isolated test networks only.
- Removed the non-cryptographic PIN fallback.
- Locked pairing for five minutes after five invalid PIN attempts.
- Added tests for the development transport gate and pairing lockout.
- Added composite PostgreSQL integrity constraints binding every device reference to its owner.
- Added session/device/owner consistency for telemetry events.
- Hardened RLS insert and update checks for sessions, events, mapping installations and validation reports.
- Reduced public view privileges to `SELECT` for authenticated users only.

## Supabase deployment

Migration `owner_device_integrity_and_view_acl` was applied successfully to project `cqppkklfugbixpxwitab`.

The migration checked for inconsistent existing rows before applying constraints and found none.

## Signing policy for this phase

Developer ID and Apple notarization are not required for development builds or PR validation.

Artifacts produced by these workflows must remain clearly identified as development/ad hoc builds. This does not claim that they are ready for public macOS distribution.

## Remote status

The existing WebSocket transport remains unencrypted. It is now fail-closed in normal app launches and can only be enabled through an explicit process environment override for development.

TLS, Mac identity pinning and iPhone proof-of-possession remain a separate implementation phase. Until that phase is complete, the iPhone remote must not be enabled for a public event or an untrusted/shared Wi-Fi network.

## Remaining work

- Implement encrypted and mutually authenticated iPhone–Mac transport.
- Replace reusable bearer-token authentication with device key proof-of-possession.
- Add persistent anti-replay sequence state.
- Replace anonymous-only Supabase bootstrap with an explicit account or device identity flow.
- Add atomic claiming for maintenance commands.
- Sign mapping and application update manifests independently of Apple Developer ID.
- Complete real-device tests for Mac, iPhone, Serato, djay, Rekordbox, MIDI and audio.
