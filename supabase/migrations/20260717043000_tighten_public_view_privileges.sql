-- Supabase grants broad default table privileges to API roles on newly created
-- views. The views are security_invoker and their base tables use RLS, but the
-- client only needs authenticated SELECT access.

revoke all privileges on public.mixpilot_latest_mapping_releases from anon, authenticated;
revoke all privileges on public.mixpilot_active_compatibility_overrides from anon, authenticated;
revoke all privileges on public.mixpilot_device_health from anon, authenticated;

grant select on public.mixpilot_latest_mapping_releases to authenticated;
grant select on public.mixpilot_active_compatibility_overrides to authenticated;
grant select on public.mixpilot_device_health to authenticated;
