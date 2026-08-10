#!/usr/bin/env bash
# Create an isolated workspace for an agent session.
#
#   ./agent-workspace.sh feat/my-branch
#
# Gives the agent its own git worktree so it can never touch your working tree,
# and refuses to start if production-shaped credentials are loaded in the shell.
set -euo pipefail

BRANCH="${1:-}"
if [ -z "$BRANCH" ]; then
  echo "usage: $0 <branch-name>" >&2
  exit 1
fi

# --- 1. Don't build on top of unsaved human work ---
if [ -n "$(git status --porcelain)" ]; then
  echo "Working tree is dirty. Commit or stash before starting an agent session." >&2
  exit 1
fi

# --- 2. Production credentials must not be in scope ---
# Names only. Never print the values.
PROD_VARS="STRIPE_LIVE_KEY STRIPE_SECRET_KEY_LIVE DATABASE_URL_PROD PROD_DATABASE_URL
VERCEL_TOKEN AWS_SECRET_ACCESS_KEY SUPABASE_SERVICE_ROLE_KEY"
LOADED=""
for var in $PROD_VARS; do
  if [ -n "${!var:-}" ]; then
    LOADED="$LOADED $var"
  fi
done
if [ -n "$LOADED" ]; then
  echo "Production credentials are loaded in this shell:$LOADED" >&2
  echo "Run 'unset <VAR>' for each, then re-run. Do not start an agent with prod in scope." >&2
  exit 1
fi

# --- 3. Isolated worktree ---
REPO_ROOT="$(git rev-parse --show-toplevel)"
REPO_NAME="$(basename "$REPO_ROOT")"
WORKTREE="${REPO_ROOT}/../${REPO_NAME}-${BRANCH//\//-}"

if [ -d "$WORKTREE" ]; then
  echo "Worktree already exists: $WORKTREE"
else
  git worktree add "$WORKTREE" -b "$BRANCH"
fi

# --- 4. Dev-only env ---
# Symlink, so the agent session reads dev values and there is one file to rotate.
if [ -f "${REPO_ROOT}/.env.development" ]; then
  ln -sf "${REPO_ROOT}/.env.development" "${WORKTREE}/.env.local"
  echo "Linked .env.development -> .env.local"
else
  echo "No .env.development found. Create one before running the app in this worktree." >&2
fi

echo
echo "Workspace ready: $WORKTREE"
echo "Start the agent session from that directory."
echo "When finished: git worktree remove '$WORKTREE'"
