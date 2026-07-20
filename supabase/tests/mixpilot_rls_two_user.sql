begin;

create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;

select plan(14);

insert into auth.users (
    id, aud, role, email, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
(
    '10000000-0000-0000-0000-000000000001',
    'authenticated', 'authenticated', 'user-a@mixpilot.test', now(),
    '{}'::jsonb, '{}'::jsonb, now(), now()
),
(
    '20000000-0000-0000-0000-000000000002',
    'authenticated', 'authenticated', 'user-b@mixpilot.test', now(),
    '{}'::jsonb, '{}'::jsonb, now(), now()
);

insert into public.mixpilot_devices (id, owner_id, installation_id, device_name)
values
(
    '11000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '11100000-0000-0000-0000-000000000001',
    'User A Mac'
),
(
    '22000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000002',
    '22200000-0000-0000-0000-000000000002',
    'User B Mac'
);

insert into public.mixpilot_sessions (id, owner_id, device_id, app_version, app_build)
values
(
    '13000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '11000000-0000-0000-0000-000000000001',
    'test', 1
),
(
    '23000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000002',
    '22000000-0000-0000-0000-000000000002',
    'test', 1
);

insert into public.mixpilot_events (
    owner_id, device_id, session_id, category, name, severity, client_event_id
) values (
    '20000000-0000-0000-0000-000000000002',
    '22000000-0000-0000-0000-000000000002',
    '23000000-0000-0000-0000-000000000002',
    'test', 'user_b_event', 'info',
    '24000000-0000-0000-0000-000000000002'
);

insert into public.mixpilot_commands (
    id, owner_id, device_id, expires_at, command, payload, idempotency_key
) values
(
    '15000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '11000000-0000-0000-0000-000000000001',
    now() + interval '1 hour', 'check_for_update', '{}'::jsonb,
    '15100000-0000-0000-0000-000000000001'
),
(
    '25000000-0000-0000-0000-000000000002',
    '20000000-0000-0000-0000-000000000002',
    '22000000-0000-0000-0000-000000000002',
    now() + interval '1 hour', 'check_for_update', '{}'::jsonb,
    '25100000-0000-0000-0000-000000000002'
);

select set_config(
    'request.jwt.claims',
    '{"sub":"10000000-0000-0000-0000-000000000001","role":"authenticated"}',
    true
);
select set_config(
    'request.jwt.claim.sub',
    '10000000-0000-0000-0000-000000000001',
    true
);
set local role authenticated;

select is(
    (select count(*)::integer from public.mixpilot_devices),
    1,
    'user A sees only their own device'
);

select is(
    (select count(*)::integer from public.mixpilot_sessions),
    1,
    'user A sees only their own initial session'
);

select lives_ok(
    $$insert into public.mixpilot_sessions (
        id, owner_id, device_id, app_version, app_build
    ) values (
        '13100000-0000-0000-0000-000000000001',
        '10000000-0000-0000-0000-000000000001',
        '11000000-0000-0000-0000-000000000001',
        'test', 2
    )$$,
    'user A can create a session for their own device'
);

select throws_ok(
    $$insert into public.mixpilot_sessions (
        id, owner_id, device_id, app_version, app_build
    ) values (
        '13200000-0000-0000-0000-000000000001',
        '10000000-0000-0000-0000-000000000001',
        '22000000-0000-0000-0000-000000000002',
        'test', 3
    )$$,
    '42501',
    null,
    'user A cannot attach a session to user B device'
);

select lives_ok(
    $$insert into public.mixpilot_events (
        owner_id, device_id, session_id, category, name, severity, client_event_id
    ) values (
        '10000000-0000-0000-0000-000000000001',
        '11000000-0000-0000-0000-000000000001',
        '13000000-0000-0000-0000-000000000001',
        'test', 'user_a_event', 'info',
        '14000000-0000-0000-0000-000000000001'
    )$$,
    'user A can create an event for their own matching session and device'
);

select throws_ok(
    $$insert into public.mixpilot_events (
        owner_id, device_id, session_id, category, name, severity, client_event_id
    ) values (
        '10000000-0000-0000-0000-000000000001',
        '11000000-0000-0000-0000-000000000001',
        '23000000-0000-0000-0000-000000000002',
        'test', 'cross_session_event', 'info',
        '14100000-0000-0000-0000-000000000001'
    )$$,
    '42501',
    null,
    'user A cannot attach an event to user B session'
);

select is(
    (select count(*)::integer from public.mixpilot_events),
    1,
    'user A sees only their own event'
);

select is(
    (
        select count(*)::integer
        from public.claim_mixpilot_commands(
            '11000000-0000-0000-0000-000000000001',
            'agent-user-a-0001',
            10
        )
    ),
    1,
    'user A atomically claims their own pending command'
);

select is(
    (
        select count(*)::integer
        from public.claim_mixpilot_commands(
            '22000000-0000-0000-0000-000000000002',
            'agent-user-a-0001',
            10
        )
    ),
    0,
    'user A cannot claim a command belonging to user B device'
);

select is(
    public.complete_mixpilot_command(
        '15000000-0000-0000-0000-000000000001',
        'wrong-agent-0001',
        true,
        '{}'::jsonb,
        null
    ),
    false,
    'a different agent cannot complete the claimed command'
);

select is(
    public.complete_mixpilot_command(
        '15000000-0000-0000-0000-000000000001',
        'agent-user-a-0001',
        true,
        '{"result":"ok"}'::jsonb,
        null
    ),
    true,
    'the claiming agent can complete the command exactly once'
);

select is(
    public.complete_mixpilot_command(
        '15000000-0000-0000-0000-000000000001',
        'agent-user-a-0001',
        true,
        '{}'::jsonb,
        null
    ),
    false,
    'duplicate completion is rejected without rewriting audit data'
);

select ok(
    not has_table_privilege('authenticated', 'public.mixpilot_commands', 'UPDATE'),
    'authenticated has no direct UPDATE privilege on commands'
);

select is(
    (select count(*)::integer from public.mixpilot_commands),
    1,
    'user A sees only their own command audit row'
);

select * from finish();
rollback;
