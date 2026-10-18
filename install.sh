#!/usr/bin/env bash
# Put the pipeline into a repo: install.sh <repo-folder>
# Copies the templates (never overwrites your own REVIEW.md, PR template or Claude settings),
# sets the GitHub repo to squash-only merges, and sets the Claude token secret from the macOS Keychain.
set -euo pipefail
kit="$(cd "$(dirname "$0")" && pwd)/templates"
repo="$(cd "${1:?usage: install.sh <repo-folder>}" && pwd)"
cd "$repo"
slug=$(gh repo view --json nameWithOwner --jq .nameWithOwner)

for f in .github/workflows/pipeline.yml .github/workflows/commands.yml .github/dependabot.yml \
         .github/pull_request_template.md REVIEW.md .claude/settings.json; do
  if [ -e "$f" ] && [ "$f" != .github/workflows/pipeline.yml ] && [ "$f" != .github/workflows/commands.yml ]; then
    echo "kept    $f (already exists)"
  else
    mkdir -p "$(dirname "$f")"; cp "$kit/$f" "$f"; echo "wrote   $f"
  fi
done
git add -f .claude/settings.json # global gitignores often hide .claude/; this file is meant to be shared

gh repo edit "$slug" --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false \
  --delete-branch-on-merge >/dev/null
gh api -X PUT "repos/$slug/actions/permissions/workflow" \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true >/dev/null
echo "set     squash-only merges, branch cleanup, Actions may open PRs (for /revert)"

if security find-generic-password -s claude-ci-oauth >/dev/null 2>&1; then
  security find-generic-password -s claude-ci-oauth -w | gh secret set CLAUDE_CODE_OAUTH_TOKEN -R "$slug"
  echo "set     CLAUDE_CODE_OAUTH_TOKEN secret (from Keychain item claude-ci-oauth)"
else
  echo "TODO    Claude token: run 'claude setup-token', then store it once with:"
  echo "        security add-generic-password -s claude-ci-oauth -a \"\$USER\" -w"
  echo "        and run this script again."
fi
echo "TODO    Claude GitHub App must have access to $slug: https://github.com/apps/claude"
