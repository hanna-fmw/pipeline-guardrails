#!/usr/bin/env bash
# Bootstrap local hooks for a new (or existing) repo. Idempotent.
# Run from the repo root: bash setup.sh

set -euo pipefail

# 1. Verify git-guard is installed globally
if [ ! -f "$HOME/.git-hooks/pre-commit" ]; then
  echo "git-guard not installed. Install: https://github.com/hanna-fmw/git-guard" >&2
  exit 1
fi

# 2. Global gitignore + global hooks path.
# NOTE: git honours ONE core.hooksPath. husky (step 4) sets a repo-local one,
# which overrides this for any repo that uses husky — there, the scans are
# invoked from .husky/pre-commit instead. This global path only covers repos
# without husky.
git config --global core.hooksPath "$HOME/.git-hooks"
if [ ! -f "$HOME/.gitignore_global" ]; then
  cp "$(dirname "$0")/.gitignore_global" "$HOME/.gitignore_global"
fi
git config --global core.excludesFile "$HOME/.gitignore_global"

# 3. Install gitleaks if missing
if ! command -v gitleaks >/dev/null 2>&1; then
  echo "Installing gitleaks..."
  brew install gitleaks
fi

# 4. husky + lint-staged
if [ -f package.json ]; then
  # Pin husky: v10 removes the hook preamble these templates no longer use,
  # but an unpinned major upgrade is not something a commit hook should discover.
  pnpm add -D husky@^9 lint-staged
  pnpm exec husky init
  cp "$(dirname "$0")/.husky/pre-commit" .husky/pre-commit
  cp "$(dirname "$0")/.husky/pre-push" .husky/pre-push
  chmod +x .husky/pre-commit .husky/pre-push
  echo "husky + lint-staged installed. Add lint-staged config to package.json (see module README)."
fi

echo "Local hooks bootstrap complete."
