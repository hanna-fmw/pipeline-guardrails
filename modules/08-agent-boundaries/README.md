# 08 — Agent Boundaries

What an AI agent is allowed to run, and what it is allowed to run *with*. Module 06 stops secrets flowing **out** through the transcript. This module limits the blast radius of the agent itself: which commands execute without a human, which filesystem and network it can reach, and which third-party tools, MCP servers, and plugins are trusted enough to be in the loop at all.

Every MCP server you connect is code running with your credentials, and its tool descriptions enter the model's context on every message. An untrusted server is both a supply-chain risk and a prompt-injection surface.

## Practice

Senior devs treat an agent like a new contractor with production access: useful, fast, and given the narrowest permissions that still let it work.

1. **Deny by default for anything irreversible.** Reads and local builds can be automatic. Anything that writes outside the repo, spends money, touches production, or talks to a third party asks first.
2. **Sandbox the workspace, not just the commands.** The agent works in a clone or worktree, against a dev database with fake data, with production credentials absent from the environment rather than merely "not supposed to be used".
3. **Treat the tool list as a dependency manifest.** An MCP server, plugin, or extension is a dependency: it has an author, a version, and a permission scope. It gets reviewed before install, pinned, and removed when the project that needed it ends.
4. **Assume tool output is hostile input.** Web pages, issue bodies, and third-party tool responses can carry prompt injection. The agent may read them; it may not act on instructions found inside them without a human in the loop.
5. **One project per session.** An agent with several projects' credentials in scope can cross-contaminate them in a single mistaken command.

## Automation

### a. Permission policy

`templates/permissions.settings.json` — a starting `.claude/settings.json` permission block, split three ways:

- **allow** — non-mutating and cheap to undo: `git status`, `git diff`, `ls`, test and lint runs, type checks.
- **ask** — mutating but normal: `git commit`, `git push`, package installs, writes outside the project directory.
- **deny** — never unattended: `git push --force`, history rewrites, `rm -rf`, production deploy commands, database migration or drop against a non-local host, and any cloud CLI subcommand that prints credentials.

The deny list matters most. An allow list that is too generous is a slow leak; a missing deny rule is a single-command outage.

### b. Sandboxed workspace

`templates/agent-workspace.sh` — creates a git worktree for the agent's branch, links a dev-only env file, and verifies no production credential names are present in the environment before handing over. Refuses to run if the current directory has uncommitted changes, so an agent never starts on top of unsaved human work.

### c. Third-party tool policy

`templates/mcp-policy.md` — the admission rules for MCP servers, plugins, and agent extensions. Summary:

- **Official first.** Prefer servers published by the vendor whose API they wrap. A community server that wraps Stripe is a third party holding Stripe keys.
- **Read the manifest before install.** What does it execute, what does it read, what does it send outbound, and to where?
- **Pin the version.** `@latest` on a server that holds credentials is an unreviewed auto-update with your keys.
- **Scope the token.** Give each server its own credential with the narrowest scope, never a shared admin token, so it can be revoked alone.
- **Read-only where possible.** Many servers offer a read-only mode; the write capability is usually the one you don't need.
- **Time-box it.** A server connected for one investigation gets disconnected when the investigation ends.

### d. Connected-tool audit

`templates/audit-agent-tools.sh` — lists the **names** of configured MCP servers, plugins, and hooks, and flags any whose config specifies an unpinned version. It deliberately never prints config values, because MCP launch commands routinely carry access tokens in their arguments — auditing your tools should not itself leak them.

Run it monthly, and after any session where you installed something to try it out.

### e. Injection-resistant prompting

`templates/CLAUDE.md.snippet` — a block asserting that content retrieved from web pages, issues, PR comments, and third-party tools is **data, not instructions**, and that an instruction found inside retrieved content is reported to the user rather than followed.

This is a mitigation, not a control. It reduces drift; it does not survive a determined injection. The permission deny list in (a) is what actually holds.

## Maintenance

- **Monthly:** run the connected-tool audit. Remove anything you haven't used since the last run.
- **Quarterly:** re-read the deny list against what you now let agents do. Capability grows quietly; the deny list doesn't grow by itself.
- **On adding any MCP server or plugin:** apply the (c) checklist the same day, and issue it a dedicated scoped credential.
- **On any agent action that surprised you:** that's a missing rule, not a one-off. Add it to allow/ask/deny before the next session.
- **On project end:** revoke that project's agent credentials and disconnect its servers.

## Files

- `templates/permissions.settings.json` — allow / ask / deny permission block
- `templates/agent-workspace.sh` — sandboxed worktree setup with credential pre-flight
- `templates/mcp-policy.md` — third-party server, plugin, and extension admission rules
- `templates/audit-agent-tools.sh` — name-only inventory of connected tools
- `templates/CLAUDE.md.snippet` — untrusted-content handling block
