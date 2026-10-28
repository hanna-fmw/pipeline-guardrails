#!/bin/bash
# Keeps every pipeline repo's one pipeline file identical to the kit's template, with no person involved.
# Usage: sync.sh [--check]   repos: those the register lists (python3 -m lib.config OWN_OWNERS, from ops)
# --check prints one line per repo that differs. Without it, each differing repo gets a PR that writes the
# template (and drops the old commands.yml) and is merged once its checks pass. Prints one line per repo.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
tpl=templates/.github/workflows/pipeline.yml f=.github/workflows/pipeline.yml br=ci/pipeline-sync
owners=$(cd "$(paths get ops)" && python3 -m lib.config OWN_OWNERS) || { echo "FAILED: could not read OWN_OWNERS"; exit 1; }
for o in $owners; do
  if [ "$o" = hanna-fmw ]; then q="user/repos?affiliation=owner&per_page=100"; else q="orgs/$o/repos?per_page=100"; fi
  for r in $(gh api --paginate "$q" --jq '.[] | select(.archived | not) | .full_name'); do
    cur=$(gh api -H "Accept: application/vnd.github.raw" "repos/$r/contents/$f" 2>/dev/null) || continue # no pipeline: not a pipeline repo
    old=$(gh api "repos/$r/contents/.github/workflows/commands.yml" --jq .sha 2>/dev/null || true)
    [ "$cur" = "$(cat "$tpl")" ] && [ -z "$old" ] && continue
    [ "${1:-}" = --check ] && { echo "differs: $r"; continue; }
    main=$(gh api "repos/$r/git/ref/heads/main" --jq .object.sha) || { echo "FAILED: $r (no main)"; continue; }
    gh api -X DELETE "repos/$r/git/refs/heads/$br" >/dev/null 2>&1
    gh api "repos/$r/git/refs" -f ref="refs/heads/$br" -f sha="$main" >/dev/null || { echo "FAILED: $r (branch)"; continue; }
    gh api -X PUT "repos/$r/contents/$f" -f message="ci: pipeline file from the kit template" -f branch="$br" \
      -f content="$(base64 < "$tpl" | tr -d '\n')" -f sha="$(gh api "repos/$r/contents/$f" --jq .sha)" >/dev/null || { echo "FAILED: $r (write)"; continue; }
    [ -z "$old" ] || gh api -X DELETE "repos/$r/contents/.github/workflows/commands.yml" -f message="ci: commands.yml folded into the kit's router" \
      -f branch="$br" -f sha="$old" >/dev/null || { echo "FAILED: $r (delete commands.yml)"; continue; }
    n=$(gh api "repos/$r/pulls" -f head="$br" -f base=main -f title="ci: pipeline file from the kit template" \
      -f body="Written by pipeline-guardrails scripts/sync.sh: the repo's one pipeline file, identical in every repo. Merged by itself once checks pass." --jq .number) \
      || { echo "FAILED: $r (PR)"; continue; }
    for _ in $(seq 60); do
      c=$(gh pr checks "$n" -R "$r" --json name,bucket --jq '[.[] | select(.name | test("checks / checks$"))][0].bucket' 2>/dev/null)
      [ -n "$c" ] && [ "$c" != pending ] && break; sleep 20
    done
    if [ "${c:-}" = pass ] && gh pr merge "$n" -R "$r" --squash --delete-branch >/dev/null 2>&1; then echo "synced: $r"
    else echo "FAILED: $r#$n (checks ${c:-did not finish})"; fi
  done
done
