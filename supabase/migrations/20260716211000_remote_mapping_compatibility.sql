-- Remote mapping and compatibility control plane for MixPilot.
-- Published rows are read-only to authenticated desktop clients.

create table if not exists public.mixpilot_mapping_releases (
    id uuid primary key default gen_random_uuid(),
    channel text not null default 'stable' check (channel in ('stable','beta','internal')),
    software text not null default 'rekordbox' check (software in ('rekordbox','serato','djay')),
    controller_name text not null,
    mapping_version integer not null check (mapping_version > 0),
    minimum_app_build integer not null default 1 check (minimum_app_build > 0),
    minimum_rekordbox_version text,
    maximum_rekordbox_version text,
    profile jsonb not null,
    profile_sha256 text not null check (profile_sha256 ~ '^[A-Fa-f0-9]{64}$'),
    generated_preset_sha256 text check (generated_preset_sha256 is null or generated_preset_sha256 ~ '^[A-Fa-f0-9]{64}$'),
    publisher_signature text,
    apply_mode text not null default 'notify' check (apply_mode in ('notify','next_launch','required')),
    mandatory boolean not null default false,
    rollout_percentage integer not null default 100 check (rollout_percentage between 0 and 100),
    status text not null default 'draft' check (status in ('draft','published','paused','withdrawn')),
    release_notes text not null default '',
    validation_summary jsonb not null default '{}'::jsonb,
    published_at timestamptz,
    created_at timestamptz not null default now(),
    unique (channel, software, controller_name, mapping_version)
);

create table if not exists public.mixpilot_mapping_installations (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid not null references auth.users(id) on delete cascade,
    device_id uuid not null references public.mixpilot_devices(id) on delete cascade,
    release_id uuid not null references public.mixpilot_mapping_releases(id) on delete cascade,
    status text not null default 'discovered' check (status in ('discovered','staged','validated','applied','failed','rolled_back','dismissed')),
    previous_profile_sha256 text,
    applied_profile_sha256 text,
    error_code text,
    details jsonb not null default '{}'::jsonb,
    applied_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    unique (owner_id, device_id, release_id)
);

create table if not exists public.mixpilot_compatibility_overrides (
    id uuid primary key default gen_random_uuid(),
    channel text not null default 'stable' check (channel in ('stable','beta','internal')),
    software text not null default 'rekordbox' check (software in ('rekordbox','serato','djay')),
    controller_name text not null default '*',
    minimum_app_build integer not null default 1 check (minimum_app_build > 0),
    minimum_rekordbox_version text,
    maximum_rekordbox_version text,
    disabled_actions text[] not null default '{}',
    required_validations text[] not null default '{}',
    warnings text[] not null default '{}',
    block_live boolean not null default false,
    rollout_percentage integer not null default 100 check (rollout_percentage between 0 and 100),
    status text not null default 'draft' check (status in ('draft','published','paused','withdrawn')),
    published_at timestamptz,
    created_at timestamptz not null default now()
);

create index if not exists mixpilot_mapping_releases_lookup_idx
    on public.mixpilot_mapping_releases (channel, software, controller_name, status, mapping_version desc);
create index if not exists mixpilot_mapping_installations_owner_device_idx
    on public.mixpilot_mapping_installations (owner_id, device_id, updated_at desc);
create index if not exists mixpilot_mapping_installations_device_idx
    on public.mixpilot_mapping_installations (device_id, updated_at desc);
create index if not exists mixpilot_mapping_installations_release_idx
    on public.mixpilot_mapping_installations (release_id, status);
create index if not exists mixpilot_compatibility_overrides_lookup_idx
    on public.mixpilot_compatibility_overrides (channel, software, controller_name, status, published_at desc);

alter table public.mixpilot_mapping_releases enable row level security;
alter table public.mixpilot_mapping_installations enable row level security;
alter table public.mixpilot_compatibility_overrides enable row level security;

revoke all on public.mixpilot_mapping_releases from anon, authenticated;
revoke all on public.mixpilot_mapping_installations from anon, authenticated;
revoke all on public.mixpilot_compatibility_overrides from anon, authenticated;

grant select on public.mixpilot_mapping_releases to authenticated;
grant select, insert, update on public.mixpilot_mapping_installations to authenticated;
grant select on public.mixpilot_compatibility_overrides to authenticated;

drop policy if exists "authenticated_select_published_mappings" on public.mixpilot_mapping_releases;
create policy "authenticated_select_published_mappings"
on public.mixpilot_mapping_releases for select
to authenticated
using (status = 'published' and published_at is not null and published_at <= now());

drop policy if exists "owners_select_mapping_installations" on public.mixpilot_mapping_installations;
create policy "owners_select_mapping_installations"
on public.mixpilot_mapping_installations for select
to authenticated
using ((select auth.uid()) = owner_id);

drop policy if exists "owners_insert_mapping_installations" on public.mixpilot_mapping_installations;
create policy "owners_insert_mapping_installations"
on public.mixpilot_mapping_installations for insert
to authenticated
with check ((select auth.uid()) = owner_id);

drop policy if exists "owners_update_mapping_installations" on public.mixpilot_mapping_installations;
create policy "owners_update_mapping_installations"
on public.mixpilot_mapping_installations for update
to authenticated
using ((select auth.uid()) = owner_id)
with check ((select auth.uid()) = owner_id);

drop policy if exists "authenticated_select_published_compatibility_overrides" on public.mixpilot_compatibility_overrides;
create policy "authenticated_select_published_compatibility_overrides"
on public.mixpilot_compatibility_overrides for select
to authenticated
using (status = 'published' and published_at is not null and published_at <= now());

create or replace view public.mixpilot_latest_mapping_releases
with (security_invoker = true)
as
select distinct on (channel, software, controller_name)
    id, channel, software, controller_name, mapping_version, minimum_app_build,
    minimum_rekordbox_version, maximum_rekordbox_version, profile, profile_sha256,
    generated_preset_sha256, publisher_signature, apply_mode, mandatory,
    rollout_percentage, release_notes, validation_summary, published_at
from public.mixpilot_mapping_releases
where status = 'published' and published_at is not null and published_at <= now()
order by channel, software, controller_name, mapping_version desc;

grant select on public.mixpilot_latest_mapping_releases to authenticated;

create or replace view public.mixpilot_active_compatibility_overrides
with (security_invoker = true)
as
select id, channel, software, controller_name, minimum_app_build,
       minimum_rekordbox_version, maximum_rekordbox_version,
       disabled_actions, required_validations, warnings, block_live,
       rollout_percentage, published_at
from public.mixpilot_compatibility_overrides
where status = 'published' and published_at is not null and published_at <= now();

grant select on public.mixpilot_active_compatibility_overrides to authenticated;
