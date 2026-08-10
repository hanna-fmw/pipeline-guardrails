# 06 — Claude Code Guardrails

Stops secrets, PII, and cross-project leakage from entering Claude transcripts in the first place. Git hooks fire too late — once a secret lands in a transcript, it's already in Anthropic's logs, your terminal scrollback, and possibly an exported share link. This module is the upstream filter.

## Practice

Senior devs who use AI assistants treat the chat transcript as a **persistent, exported artifact**. They never paste a real `.env`, never let the assistant `cat` a key file, never let it `grep` for tokens across the filesystem, and never use real client/PII data in test fixtures during a session. The protections are:

1. **Pre-prompt rules** — an `AGENTS.md` security section, imported into `CLAUDE.md`, re-injected via heartbeat reminders so it doesn't drift mid-session.
2. **Tool-call hooks** — deterministic, Claude-independent blocks at the `PreToolUse` layer that refuse to read sensitive files even if the model asks for them.
3. **Output scrub** — a `Stop` hook that scans the final assistant message for accidental secret-shaped strings and warns the user.

The model can be persuaded, tricked, or simply drift. The hooks cannot.

## Automation

### a. Heartbeat (drift prevention)
A `UserPromptSubmit` hook that re-injects the top rules every N prompts (default 8). Long sessions drift; a rule stated once at the start is not a rule by message sixty.

### b. PreToolUse block on sensitive paths
Add to `~/.claude/settings.json` (or per-project `.claude/settings.json`):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read|Edit|Write|Grep|Glob|Bash",
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/block-secret-paths.sh" }
        ]
      }
    ]
  }
}
```

The matcher must include the edit tools: a hook wired to `Read|Bash` alone leaves `Edit .env` completely unguarded.

The hook script (`templates/block-secret-paths.sh`) blocks access to `.env*`, `*.pem`, `*.key`, `id_rsa*`, `~/.aws/`, `~/.ssh/`, `~/.config/gh/`, browser cookie stores, and 1Password exports. Exits **2** with a message → the call is blocked and Claude must adjust. Any other non-zero exit is a non-blocking error and the call proceeds, so the script fails closed (exit 2) if it cannot inspect the call at all.

### c. PostToolUse scrub on Bash output
Same `settings.json`, `PostToolUse` matcher on `Bash`. Matches a regex set (AWS, GitHub, OpenAI, Anthropic, Stripe, Supabase, Slack, JWTs, private keys, connection strings) and returns the redacted text as `hookSpecificOutput.updatedToolOutput`, which is the only channel Claude Code reads — rewriting the stdin envelope and echoing it back has no effect.

Order the patterns most-specific-first. A generic `sk-` rule placed before `sk-ant-` swallows Anthropic keys and mislabels them.

### d. Stop hook scan on final assistant message
Catches the rare case where the model itself generated a secret-shaped string. `templates/scan-final-message.sh` reads `.last_assistant_message` from the hook's stdin JSON and returns a `systemMessage` warning to the user.

It deliberately does not block (exit 2). By the time a Stop hook runs, the string is already in the transcript — blocking buys nothing and risks a stop loop. It reports which *pattern* matched, never the matched value, so the warning can't become the leak. Anything it fires on is compromised: rotate it.

### e. Required security section in `AGENTS.md`
Every project gets one, and this playbook treats it as **required** — the AGENTS.md spec itself has no required fields and ships no official security example, so that requirement is ours.

`templates/AGENTS.md-security-section.md` covers data boundaries, secrets, untrusted content, confirm-before, destructive operations, third-party code, and scope.

Use `AGENTS.md` rather than a tool-specific file: it's an open format that several coding agents read, it's committed to the repository so the whole team and every agent share one source, and nested files are supported (agents read the nearest one, so a package can tighten the rules for itself). Claude Code doesn't read `AGENTS.md` — add a `CLAUDE.md` containing `@AGENTS.md` to import it, with any Claude-specific rules below.

**This section is context, not enforcement.** The docs are explicit that instruction files shape behaviour without guaranteeing it. Every rule here that must actually hold is also written as a permission rule, a sandbox setting, or a hook — see module 08. Writing it once, in prose, is the most common way a team ends up believing it has a control it doesn't have.

## Maintenance

- **Monthly:** check `~/.claude/state/heartbeat/log` — confirm hook is firing. If silent, it's broken.
- **Quarterly:** update the secret regex set in the PostToolUse scrub. Source: `gitleaks` upstream rules.
- **On new tool/SDK adoption:** add its key format to the regex set the same day you start using it.
- **On a new model release:** re-read the `AGENTS.md` security section. Rules written to counter an older model's habits are often unnecessary on a newer one, and an instruction fighting a behaviour that no longer exists costs context for nothing.
- **On a Claude Code release:** verify hook event names and JSON field names against the [hooks reference](https://code.claude.com/docs/en/hooks). A renamed field doesn't error — the hook just stops having any effect.
- **Audit trigger:** if a transcript export ever shows a leaked value, rotate the key immediately AND add its format to the regex set.

## Files

- `templates/block-secret-paths.sh` — PreToolUse blocker
- `templates/scrub-bash-output.sh` — PostToolUse scrubber
- `templates/scan-final-message.sh` — Stop-hook scanner
- `templates/AGENTS.md-security-section.md` — required security section for the repo's `AGENTS.md`
- `templates/settings.json.snippet` — paste into `~/.claude/settings.json`
