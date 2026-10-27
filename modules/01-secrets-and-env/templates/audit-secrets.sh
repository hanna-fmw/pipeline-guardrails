#!/usr/bin/env bash
# Verify every env var in .env.example is documented in docs/SECRETS.md, and
# vice versa. Run from a pre-push hook, or in CI.
#
# Names only — this script never reads a value, and .env itself is never opened.
set -uo pipefail

EXAMPLE="${1:-.env.example}"
INVENTORY="${2:-docs/SECRETS.md}"

[ -f "$EXAMPLE" ]   || { echo "missing $EXAMPLE" >&2; exit 1; }
[ -f "$INVENTORY" ] || { echo "missing $INVENTORY — every project needs a secrets inventory" >&2; exit 1; }

# Variable names: strip comments and blanks, take the LHS of =.
# POSIX classes, not \s — \s is a GNU extension and silently fails to match
# under the BSD sed that ships with macOS.
example_vars=$(grep -vE '^\s*(#|$)' "$EXAMPLE" | sed -E 's/^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=.*/\2/' | sort -u)

# Variable names mentioned anywhere in the inventory (table cells, backticks, prose)
inventory_vars=$(grep -oE '\b[A-Z][A-Z0-9_]{2,}\b' "$INVENTORY" | sort -u)

missing_from_inventory=$(comm -23 <(printf '%s\n' "$example_vars") <(printf '%s\n' "$inventory_vars"))
missing_from_example=$(comm -13 <(printf '%s\n' "$example_vars") <(printf '%s\n' "$inventory_vars"))

status=0

if [ -n "$missing_from_inventory" ]; then
  echo "Env vars in $EXAMPLE but NOT documented in $INVENTORY:" >&2
  # shellcheck disable=SC2086 # a word list, split on purpose
  printf '  %s\n' $missing_from_inventory >&2
  echo "  -> add owner, scope, and rotation date for each." >&2
  status=1
fi

# Informational only: the inventory legitimately mentions words like PROD or API
# that are not variables, so this side is a prompt to look, not a failure.
if [ -n "$missing_from_example" ]; then
  echo "Names in $INVENTORY with no matching entry in $EXAMPLE (check for a removed or renamed var):" >&2
  # shellcheck disable=SC2086 # a word list, split on purpose
  printf '  %s\n' $missing_from_example >&2
fi

[ $status -eq 0 ] && echo "secrets inventory in sync"
exit $status
