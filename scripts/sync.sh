#!/bin/bash
# Keeps the kit's managed files identical in every pipeline repo, with no person involved (the daily check runs it).
# Managed (the one list; install.sh reads it): files the kit owns. A repo never edits them; its own settings live
# elsewhere (repo variable PIPELINE_DEPTH, REVIEW.md, dependabot.yml, backup.yml are the repo's and only seeded).
# Usage: sync.sh [--check | --list]   repos: every repo with the pipeline file, for each owner in ops OWN_OWNERS
#   --check  one line per repo that differs     --list  the managed files
#   (none)   each differing repo gets one PR writing the kit's versions (and dropping the old commands.yml),
#            merged only when its checks pass, at the exact commit written, touching only those files.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
MANAGED=".github/workflows/pipeline.yml .github/pull_request_template.md .claude/settings.json"
RETIRED=".github/workflows/commands.yml"
br=ci/pipeline-sync
[ "${1:-}" = --list ] && { tr ' ' '\n' <<<"$MANAGED"; exit 0; }
raw() { gh api -H "Accept: application/vnd.github.raw" "repos/$1/contents/$2" 2>/dev/null; }
sha() { gh api "repos/$1/contents/$2?ref=$3" --jq .sha 2>/dev/null; }
owners=$(cd "$(paths get ops)" && python3 -m lib.config OWN_OWNERS) || { echo "FAILED: could not read OWN_OWNERS"; exit 1; }
for o in $owners; do
  if [ "$o" = hanna-fmw ]; then q="user/repos?affiliation=owner&per_page=100"; else q="orgs/$o/repos?per_page=100"; fi
  for r in $(gh api --paginate "$q" --jq '.[] | select(.archived | not) | .full_name'); do
    raw "$r" .github/workflows/pipeline.yml >/dev/null || continue # no pipeline: not a pipeline repo
    stale=() gone=()
    for f in $MANAGED; do [ "$(raw "$r" "$f")" = "$(cat "templates/$f")" ] || stale+=("$f"); done
    for f in $RETIRED; do [ -z "$(sha "$r" "$f" main)" ] || gone+=("$f"); done
    [ ${#stale[@]} -eq 0 ] && [ ${#gone[@]} -eq 0 ] && continue
    [ "${1:-}" = --check ] && { echo "differs: $r (${stale[*]} ${gone[*]})"; continue; }
    main=$(gh api "repos/$r/git/ref/heads/main" --jq .object.sha) || { echo "FAILED: $r (no main)"; continue; }
    gh api -X DELETE "repos/$r/git/refs/heads/$br" >/dev/null 2>&1
    gh api "repos/$r/git/refs" -f ref="refs/heads/$br" -f sha="$main" >/dev/null || { echo "FAILED: $r (branch)"; continue; }
    head="" ok=true
    for f in "${stale[@]}"; do
      old=$(sha "$r" "$f" "$br"); args=(-f message="ci: $f from the kit" -f branch="$br" -f content="$(base64 < "templates/$f" | tr -d '\n')")
      [ -z "$old" ] || args+=(-f sha="$old")
      head=$(gh api -X PUT "repos/$r/contents/$f" "${args[@]}" --jq .commit.sha) || { ok=false; break; }
    done
    for f in "${gone[@]}"; do
      head=$(gh api -X DELETE "repos/$r/contents/$f" -f message="ci: drop $f (now in the kit)" -f branch="$br" -f sha="$(sha "$r" "$f" "$br")" --jq .commit.sha) || { ok=false; break; }
    done
    $ok || { echo "FAILED: $r (write)"; continue; }
    n=$(gh api "repos/$r/pulls" -f head="$br" -f base=main -f title="ci: kit-managed files from pipeline-guardrails" \
      -f body="Written by pipeline-guardrails scripts/sync.sh: ${stale[*]} ${gone[*]}. Merged by itself once checks pass." --jq .number) \
      || { echo "FAILED: $r (PR)"; continue; }
    for _ in $(seq 60); do
      c=$(gh pr checks "$n" -R "$r" --json name,bucket --jq '[.[] | select(.name | test("checks / checks$"))][0].bucket' 2>/dev/null)
      [ -n "$c" ] && [ "$c" != pending ] && break; sleep 20
    done
    # Merge only exactly what this script wrote: same head commit, no file outside the managed and retired lists
    extra=$(gh pr view "$n" -R "$r" --json files --jq '.files[].path' | grep -vxF -f <(tr ' ' '\n' <<<"$MANAGED $RETIRED") || true)
    if [ "${c:-}" = pass ] && [ -z "$extra" ] && gh pr merge "$n" -R "$r" --squash --delete-branch --match-head-commit "$head" >/dev/null 2>&1
    then echo "synced: $r"; else echo "FAILED: $r#$n (checks ${c:-did not finish}${extra:+, unexpected files})"; fi
  done
done
