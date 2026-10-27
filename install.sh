#!/usr/bin/env bash
# Put the pipeline into a repo: install.sh <repo-folder>
# Copies the templates (never overwrites your own REVIEW.md, PR template or Claude settings),
# sets the GitHub repo to squash-only merges, and sets the Claude and Slack secrets from Infisical.
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
if gh api -X PUT "repos/$slug/actions/permissions/workflow" \
  -f default_workflow_permissions=read -F can_approve_pull_request_reviews=true >/dev/null 2>&1; then
  echo "set     squash-only merges, branch cleanup, Actions may open PRs (for /revert)"
else # an organization can forbid that per repo; /revert then needs the org setting
  gh api -X PUT "repos/$slug/actions/permissions/workflow" -f default_workflow_permissions=read >/dev/null
  echo "set     squash-only merges, branch cleanup"
  echo "TODO    /revert: allow Actions to create PRs in the org's Actions settings"
fi
gh label create ai:auto -R "$slug" --color 0E8A16 --description "An agent may do this alone and open a PR" --force >/dev/null
gh label create ai:pair -R "$slug" --color 1D76DB --description "An agent works on this together with Hanna" --force >/dev/null
gh label create ai:working -R "$slug" --color FBCA04 --description "An agent is working on it now" --force >/dev/null
echo "set     labels ai:auto, ai:pair, ai:working"

# Keys come from Infisical project "personal", env dev, folder /github (scripts/keys.sh)
"$(dirname "$kit")/scripts/keys.sh" to-github "$slug" f45535b0-69ef-422f-a292-9cfefd4bdbc1 dev /github \
  CLAUDE_CODE_OAUTH_TOKEN SLACK_BOT_TOKEN || echo "        (Claude token: 'claude setup-token'; Slack: the agents bot token)"
echo "TODO    Claude GitHub App must have access to $slug: https://github.com/apps/claude"
