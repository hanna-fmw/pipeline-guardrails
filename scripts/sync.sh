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
#   --drop <owner/repo> <path> [<base file>]   the same, removing that file (nothing to do when it is absent).
#   --export <dir>   the released kit's templates into <dir>/templates (install.sh writes a new repo from them)
#   --retire <owner/repo> <path>   one PR deleting that retired kit file: what her yes in bb's queue runs, since
#            deleting waits for her (layer review, layer 4); a plain sync only asks
# The kit's files always come from a clean copy of the released tag v1, what every repo runs, never this checkout
# (layer review, layer 4): a local edit or an unreleased commit never reaches a repo.
# Every PR is merged only when its checks pass, at the exact commit written, touching only the files it wrote.
set -uo pipefail # plain strings, no arrays: the Mac runs bash 3.2, where an empty array is "unbound"
case "${1:-}" in
  ""|--check|--list|--put|--drop|--export|--retire) ;;
  --help|-h) sed -n '2,/^set /p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "FAILED: unknown option ${1} (--help lists them); nothing done"; exit 64 ;; # never a repair on a typo
esac
cd "$(dirname "$0")/.." || exit 1
# Main's newest commit, only when its self-test passed: nothing from main runs here before that
green_main() {
  local sha
  git fetch -q origin main || return 1
  sha=$(git rev-parse origin/main) || return 1
  gh api "repos/hanna-fmw/pipeline-guardrails/actions/workflows/selftest.yml/runs?head_sha=$sha&event=push" --jq '[.workflow_runs[] | .conclusion]' | jq -e 'index("success") != null' >/dev/null || return 1
  echo "$sha"
}
# The daily repair runs this from her main checkout, which nothing else updates: move it to main's latest green commit
if [ -z "${1:-}" ] && [ "$(git branch --show-current)" = main ] && green=$(green_main) && [ "$(git rev-parse HEAD)" != "$green" ]; then
  if git merge -q --ff-only "$green"; then exec bash scripts/sync.sh "$@"; fi
  echo "FAILED: could not update the kit's main checkout; running it as it is" >&2
fi
MANAGED=".github/workflows/pipeline.yml .github/pull_request_template.md .claude/settings.json"
RETIRED=".github/workflows/commands.yml"
[ "${1:-}" = --list ] && { tr ' ' '\n' <<<"$MANAGED"; exit 0; }
released() { # fails closed: a managed file missing or empty in the release stops everything
  git fetch -q --force origin 'refs/tags/v1:refs/tags/v1' && mkdir -p "$1" && git archive v1 templates | tar -x -C "$1" || return 1
  local f; for f in $MANAGED; do [ -s "$1/templates/$f" ] || { echo "FAILED: $f is missing in the released kit"; return 1; }; done
}
if [ "${1:-}" = --export ]; then released "${2:?usage: sync.sh --export <dir>}" || { echo "FAILED: could not read the released kit (v1)"; exit 1; }; exit 0; fi
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
  # The gate merges a low-risk or light-mode PR itself once checks pass: give it 2 minutes first, so the two never race
  merged() { [ "$(gh pr view "$n" -R "$r" --json state,headRefOid --jq 'select(.headRefOid == "'"$head"'") | .state')" = MERGED ]; }
  for _ in $(seq 12); do merged && return 0; sleep 10; done
  gh pr merge "$n" -R "$r" --squash --delete-branch --match-head-commit "$head" >/dev/null 2>&1 && return 0
  sleep 10; merged && return 0
  echo "FAILED: $r#$n (merge refused)"; return 1
}

if [ "${1:-}" = --drop ]; then
  r=${2:?usage: sync.sh --drop <owner/repo> <path> [<base file>]} f=${3:?path} base=${4:-}
  grep -qxF "$f" <(tr ' ' '\n' <<<"$MANAGED $RETIRED") && { echo "FAILED: $f is kit-managed; sync.sh owns it"; exit 1; }
  [ -n "$(raw "$r" .github/workflows/pipeline.yml)" ] || { echo "FAILED: $r has no pipeline; commit there directly"; exit 1; }
  [ -n "$(sha "$r" "$f" main)" ] || { echo "same: $r $f (absent)"; exit 0; }
  [ -z "$base" ] || [ "$(raw "$r" "$f")" = "$(cat "$base")" ] || { echo "FAILED: $r $f changed since it was read"; exit 1; }
  deliver "$r" "ci/put-$(tr -c 'a-zA-Z0-9\n' - <<<"$f")" "ci: drop $f (generated)" "" "$f" && echo "dropped: $r $f"
  exit $?
fi
if [ "${1:-}" = --retire ]; then
  r=${2:?usage: sync.sh --retire <owner/repo> <path>} f=${3:?path}
  grep -qxF "$f" <(tr ' ' '\n' <<<"$RETIRED") || { echo "FAILED: $f is not a retired kit file"; exit 1; }
  [ -n "$(sha "$r" "$f" main)" ] || { echo "same: $r $f (absent)"; exit 0; }
  deliver "$r" ci/pipeline-retire "ci: drop retired $f" "" "$f" && echo "dropped: $r $f"
  exit $?
fi
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

# The canary (layer review, layer 4): a new release runs first in the one repo with GitHub topic pipeline-canary,
# as a PR whose pipeline file calls that exact version. v1, which every repo runs, moves to it only when that run
# used the release's own commit throughout (GitHub's referenced_workflows) and its checks and both reviews passed;
# the PR is then closed. A failed canary leaves v1 where it is, keeps the PR open and is reported.
canary() {
  local latest at c f stub br main head n run id ok gate d green
  # A green main not yet released gets its tag here, in a throwaway checkout: this one may be anyone's working copy.
  # Main not green yet is no failure: the release waits and the repos are still repaired.
  if [ "${1:-}" != --check ]; then
    if green=$(green_main); then
      d=$(mktemp -d)
      git worktree add -q --detach "$d" "$green" || { echo "FAILED: could not check out main to release it"; return 1; }
      bash "$d/scripts/release.sh" patch || { git worktree remove --force "$d"; return 1; }
      git worktree remove --force "$d"
    else echo "waiting: main has no passing self-test yet, so no new release"; fi
  fi
  git fetch -q --force origin 'refs/tags/*:refs/tags/*' || { echo "FAILED: could not read the kit's tags"; return 1; }
  latest=$(git tag -l 'v*.*.*' --sort=-v:refname | head -1); at=$(git rev-parse "$latest^{commit}")
  [ "$at" != "$(git rev-parse 'v1^{commit}')" ] || return 0
  [ "${1:-}" = --check ] && { echo "waiting: $latest for its canary run; repos still run the previous release"; return 0; }
  for o in $owners; do c=$(gh search repos --owner "$o" --topic pipeline-canary --json fullName --jq '.[0].fullName // empty'); [ -n "$c" ] && break; done
  [ -n "${c:-}" ] || { echo "FAILED: no repo has the topic pipeline-canary; v1 stays"; return 1; }
  stub=$(mktemp); git show "$latest:templates/.github/workflows/pipeline.yml" | sed "s#router.yml@v1#router.yml@$latest#" > "$stub"
  br="ci/canary-$latest" f=.github/workflows/pipeline.yml
  main=$(gh api "repos/$c/git/ref/heads/main" --jq .object.sha) || { echo "FAILED: $c (no main)"; return 1; }
  gh api -X DELETE "repos/$c/git/refs/heads/$br" >/dev/null 2>&1
  gh api "repos/$c/git/refs" -f ref="refs/heads/$br" -f sha="$main" >/dev/null || { echo "FAILED: $c (branch)"; return 1; }
  head=$(gh api -X PUT "repos/$c/contents/$f" -f message="ci: canary $latest" -f branch="$br" \
    -f content="$(base64 < "$stub" | tr -d '\n')" -f sha="$(sha "$c" "$f" "$br")" --jq .commit.sha) || { echo "FAILED: $c (write)"; return 1; }
  n=$(gh api "repos/$c/pulls" -f head="$br" -f base=main -f title="ci: kit canary $latest" \
    -f body=$'Written by pipeline-guardrails scripts/sync.sh: this repo\'s pipeline on kit '"$latest"$' before every other repo. Closed by itself when it passes.\n\n## Issue\nNo issue: the kit\'s canary run.' --jq .number) \
    || { echo "FAILED: $c (PR)"; return 1; }
  for _ in $(seq 120); do # up to 40 minutes
    run=$(gh api "repos/$c/actions/runs?head_sha=$head&event=pull_request" --jq '[.workflow_runs[] | select(.path == ".github/workflows/pipeline.yml")] | min_by(.created_at) // empty')
    [ -n "$run" ] && [ "$(jq -r .status <<<"$run")" = completed ] && break; sleep 20
  done
  ok=false id=$(jq -r '.id // empty' <<<"${run:-}")
  gate=$(gh api "repos/$c/issues/$n/comments" --jq '[.[] | select(.body | startswith("<!-- pipeline:gate -->"))] | last.body // ""' | grep '^- \[ \]')
  # every kit file it ran came from the release (GitHub reports an annotated tag's own id, not its commit's); checks green (no Claude review here: its action refuses a
  # PR that changes its workflow file, so the reviews are not tried by this run); the gate's only blocker
  # is the owner approval a workflow change always needs
  if [ -n "$id" ] \
     && jq -e --arg s "$at" --arg t "$(git rev-parse "$latest")" '[.referenced_workflows[]? | select(.path | startswith("hanna-fmw/pipeline-guardrails/"))] | length > 0 and all(.sha == $s or .sha == $t)' <<<"$run" >/dev/null \
     && [ "$(gh api "repos/$c/actions/runs/$id/jobs" --jq '[.jobs[] | select(.name | test("checks / checks")) | .conclusion] | length == 1 and all(. == "success")')" = true ] \
     && [ "$(wc -l <<<"$gate" | tr -d ' ')" = 1 ] && grep -q '^- \[ \] Owner approval required' <<<"$gate"; then ok=true; fi
  if [ "$ok" = true ]; then
    gh pr close "$n" -R "$c" --delete-branch >/dev/null
    if ! { git tag -fa v1 -m "v1 -> $latest" "$at" && git push -q -f origin v1; }; then echo "FAILED: could not move v1 to $latest"; return 1; fi
    echo "canary passed: v1 -> $latest ($c#$n)"
  else
    (cd "$(paths get ops)" && python3 -m lib.notify "Kit $latest failed its canary run in $c#$n, so no repo got it (v1 stays). https://github.com/$c/pull/$n")
    echo "FAILED: canary $latest ($c#$n)"; return 1
  fi
}
canary "${1:-}" || exit 1

rel=$(mktemp -d); trap 'rm -rf "$rel"' EXIT
released "$rel" || { echo "FAILED: could not read the released kit (v1)"; exit 1; }
for o in $owners; do
  if [ "$o" = hanna-fmw ]; then q="user/repos?affiliation=owner&per_page=100"; else q="orgs/$o/repos?per_page=100"; fi
  for r in $(gh api --paginate "$q" --jq '.[] | select(.archived | not) | .full_name'); do
    [ -n "$(raw "$r" .github/workflows/pipeline.yml)" ] || continue # no pipeline: not a pipeline repo
    stale="" names="" gone=""
    for f in $MANAGED; do [ "$(raw "$r" "$f")" = "$(cat "$rel/templates/$f")" ] || { stale="$stale $f=$rel/templates/$f"; names="$names $f"; }; done
    for f in $RETIRED; do [ -z "$(sha "$r" "$f" main)" ] || gone="$gone $f"; done
    [ -z "$stale$gone" ] && continue
    [ "${1:-}" = --check ] && { echo "differs: $r ($names$gone )"; continue; }
    [ -z "$stale" ] || { deliver "$r" ci/pipeline-sync "ci: kit-managed files from pipeline-guardrails" "$stale" "" && echo "synced: $r"; }
    for f in $gone; do # her yes in bb's queue runs the deletion; the same open question is asked only once
      (cd "$(paths get ops)" && python3 -c 'import sys; from lib import asks; asks.add("pipeline-kit", sys.argv[1], resume=sys.argv[2:])' \
        "Delete the retired kit file $f in $r?" "$(paths get pipeline-guardrails)/scripts/sync.sh" --retire "$r" "$f") >/dev/null \
        && echo "asked: $r $f (her yes in bb deletes it)" || echo "FAILED: $r $f (could not ask)"
    done
  done
done
