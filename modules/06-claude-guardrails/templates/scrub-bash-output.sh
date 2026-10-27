#!/usr/bin/env bash
# PostToolUse hook for Claude Code.
# Redacts secrets from Bash output before Claude sees it, using gitleaks' rules
# (one rule set for CI, git hooks and these hooks; version pinned in .github/workflows/checks.yml).
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
# Fail loud, not open: a silent no-op scrubber is worse than none, because
# you stop watching for the thing it was supposed to catch.
for t in python3 gitleaks; do
  command -v "$t" >/dev/null || { echo "scrub-bash-output.sh: $t not found — output NOT scrubbed" >&2; exit 1; }
done

# The payload goes in as argv[1]. Passing it on stdin would collide with the
# heredoc that carries the program itself.
"$PY_BIN" - "$INPUT" <<'PY'
import sys, json, subprocess

def scrub(s):
    # gitleaks reports each finding's Secret; replace every occurrence with its rule id.
    r = subprocess.run(["gitleaks", "stdin", "--no-banner", "--report-format", "json",
                        "--report-path", "-", "--exit-code", "0"],
                       input=s, capture_output=True, text=True)
    try:
        findings = json.loads(r.stdout or "[]")
    except ValueError:
        sys.stderr.write("scrub-bash-output.sh: gitleaks gave no report — output NOT scrubbed\n")
        sys.exit(1)
    # Longest first, so a secret that contains another is replaced whole.
    for f in sorted(findings, key=lambda f: -len(f.get("Secret", ""))):
        if f.get("Secret"):
            s = s.replace(f["Secret"], "[REDACTED_%s]" % f.get("RuleID", "secret"))
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
