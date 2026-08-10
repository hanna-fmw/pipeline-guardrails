#!/usr/bin/env bash
# Pre-push hook: enforce branch naming convention.
# Wire via .husky/pre-push (append after the existing typecheck/test steps).

set -euo pipefail

branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")

# Allowed long-lived branches
allowed_static=("main" "staging" "develop")
for b in "${allowed_static[@]}"; do
  [ "$branch" = "$b" ] && exit 0
done

# Allowed pattern: type/short-slug, type ∈ feat|fix|chore|refactor|docs|test|hotfix
if ! echo "$branch" | grep -E -q '^(feat|fix|chore|refactor|docs|test|hotfix)/[a-z0-9][a-z0-9._-]+$'; then
  echo "BLOCKED: branch '$branch' does not match the naming convention." >&2
  echo "Expected: <type>/<short-slug>  e.g. feat/stripe-webhooks, fix/login-loop" >&2
  echo "Rename:   git branch -m feat/your-slug" >&2
  exit 1
fi
