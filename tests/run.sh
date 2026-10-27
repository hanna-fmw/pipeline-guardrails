#!/bin/bash
# The kit's own tests, run by selftest.yml before any release (scripts/release.sh refuses without them).
# Needs gitleaks and jq. Uses a random fake key, never a real one; prints only pass/fail.
set -uo pipefail
cd "$(dirname "$0")/.."
fails=0
ok() { if [ "$2" = 0 ]; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }

# slack-post: no token means a quiet no-op, never a failed job
env -u SLACK_TOKEN .github/actions/slack/slack-post system hi >/dev/null 2>&1; ok "slack-post without a token exits 0" $?

# keys.sh: unknown use prints usage and fails
scripts/keys.sh >/dev/null 2>&1; [ $? -ne 0 ]; ok "keys.sh without arguments fails" $?

# secret hooks: a fake key is caught, clean text passes untouched
fake="gh""p_$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 36)"
h=modules/06-claude-guardrails/templates
out=$(jq -n --arg o "token $fake here" '{tool_name: "Bash", tool_response: {stdout: $o}}' | bash $h/scrub-bash-output.sh)
jq -e --arg f "$fake" '.hookSpecificOutput.updatedToolOutput | (contains($f) | not) and contains("[REDACTED_")' <<<"$out" >/dev/null; ok "scrub hook redacts a key" $?
out=$(jq -n '{tool_name: "Bash", tool_response: {stdout: "nothing here"}}' | bash $h/scrub-bash-output.sh); [ -z "$out" ]; ok "scrub hook leaves clean output alone" $?
out=$(jq -n --arg m "see $fake" '{last_assistant_message: $m}' | bash $h/scan-final-message.sh)
grep -q "gitleaks rule" <<<"$out" && ! grep -qF "$fake" <<<"$out"; ok "final-message hook warns without echoing the key" $?
out=$(jq -n '{last_assistant_message: "all good"}' | bash $h/scan-final-message.sh); [ -z "$out" ]; ok "final-message hook is quiet on clean text" $?

# every kit reference is pinned to a release, never main
! grep -rnE "hanna-fmw/pipeline-guardrails/[^ ]+@main" .github templates README.md; ok "no reference to @main" $?

[ $fails -eq 0 ] && echo "all tests passed" || { echo "$fails test(s) FAILED"; exit 1; }
