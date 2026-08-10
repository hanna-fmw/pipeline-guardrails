#!/usr/bin/env bash
# PreToolUse hook for Claude Code.
# Blocks tool calls that target known-sensitive paths.
# Exit 2 -> the call is blocked and Claude must adjust. Any other non-zero exit
# is a NON-BLOCKING error: the tool call proceeds. That is why the python
# lookups below must not be allowed to fail silently.
#
# Wire in ~/.claude/settings.json (Edit and Write matter as much as Read — a
# hook that only guards Read leaves `Edit .env` wide open):
#   "hooks": { "PreToolUse": [ { "matcher": "Read|Edit|Write|Grep|Glob|Bash",
#     "hooks": [ { "type": "command", "command": "~/.claude/hooks/block-secret-paths.sh" } ] } ] }
#
# Claude Code passes the tool call as JSON on stdin.

set -uo pipefail

input="$(cat)"

PY_BIN="$(command -v python3 || true)"
if [ -z "$PY_BIN" ]; then
  # Fail CLOSED. Without an interpreter this hook cannot inspect the call, and
  # exiting non-zero-but-not-2 would let it through with only a transcript notice.
  echo "block-secret-paths.sh: python3 not found — cannot verify this call, blocking." >&2
  exit 2
fi

tool=$(printf '%s' "$input" | "$PY_BIN" -c 'import sys,json;print(json.load(sys.stdin).get("tool_name",""))' 2>/dev/null || echo "")
payload=$(printf '%s' "$input" | "$PY_BIN" -c 'import sys,json;print(json.dumps(json.load(sys.stdin).get("tool_input",{})))' 2>/dev/null || echo "{}")

# Patterns that should never be touched
blocked_patterns=(
  '\.env($|\.)'
  '\.pem($|[^a-zA-Z])'
  '\.key($|[^a-zA-Z])'
  'id_rsa'
  'id_ed25519'
  '/\.aws/'
  '/\.ssh/'
  '/\.config/gh/'
  '/Library/Application Support/Google/Chrome/.*Cookies'
  '/Library/Application Support/com.vercel.cli/auth\.json'
  '1Password.*\.(1pif|opvault|agilekeychain)'
)

# Every tool names its target differently; check all the plausible fields
# rather than switching on the tool name, so a new tool is covered by default.
target=$(printf '%s' "$payload" | "$PY_BIN" -c '
import sys, json
d = json.load(sys.stdin)
fields = ("file_path", "path", "command", "notebook_path", "pattern", "glob")
print("\n".join(str(d[f]) for f in fields if isinstance(d.get(f), str)))
' 2>/dev/null || echo "")

for pat in "${blocked_patterns[@]}"; do
  if echo "$target" | grep -E -q "$pat"; then
    echo "BLOCKED by pipeline-guardrails: '$tool' targets sensitive path matching /$pat/" >&2
    echo "If you need the variable NAME, check it without reading the value (e.g. 'test -n \"\$VAR\" && echo set')." >&2
    exit 2
  fi
done

exit 0
