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

# Format-class detectors. Keep in sync with gitleaks upstream rules.
# Deliberately narrow: a false positive here nags on every turn and gets the
# hook disabled, which is worse than the leak it was meant to catch.
PATTERNS=(
  'AKIA[0-9A-Z]{16}'                        # AWS access key id
  'ASIA[0-9A-Z]{16}'                        # AWS temporary key id
  'gh[pousr]_[A-Za-z0-9]{36,}'              # GitHub PAT / OAuth / refresh
  'github_pat_[A-Za-z0-9_]{60,}'            # GitHub fine-grained PAT
  'sk-(proj|svcacct|admin)-[A-Za-z0-9_-]{20,}'  # OpenAI (current)
  'sk-[A-Za-z0-9]{32,}'                     # OpenAI (legacy)
  'sk-ant-[A-Za-z0-9_-]{20,}'               # Anthropic
  'sk_live_[A-Za-z0-9]{20,}'                # Stripe live secret
  'rk_live_[A-Za-z0-9]{20,}'                # Stripe live restricted
  'whsec_[A-Za-z0-9]{20,}'                  # Stripe webhook signing
  'sb_secret_[A-Za-z0-9_-]{20,}'            # Supabase secret key
  'sbp_[a-f0-9]{40}'                        # Supabase personal access token
  'xox[baprs]-[A-Za-z0-9-]{10,}'            # Slack
  'AIza[0-9A-Za-z_-]{35}'                   # Google API key
  'glpat-[A-Za-z0-9_-]{20,}'                # GitLab PAT
  'dop_v1_[a-f0-9]{64}'                     # DigitalOcean
  'shp(at|ss|pa)_[a-f0-9]{32}'              # Shopify
  'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'  # JWT
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'      # private key block
  'postgres(ql)?://[^:]+:[^@]+@'            # connection string with password
  'mongodb(\+srv)?://[^:]+:[^@]+@'
)

HITS=""
for pat in "${PATTERNS[@]}"; do
  # `--` matters: patterns starting with `-` are otherwise read as grep options.
  if printf '%s' "$MESSAGE" | grep -qE -- "$pat"; then
    # Report the pattern that matched, never the value that matched it —
    # this hook's own output would otherwise become the leak.
    HITS="${HITS}  - matched /${pat}/"$'\n'
  fi
done

[ -z "$HITS" ] && exit 0

WARNING="SECRET-SHAPED STRING IN ASSISTANT OUTPUT
${HITS}
The value is already in this transcript. Treat it as compromised:
  1. Rotate the credential now.
  2. Check whether it also reached a commit, a log, or a shared link.
  3. If this is a false positive, narrow the pattern in scan-final-message.sh."

jq -n --arg msg "$WARNING" '{systemMessage: $msg, suppressOutput: true}'
exit 0
