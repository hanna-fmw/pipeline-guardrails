#!/bin/bash
# Releases the kit: tags main as vX.Y.Z and moves the major tag (v1) that every repo pins.
# Refuses unless main is pushed and selftest passed on that exact commit.
# Usage: release.sh vX.Y.Z      (a breaking change is a new major: v2.0.0, then repos move one by one)
set -euo pipefail
v=${1:?usage: release.sh vX.Y.Z}
[[ $v =~ ^v([0-9]+)\.[0-9]+\.[0-9]+$ ]] || { echo "FAILED: version must look like v1.2.0"; exit 1; }
major="v${BASH_REMATCH[1]}"
cd "$(dirname "$0")/.."
git fetch -q origin main --tags
sha=$(git rev-parse origin/main)
[ "$(git rev-parse HEAD)" = "$sha" ] || { echo "FAILED: check out origin/main first (HEAD is not it)"; exit 1; }
runs=$(gh api "repos/hanna-fmw/pipeline-guardrails/actions/workflows/selftest.yml/runs?head_sha=$sha&event=push" --jq '[.workflow_runs[] | .conclusion]')
jq -e 'index("success") != null' <<<"$runs" >/dev/null || { echo "FAILED: selftest has not passed on $sha (runs: $runs)"; exit 1; }
git tag -a "$v" -m "$v" "$sha"
git tag -fa "$major" -m "$major -> $v" "$sha"
git push -q origin "$v" && git push -q -f origin "$major"
echo "released $v; $major now points at it"
