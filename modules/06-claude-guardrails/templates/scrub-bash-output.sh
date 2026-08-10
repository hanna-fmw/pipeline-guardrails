#!/usr/bin/env bash
# PostToolUse hook for Claude Code.
# Redacts known secret formats from Bash output before Claude sees it.
#
# Wire in ~/.claude/settings.json:
#   "hooks": { "PostToolUse": [ { "matcher": "Bash",
#     "hooks": [ { "type": "command", "command": "~/.claude/hooks/scrub-bash-output.sh" } ] } ] }
#
# Contract (https://code.claude.com/docs/en/hooks):
#   stdin  — JSON with .tool_name, .tool_input, .tool_response
#   output — {"hookSpecificOutput":{"hookEventName":"PostToolUse",
#             "updatedToolOutput":"<text>"}}
#            updatedToolOutput is a STRING that replaces the tool's text output.
#            Rewriting the stdin envelope and echoing it back does nothing:
#            this envelope is the only thing Claude Code reads.
#
# Emits nothing when there is no match, so untouched output passes through.

set -uo pipefail

INPUT="$(cat)"

PY_BIN="$(command -v python3 || true)"
if [ -z "$PY_BIN" ]; then
  # Fail loud, not open: a silent no-op scrubber is worse than none, because
  # you stop watching for the thing it was supposed to catch.
  echo "scrub-bash-output.sh: python3 not found — output NOT scrubbed" >&2
  exit 1
fi

# The payload goes in as argv[1]. Passing it on stdin would collide with the
# heredoc that carries the program itself.
"$PY_BIN" - "$INPUT" <<'PY'
import sys, json, re

# Ordered most-specific first: sk-ant- must be tried before the generic sk-,
# or Anthropic keys get labelled as OpenAI ones and the later rule is dead.
PATTERNS = [
    (re.compile(r'AKIA[0-9A-Z]{16}'), '[REDACTED_AWS_KEY_ID]'),
    (re.compile(r'ASIA[0-9A-Z]{16}'), '[REDACTED_AWS_TEMP_KEY_ID]'),
    (re.compile(r'aws_secret_access_key\s*=\s*[A-Za-z0-9/+=]{40}'), 'aws_secret_access_key=[REDACTED]'),
    (re.compile(r'gh[pousr]_[A-Za-z0-9]{36,255}'), '[REDACTED_GITHUB_TOKEN]'),
    (re.compile(r'github_pat_[A-Za-z0-9_]{60,}'), '[REDACTED_GITHUB_PAT]'),
    (re.compile(r'glpat-[A-Za-z0-9_-]{20,}'), '[REDACTED_GITLAB_PAT]'),
    (re.compile(r'sk-ant-[A-Za-z0-9_-]{20,}'), '[REDACTED_ANTHROPIC_KEY]'),
    # Modern OpenAI keys carry a hyphen after the prefix (sk-proj-, sk-svcacct-,
    # sk-admin-), which a [A-Za-z0-9]{32,} class cannot cross.
    (re.compile(r'sk-(?:proj|svcacct|admin)-[A-Za-z0-9_-]{20,}'), '[REDACTED_OPENAI_KEY]'),
    (re.compile(r'sk-[A-Za-z0-9]{20,}'), '[REDACTED_OPENAI_KEY]'),
    (re.compile(r'sk_live_[A-Za-z0-9]{24,}'), '[REDACTED_STRIPE_LIVE]'),
    (re.compile(r'rk_live_[A-Za-z0-9]{24,}'), '[REDACTED_STRIPE_RESTRICTED]'),
    (re.compile(r'whsec_[A-Za-z0-9]{20,}'), '[REDACTED_STRIPE_WEBHOOK]'),
    (re.compile(r'sb_secret_[A-Za-z0-9_-]{20,}'), '[REDACTED_SUPABASE_SECRET]'),
    (re.compile(r'sbp_[a-f0-9]{40}'), '[REDACTED_SUPABASE_PAT]'),
    (re.compile(r'xox[baprs]-[A-Za-z0-9-]{10,}'), '[REDACTED_SLACK_TOKEN]'),
    (re.compile(r'AIza[0-9A-Za-z_-]{35}'), '[REDACTED_GOOGLE_KEY]'),
    (re.compile(r'dop_v1_[a-f0-9]{64}'), '[REDACTED_DIGITALOCEAN]'),
    (re.compile(r'shp(?:at|ss|pa)_[a-f0-9]{32}'), '[REDACTED_SHOPIFY]'),
    (re.compile(r'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'), '[REDACTED_JWT]'),
    (re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'), '[REDACTED_PRIVATE_KEY]'),
    (re.compile(r'(postgres(?:ql)?|mongodb(?:\+srv)?)://([^:@/\s]+):[^@\s]+@'), r'\1://\2:[REDACTED]@'),
    (re.compile(r'(?i)(api[_-]?key|secret|token|password)(\s*[:=]\s*)[\'"]?[A-Za-z0-9_\-]{20,}[\'"]?'),
     r'\1\2[REDACTED]'),
]

def scrub(s):
    for pat, repl in PATTERNS:
        s = pat.sub(repl, s)
    return s

try:
    payload = json.loads(sys.argv[1])
except (IndexError, ValueError):
    sys.exit(0)

resp = payload.get("tool_response")

# tool_response is a string for some tools and an object for others.
if isinstance(resp, str):
    original = resp
elif isinstance(resp, dict):
    original = "".join(
        str(resp[k]) for k in ("stdout", "stderr", "output") if isinstance(resp.get(k), str)
    )
else:
    sys.exit(0)

if not original:
    sys.exit(0)

cleaned = scrub(original)
if cleaned == original:
    sys.exit(0)   # nothing matched — leave the real output alone

json.dump({
    "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "updatedToolOutput": cleaned,
    }
}, sys.stdout)
PY
