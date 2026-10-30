#!/bin/bash
# The one place the kit reads keys. Keys live in Infisical (build-system foundation plan); to change
# where keys come from, change only this file. Never prints a value except to a pipe (`get`).
#   keys.sh get <project id> <env> <folder> <NAME>                  value on stdout, for $(...) or a pipe
#   keys.sh to-github <owner/repo> <project id> <env> <folder> NAME...  same-named GitHub secrets, for Actions and for
#                                                                    Dependabot (its runs get only its own secrets)
set -euo pipefail
get() { infisical secrets get "$4" --projectId "$1" --env "$2" --path "$3" --plain --silent 2>/dev/null | tr -d '\n'; }
case "${1:-}" in
  get) shift; get "$@" ;;
  to-github)
    repo=$2 pid=$3 env=$4 folder=$5; shift 5; missing=0
    for n in "$@"; do
      if [ -n "$(get "$pid" "$env" "$folder" "$n" | head -c1)" ]; then
        for app in actions dependabot; do get "$pid" "$env" "$folder" "$n" | gh secret set "$n" --app "$app" -R "$repo"; done
        echo "set     $n secret (Infisical $folder)"
      else echo "MISSING $n: add it in Infisical, folder $folder, then run again"; missing=1; fi
    done
    exit $missing ;;
  *) sed -n 2,7p "$0"; exit 1 ;;
esac
