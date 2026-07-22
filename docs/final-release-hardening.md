# Final release hardening

The final MixPilot release boundary requires all of the following on the exact Git commit being packaged:

- the line-by-line repository audit reports zero blocking errors;
- the independent architecture counter-audit executes at least 50 checks and reports zero blocking errors;
- fresh Supabase migrations and database tests succeed;
- the complete Swift test suite, backend simulations, macOS products and iPhone Remote tests succeed;
- the Release executable is stripped before signing;
- the application bundle and mounted DMG contain no user data, personal home paths, credentials, runtime databases, logs or unexpected top-level payloads;
- the DMG checksum and the application signature are verified.

Physical validation with real DJ software, audio devices and controllers remains a separate release requirement and is never inferred from CI.
