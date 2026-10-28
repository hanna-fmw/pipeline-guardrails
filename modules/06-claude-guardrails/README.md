# 06 — Claude Code Guardrails

Stops secrets, PII, and cross-project leakage from entering Claude transcripts in the first place. Git hooks fire too late — once a secret lands in a transcript, it's already in Anthropic's logs, your terminal scrollback, and possibly an exported share link. This module is the upstream filter.

## Practice

Senior devs who use AI assistants treat the chat transcript as a **persistent, exported artifact**. They never paste a real `.env`, never let the assistant `cat` a key file, never let it `grep` for tokens across the filesystem, and never use real client/PII data in test fixtures during a session. The protections are:

1. **Pre-prompt rules** — re-injected via heartbeat reminders so they don't drift mid-session.
2. **Output scrub** — a `Stop` hook that scans the final assistant message for accidental secret-shaped strings and warns the user.

The model can be persuaded, tricked, or simply drift. The hooks cannot.

## Automation

### a. Heartbeat (drift prevention)
A `UserPromptSubmit` hook that re-injects the top rules every N prompts (default 8). Long sessions drift; a rule stated once at the start is not a rule by message sixty.

### b. PostToolUse scrub on Bash output
In `~/.claude/settings.json`, a `PostToolUse` matcher on `Bash`. Matches a regex set (AWS, GitHub, OpenAI, Anthropic, Stripe, Supabase, Slack, JWTs, private keys, connection strings) and returns the redacted text as `hookSpecificOutput.updatedToolOutput`, which is the only channel Claude Code reads — rewriting the stdin envelope and echoing it back has no effect.

Order the patterns most-specific-first. A generic `sk-` rule placed before `sk-ant-` swallows Anthropic keys and mislabels them.

### c. Stop hook scan on final assistant message
Catches the rare case where the model itself generated a secret-shaped string. `templates/scan-final-message.sh` reads `.last_assistant_message` from the hook's stdin JSON and returns a `systemMessage` warning to the user.

It deliberately does not block (exit 2). By the time a Stop hook runs, the string is already in the transcript — blocking buys nothing and risks a stop loop. It reports which *pattern* matched, never the matched value, so the warning can't become the leak. Anything it fires on is compromised: rotate it.

## Maintenance

- **Monthly:** check `~/.claude/state/heartbeat/log` — confirm hook is firing. If silent, it's broken.
- **Quarterly:** update the secret regex set in the PostToolUse scrub. Source: `gitleaks` upstream rules.
- **On new tool/SDK adoption:** add its key format to the regex set the same day you start using it.
- **On a Claude Code release:** verify hook event names and JSON field names against the [hooks reference](https://code.claude.com/docs/en/hooks). A renamed field doesn't error — the hook just stops having any effect.
- **Audit trigger:** if a transcript export ever shows a leaked value, rotate the key immediately AND add its format to the regex set.

## Files

- `templates/scrub-bash-output.sh` — PostToolUse scrubber
- `templates/scan-final-message.sh` — Stop-hook scanner
