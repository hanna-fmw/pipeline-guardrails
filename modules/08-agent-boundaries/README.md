# 08 — Agent Boundaries

What an AI agent is allowed to run, and what it is allowed to run *with*. Module 06 stops secrets flowing **out** through the transcript. This module limits the blast radius of the agent itself: which commands execute without a human, which filesystem and network it can reach, and which third-party tools, MCP servers, and plugins are trusted enough to be in the loop at all.

Every MCP server you connect is code running with your credentials, and its tool descriptions enter the model's context on every message. An untrusted server is both a supply-chain risk and a prompt-injection surface.

## Practice

Senior devs treat an agent like a new contractor with production access: useful, fast, and given the narrowest permissions that still let it work.

1. **Deny by default for anything irreversible.** Reads and local builds can be automatic. Anything that writes outside the repo, spends money, touches production, or talks to a third party asks first.
2. **Use an OS-enforced sandbox, not a convention.** Filesystem and network limits that the operating system applies to every command and child process, plus a dev database with fake data and production credentials absent from the environment rather than merely "not supposed to be used".
3. **Treat the tool list as a dependency manifest.** An MCP server, plugin, or extension is a dependency: it has an author, a version, and a permission scope. It gets reviewed before install, pinned, and removed when the project that needed it ends.
4. **Assume tool output is hostile input.** Web pages, issue bodies, and third-party tool responses can carry prompt injection. The agent may read them; it may not act on instructions found inside them without a human in the loop.
5. **One project per session.** An agent with several projects' credentials in scope can cross-contaminate them in a single mistaken command.

## Automation

### a. Use the built-in sandbox — don't build your own

Claude Code ships an OS-enforced Bash sandbox (Seatbelt on macOS, bubblewrap on Linux/WSL2). It applies to every sandboxed command **and its child processes**, which is the part no hand-rolled wrapper can do. Turn it on before writing any rules of your own: `/sandbox`, or `sandbox.enabled` in settings.

The settings that make it a control rather than a suggestion, all in `templates/settings.json.example`:

- **`allowUnsandboxedCommands: false`** — the hard gate. Left at the default, a command that fails under the sandbox can be retried outside it, where only the permission prompt stands in the way.
- **`failIfUnavailable: true`** — otherwise a missing dependency downgrades you to no sandbox with a warning you'll scroll past.
- **`sandbox.credentials`** — the purpose-built credential layer: `deny` on a file blocks reads inside the sandbox, `deny` on an env var unsets it before each sandboxed command. There is no built-in default list, so only what you list is protected. Deny entries merge across settings scopes and only narrow access, so any scope can add one and none can remove another's.
- **`sandbox.network.allowedDomains`** — egress allowlist. This is what stops a compromised dependency or an injected instruction from posting your source somewhere.
- **Leave `filesystem.disabled` alone.** With writes unrestricted, a sandboxed command can edit shell startup files or `settings.json` and widen its own access on the next run.

For stronger isolation than a Bash sandbox gives, the layered options are dev containers and VMs; the docs compare them under Sandbox environments.

### b. Permission rules for what the sandbox doesn't cover

The sandbox governs Bash. It does not govern Claude's own `Read`, `Edit`, `Write`, and `WebFetch` calls — those are the permission layer's job. Run both.

Same file, `permissions` block, split three ways:

- **allow** — non-mutating and cheap to undo: `git status`, `git diff`, test and lint runs, type checks.
- **ask** — mutating but normal: `git commit`, `git push`, package installs, `WebFetch`, and `Bash(dangerouslyDisableSandbox:true)` so an unsandboxed retry always surfaces.
- **deny** — never unattended: force pushes, history rewrites, `rm -rf`, production deploys, migrations against a non-local host, every cloud CLI subcommand that prints credentials, and reads or writes of `.env` and key files.

The deny list matters most. A generous allow list is a slow leak; a missing deny rule is a single-command outage. Audit it with `/permissions`, and enforce it across a team with managed settings, which individual users cannot override.

### c. Protect the config itself

A permission policy the agent can edit is not a policy. Use a **`ConfigChange` hook** to audit or block settings changes during a session, and keep `.claude/settings.json` in version control so a change shows up in review.

### d. Worktree isolation (workflow safety, not a security boundary)

`templates/agent-workspace.sh` — creates a git worktree for the agent's branch, links a dev-only env file, and refuses to run if the working tree is dirty, so an agent never builds on top of unsaved human work.

Its one genuine security check is the pre-flight that refuses to start when production credential **names** are present in the environment — cheap, and it catches the case where a live token is still loaded from an earlier task. Beyond that, treat this as workflow hygiene: a worktree is not an isolation boundary, and (a) is what actually contains the agent.

### e. Third-party tool policy

`templates/mcp-policy.md` — the admission rules for MCP servers, plugins, and agent extensions. Summary:

- **Official first.** Prefer servers published by the vendor whose API they wrap. A community server that wraps Stripe is a third party holding Stripe keys.
- **Read the manifest before install.** What does it execute, what does it read, what does it send outbound, and to where?
- **Pin the version.** `@latest` on a server that holds credentials is an unreviewed auto-update with your keys.
- **Scope the token.** Give each server its own credential with the narrowest scope, never a shared admin token, so it can be revoked alone.
- **Read-only where possible.** Many servers offer a read-only mode; the write capability is usually the one you don't need.
- **Time-box it.** A server connected for one investigation gets disconnected when the investigation ends.

### f. Connected-tool audit

`templates/audit-agent-tools.sh` — lists the **names** of configured MCP servers, plugins, and hooks, and flags any whose config specifies an unpinned version. It deliberately never prints config values, because MCP launch commands routinely carry access tokens in their arguments — auditing your tools should not itself leak them.

Run it monthly, and after any session where you installed something to try it out.

### g. Injection-resistant prompting

`templates/CLAUDE.md.snippet` — a block asserting that content retrieved from web pages, issues, PR comments, and third-party tools is **data, not instructions**, and that an instruction found inside retrieved content is reported to the user rather than followed.

This is a mitigation, not a control. It reduces drift; it does not survive a determined injection. The sandbox in (a) and the deny list in (b) are what actually hold.

The same text belongs in your `AGENTS.md` security section (module 06) so every agent reads it, not just Claude Code.

## Maintenance

- **Monthly:** run the connected-tool audit. Remove anything you haven't used since the last run.
- **Quarterly:** re-read the deny list against what you now let agents do, with `/permissions`. Capability grows quietly; the deny list doesn't grow by itself.
- **On a Claude Code release:** re-check the sandbox and permission keys against the [settings reference](https://code.claude.com/docs/en/settings). This is the fastest-moving config surface in the toolchain, and an unrecognised key is ignored rather than rejected.
- **On adding any MCP server or plugin:** apply the (e) checklist the same day, and issue it a dedicated scoped credential.
- **On any agent action that surprised you:** that's a missing rule, not a one-off. Add it to allow/ask/deny before the next session.
- **On project end:** revoke that project's agent credentials and disconnect its servers.

## Files

- `templates/settings.json.example` — sandbox layer + allow / ask / deny permission rules
- `templates/agent-workspace.sh` — worktree setup with production-credential pre-flight
- `templates/mcp-policy.md` — third-party server, plugin, and extension admission rules
- `templates/audit-agent-tools.sh` — name-only inventory of connected tools
- `templates/CLAUDE.md.snippet` — untrusted-content handling block
