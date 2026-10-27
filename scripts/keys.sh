#!/bin/bash
# The one place the kit reads keys. Keys live in Infisical (build-system foundation plan); to change
# where keys come from, change only this file. Never prints a value except to a pipe (`get`).
#   keys.sh get <project id> <env> <folder> <NAME>                  value on stdout, for $(...) or a pipe
#   keys.sh to-github <owner/repo> <project id> <env> <folder> NAME...  same-named GitHub Actions secrets
set -euo pipefail
get() { infisical secrets get "$4" --projectId "$1" --env "$2" --path "$3" --plain --silent 2>/dev/null | tr -d '\n'; }
case "${1:-}" in
  get) shift; get "$@" ;;
  to-github)
    repo=$2 pid=$3 env=$4 folder=$5; shift 5; missing=0
    for n in "$@"; do
      if [ -n "$(get "$pid" "$env" "$folder" "$n" | head -c1)" ]; then
        get "$pid" "$env" "$folder" "$n" | gh secret set "$n" -R "$repo"; echo "set     $n secret (Infisical $folder)"
      else echo "MISSING $n: add it in Infisical, folder $folder, then run again"; missing=1; fi
    done
    exit $missing ;;
  *) sed -n 2,6p "$0"; exit 1 ;;
esac
