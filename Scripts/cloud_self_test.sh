#!/usr/bin/env bash
set -euo pipefail

PROJECT_URL="${MIXPILOT_SUPABASE_URL:-https://cqppkklfugbixpxwitab.supabase.co}"
PUBLISHABLE_KEY="${MIXPILOT_SUPABASE_PUBLISHABLE_KEY:-sb_publishable_yzMOwGa4gFubk9QIFEkaEA_E2RM9CIb}"
AUTH_RESPONSE="$(mktemp)"
RPC_RESPONSE="$(mktemp)"
trap 'rm -f "$AUTH_RESPONSE" "$RPC_RESPONSE"' EXIT

curl --fail-with-body --silent --show-error \
  --request POST \
  --header "apikey: ${PUBLISHABLE_KEY}" \
  --header "Content-Type: application/json" \
  --data '{}' \
  "${PROJECT_URL}/auth/v1/signup" > "$AUTH_RESPONSE"

ACCESS_TOKEN="$(python3 - "$AUTH_RESPONSE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as handle:
    payload = json.load(handle)
token = payload.get('access_token')
if not token:
    raise SystemExit('Anonymous authentication returned no access_token')
print(token)
PY
)"

curl --fail-with-body --silent --show-error \
  --request POST \
  --header "apikey: ${PUBLISHABLE_KEY}" \
  --header "Authorization: Bearer ${ACCESS_TOKEN}" \
  --header "Content-Type: application/json" \
  --data '{}' \
  "${PROJECT_URL}/rest/v1/rpc/mixpilot_cloud_self_test" > "$RPC_RESPONSE"

python3 - "$RPC_RESPONSE" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as handle:
    payload = json.load(handle)
if not isinstance(payload, list) or len(payload) != 1:
    raise SystemExit(f'Unexpected self-test payload: {payload!r}')
row = payload[0]
if row.get('authenticated') is not True or row.get('user_id_present') is not True:
    raise SystemExit(f'Cloud self-test did not authenticate: {row!r}')
for key in ('published_mapping_count', 'published_release_count', 'checked_at'):
    if key not in row:
        raise SystemExit(f'Missing {key} in cloud self-test')
print(json.dumps(row, ensure_ascii=False, sort_keys=True))
PY
