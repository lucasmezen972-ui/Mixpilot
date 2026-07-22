-- Qualify every outer-row reference explicitly. The previous policy used
-- `s.device_id = device_id`, which PostgreSQL could resolve as the tautology
-- `s.device_id = s.device_id` inside the correlated subquery.

drop policy if exists owners_insert_events on public.mixpilot_events;
create policy owners_insert_events
on public.mixpilot_events for insert
to authenticated
with check (
    mixpilot_events.owner_id = (select auth.uid())
    and exists (
        select 1
        from public.mixpilot_devices d
        where d.id = mixpilot_events.device_id
          and d.owner_id = (select auth.uid())
    )
    and (
        mixpilot_events.session_id is null
        or exists (
            select 1
            from public.mixpilot_sessions s
            where s.id = mixpilot_events.session_id
              and s.device_id = mixpilot_events.device_id
              and s.owner_id = (select auth.uid())
        )
    )
);

-- Fail fresh rebuilds if the policy ever compiles back into the tautological
-- form that motivated this migration.
do $$
declare
    policy_expression text;
begin
    select pg_get_expr(p.polwithcheck, p.polrelid)
      into policy_expression
      from pg_policy p
      join pg_class c on c.oid = p.polrelid
      join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public'
       and c.relname = 'mixpilot_events'
       and p.polname = 'owners_insert_events';

    if policy_expression is null then
        raise exception 'owners_insert_events policy is missing';
    end if;
    if policy_expression like '%s.device_id = s.device_id%' then
        raise exception 'owners_insert_events contains a tautological session/device comparison';
    end if;
    if policy_expression not like '%s.device_id = mixpilot_events.device_id%' then
        raise exception 'owners_insert_events must bind the session to the outer event device';
    end if;
end
$$;
