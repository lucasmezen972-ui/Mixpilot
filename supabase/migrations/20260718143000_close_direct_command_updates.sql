-- The macOS client now claims and completes maintenance commands exclusively
-- through these RPCs. Close the historical authenticated UPDATE path while
-- preserving explicit owner checks inside SECURITY DEFINER functions.

create or replace function public.claim_mixpilot_commands(
    p_device_id uuid,
    p_instance_id text,
    p_limit integer default 10
)
returns setof public.mixpilot_commands
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
    if auth.uid() is null then
        raise exception 'Authentication required' using errcode = '42501';
    end if;
    if p_instance_id is null or length(p_instance_id) not between 8 and 160 then
        raise exception 'Invalid instance identifier' using errcode = '22023';
    end if;

    return query
    with candidates as (
        select c.id
        from public.mixpilot_commands c
        where c.owner_id = auth.uid()
          and c.device_id = p_device_id
          and c.status = 'pending'
          and c.claimed_at is null
          and c.expires_at > now()
          and c.attempt_count < 20
        order by c.sequence_number
        for update skip locked
        limit least(greatest(coalesce(p_limit, 1), 1), 10)
    )
    update public.mixpilot_commands c
       set status = 'accepted',
           claimed_at = now(),
           claimed_by_instance = p_instance_id,
           attempt_count = c.attempt_count + 1
      from candidates
     where c.id = candidates.id
    returning c.*;
end;
$$;

create or replace function public.complete_mixpilot_command(
    p_command_id uuid,
    p_instance_id text,
    p_succeeded boolean,
    p_result jsonb default '{}'::jsonb,
    p_failure_code text default null
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
    updated_count integer;
begin
    if auth.uid() is null then
        raise exception 'Authentication required' using errcode = '42501';
    end if;
    if p_instance_id is null or length(p_instance_id) not between 8 and 160 then
        raise exception 'Invalid instance identifier' using errcode = '22023';
    end if;
    if octet_length(coalesce(p_result, '{}'::jsonb)::text) > 16384 then
        raise exception 'Command result is too large' using errcode = '22023';
    end if;

    update public.mixpilot_commands
       set status = case when p_succeeded then 'completed' else 'failed' end,
           completed_at = now(),
           result = coalesce(p_result, '{}'::jsonb),
           failure_code = case
               when p_succeeded then null
               else left(p_failure_code, 120)
           end
     where id = p_command_id
       and owner_id = auth.uid()
       and status = 'accepted'
       and claimed_by_instance = p_instance_id
       and completed_at is null;

    get diagnostics updated_count = row_count;
    return updated_count = 1;
end;
$$;

alter function public.claim_mixpilot_commands(uuid, text, integer) owner to postgres;
alter function public.complete_mixpilot_command(uuid, text, boolean, jsonb, text) owner to postgres;

revoke all on function public.claim_mixpilot_commands(uuid, text, integer)
    from public, anon, authenticated;
revoke all on function public.complete_mixpilot_command(uuid, text, boolean, jsonb, text)
    from public, anon, authenticated;

grant execute on function public.claim_mixpilot_commands(uuid, text, integer)
    to authenticated, service_role;
grant execute on function public.complete_mixpilot_command(uuid, text, boolean, jsonb, text)
    to authenticated, service_role;

-- RPCs run as postgres and keep their own auth.uid() ownership checks. The
-- application role no longer needs to UPDATE the command table directly.
revoke update on table public.mixpilot_commands from authenticated;
grant select on table public.mixpilot_commands to authenticated;

create or replace function public.mixpilot_guard_command_update()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
    if current_user in ('postgres', 'service_role') then
        return new;
    end if;

    if new.id is distinct from old.id
       or new.owner_id is distinct from old.owner_id
       or new.device_id is distinct from old.device_id
       or new.created_at is distinct from old.created_at
       or new.expires_at is distinct from old.expires_at
       or new.command is distinct from old.command
       or new.payload is distinct from old.payload
       or new.idempotency_key is distinct from old.idempotency_key
       or new.sequence_number is distinct from old.sequence_number then
        raise exception 'Immutable command fields cannot be changed'
            using errcode = '42501';
    end if;

    if old.status in ('completed', 'failed', 'expired') then
        raise exception 'Terminal commands are immutable'
            using errcode = '42501';
    end if;

    if old.status = 'pending' and new.status not in ('accepted', 'expired') then
        raise exception 'Pending commands must be claimed before completion'
            using errcode = '22023';
    end if;

    if old.status = 'accepted' and new.status not in ('completed', 'failed', 'expired') then
        raise exception 'Invalid transition from accepted command'
            using errcode = '22023';
    end if;

    if new.status = 'accepted' then
        if new.claimed_at is null or new.claimed_by_instance is null then
            raise exception 'Accepted commands require an agent claim'
                using errcode = '22023';
        end if;
        if new.completed_at is not null or new.result is not null then
            raise exception 'Accepted commands cannot already contain a result'
                using errcode = '22023';
        end if;
    end if;

    if new.status in ('completed', 'failed') then
        if new.completed_at is null then
            raise exception 'Terminal command results require completed_at'
                using errcode = '22023';
        end if;
    elsif new.completed_at is not null or new.result is not null or new.failure_code is not null then
        raise exception 'Non-terminal commands cannot contain completion fields'
            using errcode = '22023';
    end if;

    return new;
end;
$$;

revoke all on function public.mixpilot_guard_command_update()
    from public, anon, authenticated;

-- Fail the migration if the least-privilege contract was not established.
do $$
declare
    claim_is_definer boolean;
    complete_is_definer boolean;
begin
    if has_table_privilege('authenticated', 'public.mixpilot_commands', 'UPDATE') then
        raise exception 'authenticated must not retain direct UPDATE on mixpilot_commands';
    end if;

    if not has_function_privilege(
        'authenticated',
        'public.claim_mixpilot_commands(uuid,text,integer)',
        'EXECUTE'
    ) then
        raise exception 'authenticated requires EXECUTE on claim_mixpilot_commands';
    end if;

    if not has_function_privilege(
        'authenticated',
        'public.complete_mixpilot_command(uuid,text,boolean,jsonb,text)',
        'EXECUTE'
    ) then
        raise exception 'authenticated requires EXECUTE on complete_mixpilot_command';
    end if;

    select p.prosecdef
      into claim_is_definer
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname = 'claim_mixpilot_commands'
       and pg_get_function_identity_arguments(p.oid) = 'p_device_id uuid, p_instance_id text, p_limit integer';

    select p.prosecdef
      into complete_is_definer
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname = 'complete_mixpilot_command'
       and pg_get_function_identity_arguments(p.oid) = 'p_command_id uuid, p_instance_id text, p_succeeded boolean, p_result jsonb, p_failure_code text';

    if claim_is_definer is distinct from true or complete_is_definer is distinct from true then
        raise exception 'command RPCs must remain SECURITY DEFINER';
    end if;
end
$$;
