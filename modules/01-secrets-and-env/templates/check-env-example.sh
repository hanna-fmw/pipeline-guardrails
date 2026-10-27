#!/usr/bin/env bash
# Pre-commit guard: every process.env.X / os.getenv("X") referenced in code
# must have a matching line in .env.example. Forces .env.example to stay current.
#
# Wire via husky:
#   .husky/pre-commit -> bash ./scripts/check-env-example.sh

set -euo pipefail

EXAMPLE=".env.example"
if [[ ! -f "$EXAMPLE" ]]; then
  echo "No $EXAMPLE found — skipping env var audit. Create one." >&2
  exit 0
fi

# Extract var names declared in .env.example (lines like FOO=)
declared=$(grep -E '^[A-Z_][A-Z0-9_]*=' "$EXAMPLE" | cut -d= -f1 | sort -u)

# Find references in source. Adjust the globs/extensions for your stack.
referenced=$(grep -REho \
  -e 'process\.env\.[A-Z_][A-Z0-9_]*' \
  -e 'os\.getenv\(["'"'"']([A-Z_][A-Z0-9_]*)["'"'"']\)' \
  --include='*.ts' --include='*.tsx' --include='*.js' --include='*.jsx' \
  --include='*.py' --include='*.rb' \
  --exclude-dir=node_modules --exclude-dir=.next --exclude-dir=dist \
  . 2>/dev/null \
  | sed -E 's/.*process\.env\.([A-Z_][A-Z0-9_]*).*/\1/; s/.*getenv\(["'"'"']([A-Z_][A-Z0-9_]*)["'"'"']\).*/\1/' \
  | sort -u)

missing=$(comm -23 <(echo "$referenced") <(echo "$declared") | grep -v '^$' || true)
if [[ -n "$missing" ]]; then
  echo "ERROR: env vars used in code but missing from $EXAMPLE:" >&2
  echo "$missing" | sed 's/^/  - /' >&2 # shellcheck disable=SC2001
  echo "" >&2
  echo "Add them to $EXAMPLE (names only, no values), then re-commit." >&2
  exit 1
fi

echo "env-example audit OK ($(echo "$declared" | wc -l | tr -d ' ') vars declared, all references covered)"
