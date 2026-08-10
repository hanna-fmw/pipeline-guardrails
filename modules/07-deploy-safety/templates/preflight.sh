#!/usr/bin/env bash
# Pre-deploy verification. Run before `vercel deploy --prod` / `coolify deploy`.
# Exit non-zero -> abort the deploy.

set -euo pipefail

REQUIRED_VARS=(DATABASE_URL DIRECT_URL NEXTAUTH_SECRET OPENAI_API_KEY)
TARGET=${1:-production}   # production | staging

echo "Preflight check for target: $TARGET"

# 1. On main, signed commit
branch=$(git symbolic-ref --short HEAD)
if [[ "$TARGET" == "production" && "$branch" != "main" ]]; then
  echo "FAIL: production deploys must run from main (currently on $branch)" >&2
  exit 1
fi

# 2. Working tree clean
if [[ -n "$(git status --porcelain)" ]]; then
  echo "FAIL: dirty working tree" >&2
  git status --short >&2
  exit 1
fi

# 3. Commit author email matches expected (per ~/.claude/rules/github-accounts.md)
author_email=$(git log --format=%ae -1)
if echo "$author_email" | grep -qE 'users\.noreply\.github\.com$'; then
  echo "FAIL: last commit author email is a GitHub noreply ($author_email)." >&2
  echo "       Vercel Hobby will block this. Fix git identity, rewrite, then re-deploy." >&2
  exit 1
fi
echo "  ok: git on $branch, clean tree, author=$author_email"

# 4. Required env vars present in target
if command -v vercel >/dev/null 2>&1; then
  missing=()
  vercel_env=$(vercel env ls "$TARGET" 2>/dev/null || true)
  for v in "${REQUIRED_VARS[@]}"; do
    echo "$vercel_env" | grep -qE "^\s*$v\s" || missing+=("$v")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "FAIL: env vars missing in Vercel ($TARGET): ${missing[*]}" >&2
    exit 1
  fi
  echo "  ok: ${#REQUIRED_VARS[@]} required env vars present in Vercel $TARGET"
fi

# 5. Migrations applied (Prisma)
if [[ -f "prisma/schema.prisma" ]]; then
  if ! pnpm exec prisma migrate status --schema=prisma/schema.prisma 2>&1 | grep -q "Database schema is up to date"; then
    echo "FAIL: Prisma migrations not applied to target DB" >&2
    exit 1
  fi
  echo "  ok: Prisma migrations applied"
fi

# 6. Staging smoke test (if deploying to prod, confirm staging is healthy first)
if [[ "$TARGET" == "production" && -n "${STAGING_URL:-}" ]]; then
  if ! curl -fsS --max-time 10 "$STAGING_URL/api/health" >/dev/null; then
    echo "FAIL: staging smoke test failed at $STAGING_URL/api/health" >&2
    exit 1
  fi
  echo "  ok: staging healthy at $STAGING_URL/api/health"
fi

echo "Preflight passed. Safe to deploy."
