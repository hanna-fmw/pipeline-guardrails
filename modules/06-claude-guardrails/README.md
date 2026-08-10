# 06 — Claude Code Guardrails

Stops secrets, PII, and cross-project leakage from entering Claude transcripts in the first place. Git hooks fire too late — once a secret lands in a transcript, it's already in Anthropic's logs, your terminal scrollback, and possibly an exported share link. This module is the upstream filter.

## Practice

Senior devs who use AI assistants treat the chat transcript as a **persistent, exported artifact**. They never paste a real `.env`, never let the assistant `cat` a key file, never let it `grep` for tokens across the filesystem, and never use real client/PII data in test fixtures during a session. The protections are:

1. **Pre-prompt rules** — a `CLAUDE.md` that the model re-reads via heartbeat reminders so it doesn't drift mid-session.
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
        "matcher": "Read|Bash",
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/block-secret-paths.sh" }
        ]
      }
    ]
  }
}
```

The hook script (`templates/block-secret-paths.sh`) blocks reads of `.env*`, `*.pem`, `*.key`, `id_rsa*`, `~/.aws/`, `~/.ssh/`, `~/.config/gh/`, browser cookie stores, and 1Password exports. Exits non-zero with a message → Claude sees a permission denial and must adjust.

### c. PostToolUse scrub on Bash output
Same `settings.json`, `PostToolUse` matcher on `Bash`. Pipes tool output through a regex set (AWS keys, GitHub PATs `gh[ps]_…`, OpenAI `sk-…`, Stripe `sk_live_…`, JWTs, Supabase `sb_secret_…`) and rewrites matches to `[REDACTED]` before the model sees them.

### d. Stop hook scan on final assistant message
Catches the rare case where the model itself generated a secret-shaped string. Warns the user in the terminal, does not modify the transcript.

### e. Project-level `CLAUDE.md` template
Every project gets a `CLAUDE.md` block (global rules already in `~/.claude/CLAUDE.md` — this module just provides the per-project starter) that lists: project name, allowed services, forbidden data, the agent surface.

## Maintenance

- **Monthly:** check `~/.claude/state/heartbeat/log` — confirm hook is firing. If silent, it's broken.
- **Quarterly:** update the secret regex set in the PostToolUse scrub. Source: `gitleaks` upstream rules.
- **On new tool/SDK adoption:** add its key format to the regex set the same day you start using it.
- **Audit trigger:** if a transcript export ever shows a leaked value, rotate the key immediately AND add its format to the regex set.

## Files

- `templates/block-secret-paths.sh` — PreToolUse blocker
- `templates/scrub-bash-output.sh` — PostToolUse scrubber
- `templates/scan-final-message.sh` — Stop-hook scanner
- `templates/CLAUDE.md.template` — per-project starter
- `templates/settings.json.snippet` — paste into `~/.claude/settings.json`
