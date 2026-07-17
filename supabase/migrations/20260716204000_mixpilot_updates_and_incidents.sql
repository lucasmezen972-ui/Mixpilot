-- MixPilot cloud updates, safe remote commands and incident aggregation.

revoke execute on function public.rls_auto_enable() from public, anon, authenticated;

alter table public.mixpilot_devices
    add column if not exists app_build integer,
    add column if not exists update_channel text not null default 'stable';

alter table public.mixpilot_sessions
    add column if not exists app_build integer;

alter table public.mixpilot_devices
    add constraint mixpilot_devices_update_channel_check
    check (update_channel in ('stable','beta','internal'));

alter table public.mixpilot_commands
    add constraint mixpilot_commands_command_check
    check (command in ('refresh_configuration','flush_telemetry','run_diagnostics','check_for_update'));

create table if not exists public.mixpilot_releases (
    id uuid primary key default gen_random_uuid(),
    channel text not null default 'stable' check (channel in ('stable','beta','internal')),
    version text not null,
    build integer not null check (build > 0),
    minimum_macos text not null default '14.0',
    download_url text not null,
    release_page_url text,
    sha256 text not null check (sha256 ~ '^[A-Fa-f0-9]{64}$'),
    signature text,
    release_notes text not null default '',
    mandatory boolean not null default false,
    rollout_percentage integer not null default 100 check (rollout_percentage between 0 and 100),
    status text not null default 'draft' check (status in ('draft','published','paused','withdrawn')),
    published_at timestamptz,
    created_at timestamptz not null default now(),
    unique (channel, build)
);

create table if not exists public.mixpilot_incidents (
    id uuid primary key default gen_random_uuid(),
    fingerprint text not null unique,
    category text not null,
    name text not null,
    severity text not null check (severity in ('warning','error','critical')),
    status text not null default 'open' check (status in ('open','investigating','fix_ready','released','ignored')),
    occurrences bigint not null default 1,
    affected_devices integer not null default 1,
    first_seen_at timestamptz not null default now(),
    last_seen_at timestamptz not null default now(),
    github_issue_url text,
    github_pr_url text,
    fixed_in_build integer,
    safe_summary text not null default '',
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.mixpilot_releases enable row level security;
alter table public.mixpilot_incidents enable row level security;

revoke all on public.mixpilot_releases from anon, authenticated;
revoke all on public.mixpilot_incidents from anon, authenticated;
grant select on public.mixpilot_releases to authenticated;

create policy "authenticated_select_published_releases"
on public.mixpilot_releases for select
to authenticated
using (status = 'published' and published_at is not null and published_at <= now());

create policy "deny_authenticated_incidents"
on public.mixpilot_incidents as restrictive for all
to authenticated
using (false)
with check (false);

create index if not exists mixpilot_commands_owner_idx on public.mixpilot_commands (owner_id);
create index if not exists mixpilot_events_device_idx on public.mixpilot_events (device_id);
create index if not exists mixpilot_sessions_device_idx on public.mixpilot_sessions (device_id);
create index if not exists rekordbox_validation_device_idx on public.rekordbox_validation_reports (device_id);
create index if not exists mixpilot_releases_lookup_idx on public.mixpilot_releases (channel, status, build desc);
create index if not exists mixpilot_incidents_status_severity_idx on public.mixpilot_incidents (status, severity, last_seen_at desc);

create or replace view public.mixpilot_latest_releases
with (security_invoker = true)
as
select distinct on (channel)
    id,
    channel,
    version,
    build,
    minimum_macos,
    download_url,
    release_page_url,
    sha256,
    signature,
    release_notes,
    mandatory,
    rollout_percentage,
    published_at
from public.mixpilot_releases
where status = 'published'
  and published_at is not null
  and published_at <= now()
order by channel, build desc;

grant select on public.mixpilot_latest_releases to authenticated;

create or replace view public.mixpilot_device_health
with (security_invoker = true)
as
select
    d.owner_id,
    d.id as device_id,
    d.device_name,
    d.app_version,
    d.app_build,
    d.rekordbox_version,
    d.update_channel,
    d.last_seen_at,
    (now() - d.last_seen_at) < interval '2 minutes' as online,
    count(e.id) filter (
        where e.severity in ('error','critical')
          and e.occurred_at > now() - interval '24 hours'
    ) as errors_last_24h,
    max(e.occurred_at) as last_event_at
from public.mixpilot_devices d
left join public.mixpilot_events e on e.device_id = d.id
group by d.owner_id, d.id;

create or replace function mixpilot_private.aggregate_event_incident()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, mixpilot_private
as $$
declare
    incident_fingerprint text;
begin
    if new.severity not in ('error', 'critical') then
        return new;
    end if;

    incident_fingerprint := encode(
        extensions.digest(convert_to(new.category || ':' || new.name, 'UTF8'), 'sha256'),
        'hex'
    );

    insert into public.mixpilot_incidents (
        fingerprint,
        category,
        name,
        severity,
        status,
        occurrences,
        affected_devices,
        first_seen_at,
        last_seen_at,
        safe_summary
    ) values (
        incident_fingerprint,
        left(new.category, 80),
        left(new.name, 80),
        new.severity,
        'open',
        1,
        1,
        new.occurred_at,
        new.occurred_at,
        left(new.category || ' / ' || new.name, 180)
    )
    on conflict (fingerprint) do update
    set occurrences = public.mixpilot_incidents.occurrences + 1,
        severity = case
            when excluded.severity = 'critical' then 'critical'
            else public.mixpilot_incidents.severity
        end,
        last_seen_at = greatest(public.mixpilot_incidents.last_seen_at, excluded.last_seen_at),
        updated_at = now();

    return new;
end;
$$;

revoke all on function mixpilot_private.aggregate_event_incident() from public, anon, authenticated;

drop trigger if exists mixpilot_aggregate_event_incident on public.mixpilot_events;
create trigger mixpilot_aggregate_event_incident
after insert on public.mixpilot_events
for each row execute function mixpilot_private.aggregate_event_incident();
