-- The clients now verify detached Ed25519 signatures against an embedded
-- publisher public key. The database also rejects malformed signature encodings
-- before a mapping or app release can enter a published state.

create or replace function mixpilot_private.is_ed25519_signature(value text)
returns boolean
language plpgsql
immutable
strict
set search_path = pg_catalog
as $$
declare
    decoded bytea;
begin
    decoded := decode(value, 'base64');
    return octet_length(decoded) = 64;
exception
    when others then
        return false;
end;
$$;

revoke all on function mixpilot_private.is_ed25519_signature(text)
    from public, anon, authenticated;

create or replace function public.mixpilot_guard_mapping_publication()
returns trigger
language plpgsql
set search_path = pg_catalog, public, mixpilot_private
as $$
begin
    if new.status = 'published' then
        if new.published_at is null or new.rollout_percentage <= 0 then
            raise exception 'Published mappings require published_at and rollout_percentage > 0';
        end if;
        if not coalesce(mixpilot_private.is_ed25519_signature(new.publisher_signature), false) then
            raise exception 'Published mappings require a valid Ed25519 signature encoding';
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
        if new.channel = 'stable'
           and coalesce(new.validation_summary->>'device_validation', '') <> 'passed' then
            raise exception 'Stable mappings require real device validation';
        end if;
    end if;
    return new;
end;
$$;

create or replace function public.mixpilot_guard_release_publication()
returns trigger
language plpgsql
set search_path = pg_catalog, public, mixpilot_private
as $$
begin
    if new.status = 'published' then
        if new.published_at is null or new.rollout_percentage <= 0 then
            raise exception 'Published releases require published_at and rollout_percentage > 0';
        end if;
        if not coalesce(mixpilot_private.is_ed25519_signature(new.signature), false) then
            raise exception 'Published releases require a valid Ed25519 signature encoding';
        end if;
        if not mixpilot_private.is_allowed_distribution_url(new.download_url) then
            raise exception 'Release download URL is not on the MixPilot allowlist';
        end if;
        if new.release_page_url is not null
           and not mixpilot_private.is_allowed_distribution_url(new.release_page_url) then
            raise exception 'Release page URL is not on the MixPilot allowlist';
        end if;
    end if;
    return new;
end;
$$;

revoke all on function public.mixpilot_guard_mapping_publication()
    from public, anon, authenticated;
revoke all on function public.mixpilot_guard_release_publication()
    from public, anon, authenticated;

-- Validate the helper itself during every fresh migration rebuild.
do $$
begin
    if not mixpilot_private.is_ed25519_signature(
        encode(decode(repeat('00', 64), 'hex'), 'base64')
    ) then
        raise exception 'Ed25519 signature shape helper rejected a 64-byte value';
    end if;
    if mixpilot_private.is_ed25519_signature('not-a-signature') then
        raise exception 'Ed25519 signature shape helper accepted malformed data';
    end if;
end
$$;
