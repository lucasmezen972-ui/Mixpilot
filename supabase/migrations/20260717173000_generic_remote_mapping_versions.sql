-- Generalize remote mapping releases and compatibility overrides for all DJ backends.
-- Legacy rekordbox-named columns remain available for older desktop builds.

alter table public.mixpilot_mapping_releases
    add column if not exists minimum_software_version text,
    add column if not exists maximum_software_version text,
    add column if not exists generated_artifact_sha256 text;

alter table public.mixpilot_compatibility_overrides
    add column if not exists minimum_software_version text,
    add column if not exists maximum_software_version text;

update public.mixpilot_mapping_releases
set minimum_software_version = coalesce(minimum_software_version, minimum_rekordbox_version),
    maximum_software_version = coalesce(maximum_software_version, maximum_rekordbox_version),
    generated_artifact_sha256 = coalesce(generated_artifact_sha256, generated_preset_sha256)
where minimum_software_version is null
   or maximum_software_version is null
   or generated_artifact_sha256 is null;

update public.mixpilot_compatibility_overrides
set minimum_software_version = coalesce(minimum_software_version, minimum_rekordbox_version),
    maximum_software_version = coalesce(maximum_software_version, maximum_rekordbox_version)
where minimum_software_version is null
   or maximum_software_version is null;

alter table public.mixpilot_mapping_releases
    drop constraint if exists mixpilot_mapping_releases_generated_artifact_sha256_check;

alter table public.mixpilot_mapping_releases
    add constraint mixpilot_mapping_releases_generated_artifact_sha256_check
    check (
        generated_artifact_sha256 is null
        or generated_artifact_sha256 ~ '^[A-Fa-f0-9]{64}$'
    );

-- Keep legacy columns synchronized for rekordbox rows written by newer tooling.
create or replace function public.mixpilot_sync_mapping_legacy_columns()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
    if new.software = 'rekordbox' then
        new.minimum_rekordbox_version := coalesce(new.minimum_rekordbox_version, new.minimum_software_version);
        new.maximum_rekordbox_version := coalesce(new.maximum_rekordbox_version, new.maximum_software_version);
        new.generated_preset_sha256 := coalesce(new.generated_preset_sha256, new.generated_artifact_sha256);
    end if;
    new.minimum_software_version := coalesce(new.minimum_software_version, new.minimum_rekordbox_version);
    new.maximum_software_version := coalesce(new.maximum_software_version, new.maximum_rekordbox_version);
    new.generated_artifact_sha256 := coalesce(new.generated_artifact_sha256, new.generated_preset_sha256);
    return new;
end;
$$;

create or replace function public.mixpilot_sync_override_legacy_columns()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
    if new.software = 'rekordbox' then
        new.minimum_rekordbox_version := coalesce(new.minimum_rekordbox_version, new.minimum_software_version);
        new.maximum_rekordbox_version := coalesce(new.maximum_rekordbox_version, new.maximum_software_version);
    end if;
    new.minimum_software_version := coalesce(new.minimum_software_version, new.minimum_rekordbox_version);
    new.maximum_software_version := coalesce(new.maximum_software_version, new.maximum_rekordbox_version);
    return new;
end;
$$;

drop trigger if exists mixpilot_mapping_releases_sync_legacy on public.mixpilot_mapping_releases;
create trigger mixpilot_mapping_releases_sync_legacy
before insert or update on public.mixpilot_mapping_releases
for each row execute function public.mixpilot_sync_mapping_legacy_columns();

drop trigger if exists mixpilot_compatibility_overrides_sync_legacy on public.mixpilot_compatibility_overrides;
create trigger mixpilot_compatibility_overrides_sync_legacy
before insert or update on public.mixpilot_compatibility_overrides
for each row execute function public.mixpilot_sync_override_legacy_columns();

drop view if exists public.mixpilot_latest_mapping_releases;
create view public.mixpilot_latest_mapping_releases
with (security_invoker = true)
as
select distinct on (channel, software, controller_name)
    id,
    channel,
    software,
    controller_name,
    mapping_version,
    minimum_app_build,
    minimum_software_version,
    maximum_software_version,
    minimum_rekordbox_version,
    maximum_rekordbox_version,
    profile,
    profile_sha256,
    generated_artifact_sha256,
    generated_preset_sha256,
    publisher_signature,
    apply_mode,
    mandatory,
    rollout_percentage,
    release_notes,
    validation_summary,
    published_at
from public.mixpilot_mapping_releases
where status = 'published'
  and published_at is not null
  and published_at <= now()
order by channel, software, controller_name, mapping_version desc;

grant select on public.mixpilot_latest_mapping_releases to authenticated;

drop view if exists public.mixpilot_active_compatibility_overrides;
create view public.mixpilot_active_compatibility_overrides
with (security_invoker = true)
as
select
    id,
    channel,
    software,
    controller_name,
    minimum_app_build,
    minimum_software_version,
    maximum_software_version,
    minimum_rekordbox_version,
    maximum_rekordbox_version,
    disabled_actions,
    required_validations,
    warnings,
    block_live,
    rollout_percentage,
    published_at
from public.mixpilot_compatibility_overrides
where status = 'published'
  and published_at is not null
  and published_at <= now();

grant select on public.mixpilot_active_compatibility_overrides to authenticated;
