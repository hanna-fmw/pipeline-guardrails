#!/usr/bin/env bash
# Stop hook — scan the assistant's final message for secret-shaped strings.
#
# Last line of defence. The PreToolUse blocker stops the agent reading a secret
# and the PostToolUse scrubber redacts it out of tool output; this catches the
# case where the model produced a credential-shaped string itself.
#
# Wire in ~/.claude/settings.json:
#   { "hooks": { "Stop": [ { "hooks": [
#       { "type": "command", "command": "~/.claude/hooks/scan-final-message.sh" } ] } ] } }
#
# Contract (docs: code.claude.com/docs/en/hooks):
#   stdin  — JSON with .last_assistant_message (use this; don't parse the transcript)
#   exit 0 — stdout is parsed as JSON output
#   exit 2 — blocks the stop and sends stderr to the model. NOT used here: the
#            secret is already in the transcript by this point, so blocking buys
#            nothing and risks a stop loop. Warn the human instead.
#
# It warns; it does not redact. Anything it fires on must be treated as
# compromised and rotated.
set -uo pipefail

INPUT="$(cat)"

command -v jq >/dev/null || exit 0   # never break a session over a missing tool

MESSAGE="$(printf '%s' "$INPUT" | jq -r '.last_assistant_message // ""')"
[ -z "$MESSAGE" ] && exit 0

# The rules are gitleaks' own (one rule set for CI, git hooks and these hooks; version pinned in
# .github/workflows/checks.yml). Report the rule that matched, never the value: this hook's own
# output would otherwise become the leak.
command -v gitleaks >/dev/null || { jq -n '{systemMessage: "scan-final-message.sh: gitleaks not installed, final message NOT scanned"}'; exit 0; }
HITS="$(printf '%s' "$MESSAGE" | gitleaks stdin --no-banner --redact --report-format json --report-path - --exit-code 0 2>/dev/null \
  | jq -r '.[]? | "  - gitleaks rule \(.RuleID)"' | sort -u)"

[ -z "$HITS" ] && exit 0

WARNING="SECRET-SHAPED STRING IN ASSISTANT OUTPUT
${HITS}
The value is already in this transcript. Treat it as compromised:
  1. Rotate the credential now.
  2. Check whether it also reached a commit, a log, or a shared link.
  3. If this is a false positive, add a gitleaks allowlist entry (.gitleaks.toml)."

jq -n --arg msg "$WARNING" '{systemMessage: $msg, suppressOutput: true}'
exit 0
