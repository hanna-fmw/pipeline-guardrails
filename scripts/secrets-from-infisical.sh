#!/bin/bash
# Fills a repo's GitHub Actions secrets from Infisical, the one place keys live. Prints no values.
# Usage: secrets-from-infisical.sh <owner/repo> <infisical project id> <env> <folder> NAME...
# Each NAME is read from that Infisical folder and saved under the same name in GitHub.
set -euo pipefail
repo=$1 pid=$2 env=$3 folder=$4; shift 4
missing=0
for n in "$@"; do
  v=$(infisical secrets get "$n" --projectId "$pid" --env "$env" --path "$folder" --plain --silent 2>/dev/null | tr -d '\n' || true)
  if [ -n "$v" ]; then printf '%s' "$v" | gh secret set "$n" -R "$repo"; echo "set     $n"
  else echo "MISSING $n (not in Infisical $folder)"; missing=1; fi
done
exit $missing
