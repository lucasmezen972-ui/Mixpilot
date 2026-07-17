-- First-class multi-backend cloud context.
-- Existing rekordbox columns remain during the local/app migration window.

alter table public.mixpilot_devices
    add column if not exists dj_backend text,
    add column if not exists dj_software_version text,
    add column if not exists controller_name text,
    add column if not exists mapping_version text,
    add column if not exists mapping_sha256 text,
    add column if not exists capabilities_snapshot jsonb not null default '{}'::jsonb,
    add column if not exists validation_status text,
    add column if not exists telemetry_enabled boolean not null default false;

alter table public.mixpilot_sessions
    add column if not exists dj_software_version text,
    add column if not exists controller_name text,
    add column if not exists mapping_version text,
    add column if not exists mapping_sha256 text,
    add column if not exists capabilities_snapshot jsonb not null default '{}'::jsonb,
    add column if not exists validation_status text,
    add column if not exists telemetry_enabled boolean not null default false;

alter table public.mixpilot_events
    add column if not exists expires_at timestamptz;

update public.mixpilot_events
set expires_at = occurred_at + interval '30 days'
where expires_at is null;

alter table public.mixpilot_events
    alter column expires_at set default (now() + interval '30 days'),
    alter column expires_at set not null;

alter table public.mixpilot_mapping_releases
    add column if not exists minimum_software_version text,
    add column if not exists maximum_software_version text,
    add column if not exists mapping_format text not null default 'profile_json';

update public.mixpilot_mapping_releases
set minimum_software_version = coalesce(minimum_software_version, minimum_rekordbox_version),
    maximum_software_version = coalesce(maximum_software_version, maximum_rekordbox_version)
where software = 'rekordbox';

alter table public.mixpilot_compatibility_overrides
    add column if not exists minimum_software_version text,
    add column if not exists maximum_software_version text;

update public.mixpilot_compatibility_overrides
set minimum_software_version = coalesce(minimum_software_version, minimum_rekordbox_version),
    maximum_software_version = coalesce(maximum_software_version, maximum_rekordbox_version)
where software = 'rekordbox';

do $$
begin
    if not exists (
        select 1 from pg_constraint where conname = 'mixpilot_devices_dj_backend_check'
    ) then
        alter table public.mixpilot_devices
            add constraint mixpilot_devices_dj_backend_check
            check (dj_backend is null or dj_backend in ('djay','rekordbox','serato'));
    end if;

    if not exists (
        select 1 from pg_constraint where conname = 'mixpilot_sessions_dj_backend_check'
    ) then
        alter table public.mixpilot_sessions
            add constraint mixpilot_sessions_dj_backend_check
            check (dj_backend is null or dj_backend in ('djay','rekordbox','serato'));
    end if;

    if not exists (
        select 1 from pg_constraint where conname = 'mixpilot_devices_mapping_sha256_check'
    ) then
        alter table public.mixpilot_devices
            add constraint mixpilot_devices_mapping_sha256_check
            check (mapping_sha256 is null or mapping_sha256 ~ '^[A-Fa-f0-9]{64}$');
    end if;

    if not exists (
        select 1 from pg_constraint where conname = 'mixpilot_sessions_mapping_sha256_check'
    ) then
        alter table public.mixpilot_sessions
            add constraint mixpilot_sessions_mapping_sha256_check
            check (mapping_sha256 is null or mapping_sha256 ~ '^[A-Fa-f0-9]{64}$');
    end if;
end
$$;

create index if not exists mixpilot_devices_backend_version_idx
    on public.mixpilot_devices (dj_backend, dj_software_version, last_seen_at desc);
create index if not exists mixpilot_sessions_backend_started_idx
    on public.mixpilot_sessions (dj_backend, dj_software_version, started_at desc);
create index if not exists mixpilot_events_expiry_idx
    on public.mixpilot_events (expires_at);

create or replace view public.mixpilot_latest_mapping_releases
with (security_invoker = true)
as
select distinct on (channel, software, controller_name)
    id, channel, software, controller_name, mapping_version, minimum_app_build,
    minimum_software_version, maximum_software_version,
    minimum_rekordbox_version, maximum_rekordbox_version,
    mapping_format, profile, profile_sha256, generated_preset_sha256,
    publisher_signature, apply_mode, mandatory, rollout_percentage,
    release_notes, validation_summary, published_at
from public.mixpilot_mapping_releases
where status = 'published' and published_at is not null and published_at <= now()
order by channel, software, controller_name, mapping_version desc;

grant select on public.mixpilot_latest_mapping_releases to authenticated;

create or replace view public.mixpilot_active_compatibility_overrides
with (security_invoker = true)
as
select id, channel, software, controller_name, minimum_app_build,
       minimum_software_version, maximum_software_version,
       minimum_rekordbox_version, maximum_rekordbox_version,
       disabled_actions, required_validations, warnings, block_live,
       rollout_percentage, published_at
from public.mixpilot_compatibility_overrides
where status = 'published' and published_at is not null and published_at <= now();

grant select on public.mixpilot_active_compatibility_overrides to authenticated;

create or replace function mixpilot_private.purge_expired_telemetry()
returns bigint
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
    deleted_count bigint;
begin
    delete from public.mixpilot_events where expires_at <= now();
    get diagnostics deleted_count = row_count;
    return deleted_count;
end;
$$;

revoke all on function mixpilot_private.purge_expired_telemetry() from public, anon, authenticated;
grant execute on function mixpilot_private.purge_expired_telemetry() to service_role;
