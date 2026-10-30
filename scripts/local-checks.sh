#!/bin/bash
# Runs, in the current repo, the same package scripts and Python tests the pipeline's checks job runs (read from
# checks.yml, the one list), so fmw-ship proves a change locally exactly as CI will. Prints each command's last lines.
# Usage: local-checks.sh   (in the repo; exits non-zero on the first failure)
set -uo pipefail
[ $# -eq 0 ] || { [ "$1" = --help ] && { sed -n '2,4p' "$0" | sed 's/^# //'; exit 0; }; echo "FAILED: local-checks.sh takes no options (--help)"; exit 64; }
kit="$(cd "$(dirname "$0")/.." && pwd)"
list=$(grep -oE 'for s in [a-z ]+; do # the one list' "$kit/.github/workflows/checks.yml" | sed -E 's/for s in ([a-z ]+); do.*/\1/')
[ -n "$list" ] || { echo "FAILED: could not read the script list from checks.yml"; exit 1; }
py=$(grep -oE '[^ ].* # the one Python test command' "$kit/.github/workflows/checks.yml" | sed 's/ # the one.*//')
[ -n "$py" ] || { echo "FAILED: could not read the Python test command from checks.yml"; exit 1; }
if compgen -G "tests/test_*.py" >/dev/null; then
  if out=$($py 2>&1); then echo "ok   $py: $(tail -1 <<<"$out")"; else echo "FAIL $py:"; tail -15 <<<"$out"; exit 1; fi
fi
[ -f package.json ] || { echo "No package.json: no package scripts to run."; exit 0; }
pm=npm; [ -f pnpm-lock.yaml ] && pm=pnpm
for s in $list; do
  jq -e --arg s "$s" '.scripts[$s]' package.json >/dev/null || { echo "skip $s (no script)"; continue; }
  if out=$($pm run "$s" 2>&1); then echo "ok   $pm run $s: $(tail -1 <<<"$out")"
  else echo "FAIL $pm run $s:"; tail -15 <<<"$out"; exit 1; fi
done
