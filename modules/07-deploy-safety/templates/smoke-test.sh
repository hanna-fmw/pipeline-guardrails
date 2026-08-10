#!/usr/bin/env bash
# Post-deploy smoke test. Run immediately after deploy + on a 5-min schedule for 1h.

set -euo pipefail

URL=${1:?usage: smoke-test.sh <base_url>}

# Endpoints to probe + expected response signals.
declare -a probes=(
  "/api/health|200|ok"
  "/|200|<html"
  "/api/auth/session|200|"
)

fail=0
for probe in "${probes[@]}"; do
  IFS='|' read -r path want_code want_body <<<"$probe"
  response=$(curl -s -o /tmp/smoke.body -w "%{http_code}" --max-time 10 "$URL$path" || echo "000")
  if [[ "$response" != "$want_code" ]]; then
    echo "FAIL: $path expected $want_code, got $response" >&2
    fail=1
    continue
  fi
  if [[ -n "$want_body" ]] && ! grep -q "$want_body" /tmp/smoke.body; then
    echo "FAIL: $path body did not contain '$want_body'" >&2
    fail=1
    continue
  fi
  echo "ok:   $path -> $response"
done

exit $fail
