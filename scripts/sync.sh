#!/bin/bash
# Keeps the kit's managed files identical in every pipeline repo, with no person involved (the daily check runs it),
# and is the one way anything else lands a file in a pipeline repo (--put), since those never take commits on main.
# Managed (the one list; install.sh reads it): files the kit owns. A repo never edits them; its own settings live
# elsewhere (repo variable PIPELINE_DEPTH, REVIEW.md, dependabot.yml, backup.yml are the repo's and only seeded).
# Usage: sync.sh [--check | --list]   repos: every repo with the pipeline file, for each owner in ops OWN_OWNERS
#   --check  one line per repo that differs     --list  the managed files
#   (none)   each differing repo gets one PR writing the kit's versions (and dropping the old commands.yml)
#   --put <owner/repo> <path> <local file> [<base file>]   one PR writing that file at that path (ops' generated
#            files; the kit never holds their text). Refuses a managed path; does nothing when it already matches.
#            With <base file> (what the caller read and rendered from), refuses if the repo's copy changed since.
# Every PR is merged only when its checks pass, at the exact commit written, touching only the files it wrote.
set -uo pipefail # plain strings, no arrays: the Mac runs bash 3.2, where an empty array is "unbound"
case "${1:-}" in
  ""|--check|--list|--put) ;;
  --help|-h) sed -n '2,/^set /p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "FAILED: unknown option ${1} (--help lists them); nothing done"; exit 64 ;; # never a repair on a typo
esac
cd "$(dirname "$0")/.." || exit 1
MANAGED=".github/workflows/pipeline.yml .github/pull_request_template.md .claude/settings.json"
RETIRED=".github/workflows/commands.yml"
[ "${1:-}" = --list ] && { tr ' ' '\n' <<<"$MANAGED"; exit 0; }
# gh prints GitHub's error body on stdout too, so a missing file must give empty output, never that body
raw() { local c; c=$(gh api -H "Accept: application/vnd.github.raw" "repos/$1/contents/$2" 2>/dev/null) && printf '%s' "$c"; }
sha() { local s; s=$(gh api "repos/$1/contents/$2?ref=$3" --jq .sha 2>/dev/null) && printf '%s' "$s"; }

# deliver <repo> <branch> <title> <writes> <drops>: one self-merging PR. writes = "path=localfile ...", drops = "path ...".
deliver() {
  local r=$1 br=$2 title=$3 writes=$4 drops=$5 main head="" w f src old n c extra allowed=""
  main=$(gh api "repos/$r/git/ref/heads/main" --jq .object.sha) || { echo "FAILED: $r (no main)"; return 1; }
  gh api -X DELETE "repos/$r/git/refs/heads/$br" >/dev/null 2>&1
  gh api "repos/$r/git/refs" -f ref="refs/heads/$br" -f sha="$main" >/dev/null || { echo "FAILED: $r (branch)"; return 1; }
  drop_branch() { gh api -X DELETE "repos/$r/git/refs/heads/$br" >/dev/null 2>&1; } # a failed write never leaves a stray branch
  for w in $writes; do
    f=${w%%=*} src=${w#*=} allowed="$allowed $f"
    old=$(sha "$r" "$f" "$br") # empty for a new file; GitHub then ignores the sha field
    head=$(gh api -X PUT "repos/$r/contents/$f" -f message="ci: $f" -f branch="$br" \
      -f content="$(base64 < "$src" | tr -d '\n')" ${old:+-f sha="$old"} --jq .commit.sha) || { echo "FAILED: $r (write $f)"; drop_branch; return 1; }
  done
  for f in $drops; do
    allowed="$allowed $f"
    head=$(gh api -X DELETE "repos/$r/contents/$f" -f message="ci: drop $f" -f branch="$br" -f sha="$(sha "$r" "$f" "$br")" --jq .commit.sha) \
      || { echo "FAILED: $r (drop $f)"; drop_branch; return 1; }
  done
  n=$(gh api "repos/$r/pulls" -f head="$br" -f base=main -f title="$title" \
    -f body="Written by pipeline-guardrails scripts/sync.sh:$allowed. Merged by itself once checks pass." --jq .number) \
    || { echo "FAILED: $r (PR)"; drop_branch; return 1; }
  for _ in $(seq 60); do
    c=$(gh pr checks "$n" -R "$r" --json name,bucket --jq '[.[] | select(.name | test("checks / checks$"))][0].bucket' 2>/dev/null)
    [ -n "$c" ] && [ "$c" != pending ] && break; sleep 20
  done
  # Merge only exactly what was written: same head commit, no file outside the ones this call wrote or dropped
  extra=$(gh pr view "$n" -R "$r" --json files --jq '.files[].path' | grep -vxF -f <(tr ' ' '\n' <<<"$allowed") || true)
  [ "${c:-}" = pass ] && [ -z "$extra" ] || { echo "FAILED: $r#$n (checks ${c:-did not finish}${extra:+, unexpected files})"; return 1; }
  gh pr merge "$n" -R "$r" --squash --delete-branch --match-head-commit "$head" >/dev/null 2>&1 && return 0
  # A docs-only change is low risk, so the gate may have merged it first: that is success, not a failure
  [ "$(gh pr view "$n" -R "$r" --json state,headRefOid --jq 'select(.headRefOid == "'"$head"'") | .state')" = MERGED ] && return 0
  echo "FAILED: $r#$n (merge refused)"; return 1
}

if [ "${1:-}" = --put ]; then
  r=${2:?usage: sync.sh --put <owner/repo> <path> <local file> [<base file>]} f=${3:?path} src=${4:?local file} base=${5:-}
  [ -f "$src" ] || { echo "FAILED: no file $src"; exit 1; }
  [ -z "$base" ] || [ -f "$base" ] || { echo "FAILED: no file $base"; exit 1; }
  grep -qxF "$f" <(tr ' ' '\n' <<<"$MANAGED $RETIRED") && { echo "FAILED: $f is kit-managed; sync.sh owns it"; exit 1; }
  [ -n "$(raw "$r" .github/workflows/pipeline.yml)" ] || { echo "FAILED: $r has no pipeline; commit there directly"; exit 1; }
  cur=$(raw "$r" "$f")
  [ "$cur" = "$(cat "$src")" ] && { echo "same: $r $f"; exit 0; }
  [ -z "$base" ] || [ "$cur" = "$(cat "$base")" ] || { echo "FAILED: $r $f changed since it was read; render again"; exit 1; }
  deliver "$r" "ci/put-$(tr -c 'a-zA-Z0-9\n' - <<<"$f")" "ci: $f (generated)" "$f=$src" "" && echo "put: $r $f"
  exit $?
fi

owners=$(cd "$(paths get ops)" && python3 -m lib.config OWN_OWNERS) || { echo "FAILED: could not read OWN_OWNERS"; exit 1; }
for o in $owners; do
  if [ "$o" = hanna-fmw ]; then q="user/repos?affiliation=owner&per_page=100"; else q="orgs/$o/repos?per_page=100"; fi
  for r in $(gh api --paginate "$q" --jq '.[] | select(.archived | not) | .full_name'); do
    [ -n "$(raw "$r" .github/workflows/pipeline.yml)" ] || continue # no pipeline: not a pipeline repo
    stale="" names="" gone=""
    for f in $MANAGED; do [ "$(raw "$r" "$f")" = "$(cat "templates/$f")" ] || { stale="$stale $f=templates/$f"; names="$names $f"; }; done
    for f in $RETIRED; do [ -z "$(sha "$r" "$f" main)" ] || gone="$gone $f"; done
    [ -z "$stale$gone" ] && continue
    [ "${1:-}" = --check ] && { echo "differs: $r ($names$gone )"; continue; }
    deliver "$r" ci/pipeline-sync "ci: kit-managed files from pipeline-guardrails" "$stale" "$gone" && echo "synced: $r"
  done
done
