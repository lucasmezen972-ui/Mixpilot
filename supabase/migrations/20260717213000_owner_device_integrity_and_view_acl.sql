-- Enforce owner/device/session integrity before MixPilot cloud data grows.
-- This migration is intentionally fail-closed: it refuses to add constraints
-- when pre-existing rows are inconsistent instead of deleting or rewriting them.

do $$
declare
    mismatch_count bigint;
begin
    select
        (select count(*) from public.mixpilot_sessions s
         left join public.mixpilot_devices d on d.id = s.device_id and d.owner_id = s.owner_id
         where d.id is null)
      + (select count(*) from public.mixpilot_events e
         left join public.mixpilot_devices d on d.id = e.device_id and d.owner_id = e.owner_id
         where d.id is null)
      + (select count(*) from public.mixpilot_events e
         left join public.mixpilot_sessions s
           on s.id = e.session_id and s.device_id = e.device_id and s.owner_id = e.owner_id
         where e.session_id is not null and s.id is null)
      + (select count(*) from public.mixpilot_commands c
         left join public.mixpilot_devices d on d.id = c.device_id and d.owner_id = c.owner_id
         where d.id is null)
      + (select count(*) from public.mixpilot_mapping_installations i
         left join public.mixpilot_devices d on d.id = i.device_id and d.owner_id = i.owner_id
         where d.id is null)
      + (select count(*) from public.rekordbox_validation_reports r
         left join public.mixpilot_devices d on d.id = r.device_id and d.owner_id = r.owner_id
         where d.id is null)
    into mismatch_count;

    if mismatch_count > 0 then
        raise exception 'MixPilot owner/device integrity migration blocked: % inconsistent rows require manual repair', mismatch_count;
    end if;
end
$$;

alter table public.mixpilot_devices
    add constraint mixpilot_devices_id_owner_key unique (id, owner_id);

alter table public.mixpilot_sessions
    add constraint mixpilot_sessions_id_device_owner_key unique (id, device_id, owner_id);

alter table public.mixpilot_sessions
    drop constraint if exists mixpilot_sessions_device_id_fkey,
    add constraint mixpilot_sessions_device_owner_fkey
        foreign key (device_id, owner_id)
        references public.mixpilot_devices (id, owner_id)
        on delete cascade;

alter table public.mixpilot_events
    drop constraint if exists mixpilot_events_device_id_fkey,
    drop constraint if exists mixpilot_events_session_id_fkey,
    add constraint mixpilot_events_device_owner_fkey
        foreign key (device_id, owner_id)
        references public.mixpilot_devices (id, owner_id)
        on delete cascade,
    add constraint mixpilot_events_session_device_owner_fkey
        foreign key (session_id, device_id, owner_id)
        references public.mixpilot_sessions (id, device_id, owner_id)
        on delete set null (session_id);

alter table public.mixpilot_commands
    drop constraint if exists mixpilot_commands_device_id_fkey,
    add constraint mixpilot_commands_device_owner_fkey
        foreign key (device_id, owner_id)
        references public.mixpilot_devices (id, owner_id)
        on delete cascade;

alter table public.mixpilot_mapping_installations
    drop constraint if exists mixpilot_mapping_installations_device_id_fkey,
    add constraint mixpilot_mapping_installations_device_owner_fkey
        foreign key (device_id, owner_id)
        references public.mixpilot_devices (id, owner_id)
        on delete cascade;

alter table public.rekordbox_validation_reports
    drop constraint if exists rekordbox_validation_reports_device_id_fkey,
    add constraint rekordbox_validation_reports_device_owner_fkey
        foreign key (device_id, owner_id)
        references public.mixpilot_devices (id, owner_id)
        on delete cascade;

-- Defense in depth: inserts and client updates must reference the caller's own
-- device even if a future migration accidentally changes a foreign key.
drop policy if exists owners_insert_sessions on public.mixpilot_sessions;
create policy owners_insert_sessions
on public.mixpilot_sessions for insert
to authenticated
with check (
    owner_id = (select auth.uid())
    and exists (
        select 1 from public.mixpilot_devices d
        where d.id = device_id and d.owner_id = (select auth.uid())
    )
);

drop policy if exists owners_update_sessions on public.mixpilot_sessions;
create policy owners_update_sessions
on public.mixpilot_sessions for update
to authenticated
using (owner_id = (select auth.uid()))
with check (
    owner_id = (select auth.uid())
    and exists (
        select 1 from public.mixpilot_devices d
        where d.id = device_id and d.owner_id = (select auth.uid())
    )
);

drop policy if exists owners_insert_events on public.mixpilot_events;
create policy owners_insert_events
on public.mixpilot_events for insert
to authenticated
with check (
    owner_id = (select auth.uid())
    and exists (
        select 1 from public.mixpilot_devices d
        where d.id = device_id and d.owner_id = (select auth.uid())
    )
    and (
        session_id is null
        or exists (
            select 1 from public.mixpilot_sessions s
            where s.id = session_id
              and s.device_id = device_id
              and s.owner_id = (select auth.uid())
        )
    )
);

drop policy if exists owners_insert_mapping_installations on public.mixpilot_mapping_installations;
create policy owners_insert_mapping_installations
on public.mixpilot_mapping_installations for insert
to authenticated
with check (
    owner_id = (select auth.uid())
    and exists (
        select 1 from public.mixpilot_devices d
        where d.id = device_id and d.owner_id = (select auth.uid())
    )
);

drop policy if exists owners_update_mapping_installations on public.mixpilot_mapping_installations;
create policy owners_update_mapping_installations
on public.mixpilot_mapping_installations for update
to authenticated
using (owner_id = (select auth.uid()))
with check (
    owner_id = (select auth.uid())
    and exists (
        select 1 from public.mixpilot_devices d
        where d.id = device_id and d.owner_id = (select auth.uid())
    )
);

drop policy if exists owners_insert_validation_reports on public.rekordbox_validation_reports;
create policy owners_insert_validation_reports
on public.rekordbox_validation_reports for insert
to authenticated
with check (
    owner_id = (select auth.uid())
    and exists (
        select 1 from public.mixpilot_devices d
        where d.id = device_id and d.owner_id = (select auth.uid())
    )
);

drop policy if exists owners_update_validation_reports on public.rekordbox_validation_reports;
create policy owners_update_validation_reports
on public.rekordbox_validation_reports for update
to authenticated
using (owner_id = (select auth.uid()))
with check (
    owner_id = (select auth.uid())
    and exists (
        select 1 from public.mixpilot_devices d
        where d.id = device_id and d.owner_id = (select auth.uid())
    )
);

-- Views are read models. The API roles must never retain write-like ACLs.
revoke all on public.mixpilot_latest_releases from anon, authenticated;
grant select on public.mixpilot_latest_releases to authenticated;

revoke all on public.mixpilot_mapping_provenance from anon, authenticated;
grant select on public.mixpilot_mapping_provenance to authenticated;

revoke all on public.mixpilot_latest_mapping_releases from anon, authenticated;
grant select on public.mixpilot_latest_mapping_releases to authenticated;

revoke all on public.mixpilot_active_compatibility_overrides from anon, authenticated;
grant select on public.mixpilot_active_compatibility_overrides to authenticated;

revoke all on public.mixpilot_device_health from anon, authenticated;
grant select on public.mixpilot_device_health to authenticated;
