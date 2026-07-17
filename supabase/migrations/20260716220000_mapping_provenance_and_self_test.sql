-- Immutable GitHub provenance and publication guard for remote mappings.

alter table public.mixpilot_mapping_releases
    add column if not exists source_repository text,
    add column if not exists source_commit_sha text,
    add column if not exists source_manifest_path text,
    add column if not exists source_manifest_sha256 text;

alter table public.mixpilot_mapping_releases
    drop constraint if exists mixpilot_mapping_source_commit_sha_check,
    add constraint mixpilot_mapping_source_commit_sha_check
        check (source_commit_sha is null or source_commit_sha ~ '^[A-Fa-f0-9]{40}$'),
    drop constraint if exists mixpilot_mapping_source_manifest_sha256_check,
    add constraint mixpilot_mapping_source_manifest_sha256_check
        check (source_manifest_sha256 is null or source_manifest_sha256 ~ '^[A-Fa-f0-9]{64}$'),
    drop constraint if exists mixpilot_mapping_source_manifest_path_check,
    add constraint mixpilot_mapping_source_manifest_path_check
        check (source_manifest_path is null or source_manifest_path ~ '^MappingReleases/[A-Za-z0-9._/-]+\.json$');

create or replace function public.mixpilot_guard_mapping_publication()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
    if new.status = 'published' then
        if new.published_at is null or new.rollout_percentage <= 0 then
            raise exception 'Published mappings require published_at and rollout_percentage > 0';
        end if;
        if new.source_repository is distinct from 'lucasmezen972-ui/Mixpilot'
           or new.source_commit_sha is null
           or new.source_manifest_path is null
           or new.source_manifest_sha256 is null then
            raise exception 'Published mappings require trusted immutable GitHub provenance';
        end if;
        if new.generated_preset_sha256 is null then
            raise exception 'Published mappings require the generated preset digest';
        end if;
        if coalesce(new.validation_summary->>'unit_tests', '') <> 'passed'
           or coalesce(new.validation_summary->>'release_build', '') <> 'passed'
           or coalesce(new.validation_summary->>'dmg_checksum', '') <> 'passed' then
            raise exception 'Published mappings require completed CI validation';
        end if;
    end if;
    return new;
end;
$$;

revoke all on function public.mixpilot_guard_mapping_publication() from public, anon, authenticated;
grant execute on function public.mixpilot_guard_mapping_publication() to postgres, service_role;

drop trigger if exists mixpilot_guard_mapping_publication_trigger on public.mixpilot_mapping_releases;
create trigger mixpilot_guard_mapping_publication_trigger
before insert or update on public.mixpilot_mapping_releases
for each row execute function public.mixpilot_guard_mapping_publication();

create or replace view public.mixpilot_latest_mapping_releases
with (security_invoker = true)
as
select distinct on (channel, software, controller_name)
    id, channel, software, controller_name, mapping_version, minimum_app_build,
    minimum_rekordbox_version, maximum_rekordbox_version, profile, profile_sha256,
    generated_preset_sha256, publisher_signature, apply_mode, mandatory,
    rollout_percentage, release_notes, validation_summary, published_at,
    source_repository, source_commit_sha, source_manifest_path, source_manifest_sha256
from public.mixpilot_mapping_releases
where status = 'published' and published_at is not null and published_at <= now()
order by channel, software, controller_name, mapping_version desc;

grant select on public.mixpilot_latest_mapping_releases to authenticated;

create or replace view public.mixpilot_mapping_provenance
with (security_invoker = true)
as
select id, source_repository, source_commit_sha, source_manifest_path, source_manifest_sha256
from public.mixpilot_mapping_releases
where status = 'published' and published_at is not null and published_at <= now();

grant select on public.mixpilot_mapping_provenance to authenticated;

create or replace function public.mixpilot_cloud_self_test()
returns table (
    authenticated boolean,
    user_id_present boolean,
    published_mapping_count bigint,
    published_release_count bigint,
    checked_at timestamptz
)
language sql
stable
security invoker
set search_path = ''
as $$
    select
        auth.uid() is not null,
        auth.uid() is not null,
        (select count(*) from public.mixpilot_mapping_releases where status = 'published' and published_at <= now()),
        (select count(*) from public.mixpilot_releases where status = 'published' and published_at <= now()),
        now();
$$;

revoke all on function public.mixpilot_cloud_self_test() from public, anon;
grant execute on function public.mixpilot_cloud_self_test() to authenticated;
