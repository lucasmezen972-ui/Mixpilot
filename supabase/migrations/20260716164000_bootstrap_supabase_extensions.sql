-- Fresh-database prerequisites used by later MixPilot migrations.
-- Supabase normally provides the extensions schema, while a local or newly
-- provisioned Postgres instance may not have installed pgcrypto yet.

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
