#!/usr/bin/env bash
# PostToolUse hook for Claude Code.
# Scrubs known secret formats from Bash tool output before Claude sees it.
# Wire in ~/.claude/settings.json:
#   "hooks": { "PostToolUse": [ { "matcher": "Bash",
#     "hooks": [ { "type": "command", "command": "~/.claude/hooks/scrub-bash-output.sh" } ] } ] }

set -euo pipefail

input="$(cat)"

# Regex patterns are based on gitleaks defaults; extend as new providers appear.
# We rewrite the tool_response.stdout/stderr fields in the JSON envelope.

/usr/bin/python3 <<'PY'
import sys, json, re

PATTERNS = [
    # AWS
    (re.compile(r'AKIA[0-9A-Z]{16}'), '[REDACTED_AWS_KEY]'),
    (re.compile(r'aws_secret_access_key\s*=\s*[A-Za-z0-9/+=]{40}'), 'aws_secret_access_key=[REDACTED]'),
    # GitHub
    (re.compile(r'gh[pousr]_[A-Za-z0-9]{36,255}'), '[REDACTED_GITHUB_TOKEN]'),
    # OpenAI / Anthropic
    (re.compile(r'sk-[A-Za-z0-9_-]{20,}'), '[REDACTED_OPENAI_KEY]'),
    (re.compile(r'sk-ant-[A-Za-z0-9_-]{20,}'), '[REDACTED_ANTHROPIC_KEY]'),
    # Stripe
    (re.compile(r'sk_live_[A-Za-z0-9]{24,}'), '[REDACTED_STRIPE_LIVE]'),
    (re.compile(r'rk_live_[A-Za-z0-9]{24,}'), '[REDACTED_STRIPE_RESTRICTED]'),
    # Supabase (new key format)
    (re.compile(r'sb_secret_[A-Za-z0-9_-]{20,}'), '[REDACTED_SUPABASE_SECRET]'),
    # JWT (3-segment base64url)
    (re.compile(r'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'), '[REDACTED_JWT]'),
    # Generic high-entropy "secret=" / "token=" / "password=" lines
    (re.compile(r'(?i)(api[_-]?key|secret|token|password)\s*[:=]\s*[\'"]?[A-Za-z0-9_\-]{20,}[\'"]?'),
     r'\1=[REDACTED]'),
]

def scrub(s):
    if not isinstance(s, str): return s
    for pat, repl in PATTERNS:
        s = pat.sub(repl, s)
    return s

raw = sys.stdin.read()
try:
    d = json.loads(raw)
except Exception:
    # Not JSON — pass through unchanged
    sys.stdout.write(raw); sys.exit(0)

resp = d.get("tool_response") or {}
for k in ("stdout", "stderr", "output"):
    if k in resp:
        resp[k] = scrub(resp[k])
d["tool_response"] = resp
sys.stdout.write(json.dumps(d))
PY
