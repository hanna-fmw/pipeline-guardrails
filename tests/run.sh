#!/bin/bash
# The kit's own tests, run by selftest.yml before any release (scripts/release.sh refuses without them).
# Needs gitleaks and jq. Uses a random fake key, never a real one; prints only pass/fail.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
fails=0
check() { local name=$1; shift; if "$@" >/dev/null 2>&1; then echo "ok   $name"; else echo "FAIL $name"; fails=$((fails + 1)); fi; }
fake="gh""p_$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 36)"
h=modules/06-claude-guardrails/templates
scrub() { jq -n --arg o "$1" '{tool_name: "Bash", tool_response: {stdout: $o}}' | bash $h/scrub-bash-output.sh; }
scan() { jq -n --arg m "$1" '{last_assistant_message: $m}' | bash $h/scan-final-message.sh; }

# slack-post: no token means a quiet no-op, never a failed job
check "slack-post without a token exits 0" env -u SLACK_TOKEN .github/actions/slack/slack-post system hi
# keys.sh: no arguments prints usage and fails
check "keys.sh without arguments fails" bash -c '! scripts/keys.sh'
check "the repo pipeline file holds no logic (only the router call)" bash -c '[ $(grep -c "uses:" templates/.github/workflows/pipeline.yml) -eq 1 ] && ! grep -q "if:" templates/.github/workflows/pipeline.yml'
check "no second repo workflow template" test ! -e templates/.github/workflows/commands.yml
check "local-checks.sh reads the script list from checks.yml" bash -c 'grep -q "for s in [a-z ]*; do # the one list" .github/workflows/checks.yml'
check "sync.sh runs on the Mac's bash 3.2 (no arrays)" bash -c '! grep -qE "\\[@\\]|\\[\\*\\]|=\\(\\)" scripts/sync.sh'
check "sync.sh --put refuses a kit-managed path" bash -c 'echo x > /tmp/put.$$; ! scripts/sync.sh --put any/repo .claude/settings.json /tmp/put.$$ >/dev/null; r=$?; rm -f /tmp/put.$$; exit $r'
check "approve.sh without arguments fails" bash -c '! scripts/approve.sh 2>/dev/null'
# secret hooks: a fake key is caught, clean text passes untouched
check "scrub hook redacts a key" bash -c '[[ $1 == *"[REDACTED_"* && $1 != *"$2"* ]]' _ "$(scrub "token $fake here")" "$fake"
check "scrub hook leaves clean output alone" test -z "$(scrub "nothing here")"
check "final-message hook warns without echoing the key" bash -c '[[ $1 == *"gitleaks rule"* && $1 != *"$2"* ]]' _ "$(scan "see $fake")" "$fake"
check "final-message hook is quiet on clean text" test -z "$(scan "all good")"
# every kit reference is pinned to a release, never main
check "no reference to @main" bash -c '! grep -rqE "hanna-fmw/pipeline-guardrails/[^ ]+@main" .github templates README.md'

if [ $fails -eq 0 ]; then echo "all tests passed"; else echo "$fails test(s) FAILED"; exit 1; fi
