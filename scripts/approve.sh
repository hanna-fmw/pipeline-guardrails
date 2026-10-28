#!/bin/bash
# The owner's yes, as one step every session uses (README "Approving a PR"): run it only after the owner said yes.
# Usage: approve.sh <owner/repo> <pr> [worktree-to-remove]
# Adds owner-approved (which re-runs the gate), waits for the gate, merges itself only when the gate is green but
# its token may not merge (workflow-file PRs), then removes the given worktree. Prints one line; non-zero if not merged.
set -uo pipefail
repo=${1:?usage: approve.sh <owner/repo> <pr> [worktree]} pr=${2:?usage: approve.sh <owner/repo> <pr> [worktree]} wt=${3:-}
state() { gh pr view "$pr" -R "$repo" --json state -q .state; }
[ "$(state)" = OPEN ] || { echo "FAILED: $repo#$pr is not open"; exit 1; }
head=$(gh pr view "$pr" -R "$repo" --json headRefOid -q .headRefOid)
since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
gh pr edit "$pr" -R "$repo" --add-label owner-approved >/dev/null || { echo "FAILED: could not add owner-approved"; exit 1; }
# The label starts a gate run; wait (max 15 min) for a gate check on this commit that started after the label
for _ in $(seq 90); do
  sleep 10
  [ "$(state)" = MERGED ] && break
  g=$(gh api "repos/$repo/commits/$head/check-runs?per_page=100" \
    --jq "[.check_runs[] | select((.name | test(\"gate\")) and .started_at >= \"$since\")] | max_by(.started_at) | .conclusion // \"\"")
  [ -n "$g" ] && break
done
if [ "$(state)" != MERGED ]; then
  if [ "${g:-}" = success ]; then gh pr merge "$pr" -R "$repo" --squash --delete-branch --match-head-commit "$head" >/dev/null 2>&1
  else
    why=$(gh api "repos/$repo/issues/$pr/comments" --paginate --jq '[.[] | select(.body | startswith("<!-- pipeline:gate -->"))] | last | .body' | grep -m3 -- '- \[ \]' | sed 's/- \[ \] //' | paste -sd ';' -)
    echo "NOT MERGED: $repo#$pr: ${why:-gate did not finish in 15 minutes}"; exit 1
  fi
fi
[ "$(state)" = MERGED ] || { echo "FAILED: $repo#$pr: merge refused"; exit 1; }
if [ -n "$wt" ]; then git -C "$wt" worktree remove "$wt" 2>/dev/null || echo "kept worktree $wt (not clean)"; fi
echo "merged $repo#$pr; the host deploys main, the branch and Slack message are gone"
