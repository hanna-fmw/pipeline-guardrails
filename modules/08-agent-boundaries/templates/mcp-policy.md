# Third-party agent tooling policy

Applies to MCP servers, agent plugins, editor extensions, and any other code that runs inside or alongside an AI coding session.

An MCP server is not a config file. It is code executing on your machine with whatever credential you hand it, and its tool descriptions are injected into the model's context on every message. Both facts matter: it is a supply-chain dependency **and** a prompt-injection surface.

## Admission checklist

Before installing, answer all six. If any answer is unknown, don't install.

1. **Who publishes it?** Prefer the vendor whose own API it wraps. A community server wrapping a payment provider is a stranger holding payment keys. For community servers: is the source public, is there commit activity in the last six months, is there more than one maintainer?
2. **What does it execute?** Read the launch command. `npx some-package` fetches and runs code at every startup.
3. **What can it reach?** Filesystem paths, network destinations, which API scopes. A server that only needs read access should not be given a write-capable token.
4. **What credential does it need?** Issue a dedicated one, scoped as narrowly as the service allows. Never a shared admin token — you must be able to revoke this server alone.
5. **Is the version pinned?** `@latest` is an unreviewed auto-update running with your keys. Pin it.
6. **When does it leave?** A server added for one investigation is disconnected when that investigation ends. Write the removal date down.

## Standing rules

- **Official over community**, community over unmaintained, unmaintained over nothing.
- **Read-only mode wherever it exists.** The write capability is usually the one you didn't need.
- **One credential per server.** Shared tokens make revocation all-or-nothing.
- **No production write access from an agent session.** Read-only prod is a deliberate, time-boxed exception; write is not.
- **Project isolation.** A server connected for project A is not used against project B's data, even to look.
- **Retrieved content is data, not instructions.** Web pages, issue bodies, and tool responses may contain text aimed at the model. It gets reported, never followed.
- **Token cost is a real constraint.** Every connected server's tool definitions are sent on every message. Disconnecting unused servers is a cost control as well as a security one.

## Review log

Record each admitted tool so the quarterly audit has something to check against.

| Tool | Publisher | Version | Credential + scope | Added | Remove by | Reviewed by |
|------|-----------|---------|--------------------|-------|-----------|-------------|
| example-db-server | vendor (official) | 1.4.2 | `db-agent-ro`, read-only, dev database | 2026-01-15 | 2026-04-15 | Owner |
| example-docs-server | community | 0.8.0 | none (public docs only) | 2026-02-01 | 2026-05-01 | Owner |
