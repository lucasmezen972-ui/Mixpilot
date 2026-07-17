-- Preserve compatibility with the current maintenance-command client while
-- preventing authenticated callers from rewriting immutable command fields or
-- mutating terminal audit records.

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

    if old.status = 'pending' and new.status not in ('accepted', 'completed', 'failed', 'expired') then
        raise exception 'Invalid transition from pending command'
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

drop trigger if exists mixpilot_guard_command_update
    on public.mixpilot_commands;
create trigger mixpilot_guard_command_update
before update on public.mixpilot_commands
for each row execute function public.mixpilot_guard_command_update();
