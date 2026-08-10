#!/usr/bin/env bash
# PreToolUse hook for Claude Code.
# Blocks Read/Bash invocations that target known-sensitive paths.
# Exit non-zero -> Claude receives a permission denial and must adjust.
#
# Wire in ~/.claude/settings.json:
#   "hooks": { "PreToolUse": [ { "matcher": "Read|Bash",
#     "hooks": [ { "type": "command", "command": "~/.claude/hooks/block-secret-paths.sh" } ] } ] }
#
# Claude Code passes the tool call as JSON on stdin.

set -euo pipefail

input="$(cat)"
tool=$(echo "$input" | /usr/bin/python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("tool_name",""))' 2>/dev/null || echo "")
payload=$(echo "$input" | /usr/bin/python3 -c 'import sys,json;d=json.load(sys.stdin);print(json.dumps(d.get("tool_input",{})))' 2>/dev/null || echo "{}")

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

target=""
case "$tool" in
  Read)
    target=$(echo "$payload" | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin).get("file_path",""))')
    ;;
  Bash)
    target=$(echo "$payload" | /usr/bin/python3 -c 'import sys,json;print(json.load(sys.stdin).get("command",""))')
    ;;
esac

for pat in "${blocked_patterns[@]}"; do
  if echo "$target" | grep -E -q "$pat"; then
    echo "BLOCKED by pipeline-guardrails: '$tool' targets sensitive path matching /$pat/" >&2
    echo "If you need the variable NAME, check it without reading the value (e.g. 'test -n \"\$VAR\" && echo set')." >&2
    exit 2
  fi
done

exit 0
