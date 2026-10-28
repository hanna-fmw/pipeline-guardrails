#!/bin/bash
# The owner's yes, as one step every session uses (README "Approving a PR"): run it only after the owner said yes.
# Usage: approve.sh <owner/repo> <pr> [worktree-to-remove]
# Adds owner-approved, which re-runs the gate; the gate merges a green PR. Waits up to 15 minutes for the merge,
# then removes the given worktree. It never merges itself and never prints PR text: a PR's own workflows can fake
# a check or a bot comment, so only GitHub's merged state counts. Prints one line; non-zero if not merged.
set -uo pipefail
repo=${1:?usage: approve.sh <owner/repo> <pr> [worktree]} pr=${2:?usage: approve.sh <owner/repo> <pr> [worktree]} wt=${3:-}
url="https://github.com/$repo/pull/$pr"
state() { gh pr view "$pr" -R "$repo" --json state -q .state; }
[ "$(state)" = OPEN ] || { echo "FAILED: $url is not open"; exit 1; }
gh pr edit "$pr" -R "$repo" --add-label owner-approved >/dev/null || { echo "FAILED: could not add owner-approved to $url"; exit 1; }
for _ in $(seq 90); do
  sleep 10
  [ "$(state)" = MERGED ] && break
done
if [ "$(state)" != MERGED ]; then
  echo "NOT MERGED: $url (the gate comment there says what is missing; a PR that changes workflow files needs the owner's Squash and merge)"
  exit 1
fi
if [ -n "$wt" ]; then git -C "$wt" worktree remove "$wt" 2>/dev/null || echo "kept worktree $wt (not clean)"; fi
echo "merged $url; the host deploys main, the branch and Slack message are gone"
