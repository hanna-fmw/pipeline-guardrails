#!/usr/bin/env bash
# Inventory of what is connected to your agent: MCP servers, plugins, hooks.
#
# Prints NAMES ONLY. MCP launch commands routinely carry access tokens in their
# arguments, so this script never prints config values, and you should never run
# `claude mcp list` / `claude mcp get` to answer the same question — those print
# the full command line, tokens included.
set -euo pipefail

CONFIG="${HOME}/.claude.json"
SETTINGS="${HOME}/.claude/settings.json"

command -v jq >/dev/null || { echo "jq required" >&2; exit 1; }

echo "=== MCP servers ==="
if [ -f "$CONFIG" ]; then
  jq -r '.mcpServers // {} | keys[]' "$CONFIG" 2>/dev/null | sed 's/^/  /' || echo "  (none)"
else
  echo "  no ~/.claude.json"
fi

echo
echo "=== Unpinned versions (auto-updating with your credentials) ==="
# Matches @latest or a bare package with no version in the args array.
if [ -f "$CONFIG" ]; then
  jq -r '
    .mcpServers // {} | to_entries[]
    | select((.value.args // []) | map(test("@latest$")) | any)
    | "  " + .key + "  <- pinned to @latest"
  ' "$CONFIG" 2>/dev/null || true
fi

echo
echo "=== Project-local MCP config ==="
for f in .mcp.json .claude/settings.local.json; do
  [ -f "$f" ] && echo "  found: $f (review it — project configs are easy to forget)"
done

echo
echo "=== Hooks ==="
if [ -f "$SETTINGS" ]; then
  jq -r '.hooks // {} | keys[]' "$SETTINGS" 2>/dev/null | sed 's/^/  /' || echo "  (none)"
fi

echo
echo "=== Plugins ==="
if [ -d "${HOME}/.claude/plugins" ]; then
  find "${HOME}/.claude/plugins" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sed 's/^/  /'
else
  echo "  (none)"
fi

echo
echo "Review: anything unused since last audit should be disconnected."
echo "Each server should hold its own scoped credential, revocable on its own."
