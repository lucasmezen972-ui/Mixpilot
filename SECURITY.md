# Security Policy

## Public repository

MixPilot is developed in a public repository. No secret or private user data may be committed.

## Never commit

- API keys, access tokens or passwords
- Apple Developer certificates or private keys
- Spotify or Serato credentials
- GitHub runner registration tokens
- Signing and notarization credentials
- User audio files or protected streamed content
- Raw diagnostic exports containing personal information

All CI/CD credentials must be stored in GitHub Actions Secrets or in the secure keychain of the self-hosted Mac runner.

## Reporting a vulnerability

Do not publish exploitable security details in a public issue. Contact the repository owner privately before public disclosure.

## Required safeguards

- Validate all external inputs.
- Keep real Serato automation separated from the simulator.
- Never label a simulated validation as a real hardware success.
- Redact sensitive paths, usernames and identifiers from exported diagnostics.
- Store no raw Spotify audio.
- Use least-privilege GitHub Actions permissions.
- Pin third-party GitHub Actions to trusted versions or commit SHAs when practical.
- Review dependencies and licenses before adoption.

## Local machine security

The macOS application may require Accessibility, Screen Recording and audio permissions to control and observe Serato. MixPilot must request only the permissions required for enabled features and explain their purpose to the user.
