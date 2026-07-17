-- The command RPCs intentionally remain callable by authenticated device users,
-- but they do not need elevated database privileges. RLS and table grants are
-- sufficient because every statement filters on auth.uid().

alter function public.claim_mixpilot_commands(uuid, text, integer)
    security invoker;

alter function public.complete_mixpilot_command(uuid, text, boolean, jsonb, text)
    security invoker;
