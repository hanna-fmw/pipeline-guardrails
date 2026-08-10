# pipeline-guardrails

A modular safety + best-practice kit for the full code delivery pipeline — from "I open the editor" to "the client sees the deploy." Built for small teams that lean on AI assistants (Claude Code, Cursor, Copilot) and need the safety net that senior engineers usually carry in their heads.

Each module is self-contained: a short README explaining the **practice** (what a senior dev does and why), the **automation** (the config/script/hook that enforces it), and the **maintenance** (how it stays current — rotation, updates, audits).

## Modules

| # | Module | Covers |
|---|---|---|
| 01 | [secrets-and-env](modules/01-secrets-and-env/) | `.env` strategy, 1Password integration, key rotation, where to find keys per project |
| 02 | [git-hygiene](modules/02-git-hygiene/) | Branch naming, commit conventions, merge strategy, protected branches |
| 03 | [local-hooks](modules/03-local-hooks/) | Pre-commit secret/PII scan (`git-guard`), global `.gitignore`, lint-staged |
| 04 | [ci-pipeline](modules/04-ci-pipeline/) | GitHub Actions: lint, test, secret scan, type check, build verification |
| 05 | [pr-review](modules/05-pr-review/) | CodeRabbit setup, PR template, review checklist, required checks |
| 06 | [claude-guardrails](modules/06-claude-guardrails/) | Claude Code hooks that block secrets/PII before they enter transcripts |
| 07 | [deploy-safety](modules/07-deploy-safety/) | Vercel / Coolify pre-deploy gates, preview env protection, rollback drills |
| 08 | [agent-boundaries](modules/08-agent-boundaries/) | Agent permissions, sandboxed workspaces, MCP/plugin admission policy, connected-tool audits |

## Usage

Read the module you need and copy its templates into your repo. Each module README explains what to change and in what order — nothing here is installed for you.

Start with `01-secrets-and-env` and `06-claude-guardrails`; those are the highest-leverage.

## Staying up to date

Each module ends with a **Maintenance** section: what to re-check quarterly, what to rotate, which upstream tool to watch for breaking changes.

## Status

Reference-first and in progress. The modules are written and the templates are usable as-is by copying them.

Planned next: a `cli/` package providing `pipeline-guardrails init`, which drops the relevant configs into a repo and verifies the prerequisites (git-guard installed, 1Password CLI present, gitleaks available), and `update`, which diffs an existing repo against the latest templates. Not implemented yet — copy the templates manually until it lands.

Examples use a fictional `acme-` org and generic placeholders; substitute your own.

## License

MIT — see [LICENSE](LICENSE).
