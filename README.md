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

Guardrails rot quietly. A hook that stopped firing, a regex that doesn't know the format of the API key you adopted last month, or a prompt tuned for a model that no longer needs the workaround all *look* fine — the file is still there, the config still parses, nothing errors. Silent failure is the normal failure mode here, so the review has to be scheduled rather than triggered.

| Trigger | Re-check |
|---------|----------|
| **New model release** | Agent prompts, `CLAUDE.md` files, skills, and review-agent prompts. Phrasing that compensated for an older model's habits is often redundant on a newer one, and occasionally harmful — an instruction fighting a behaviour the model no longer has is wasted context at best. Verbose rules can usually be cut. Re-test one real task per prompt before trusting it. |
| **New agent tooling release** | Hook event names, JSON input and output fields, settings schema, permission-rule syntax. These are the parts that break silently: a renamed field means your hook returns something the harness ignores. Re-read the hooks and settings reference, then verify each hook actually fires. |
| **Adopting any new service** | Add its credential format to the secret regex sets (modules 04 and 06) the same day, not at the next quarterly review. |
| **Quarterly** | Deny lists and permission rules (capability grows quietly), CODEOWNERS, connected MCP servers and plugins, and contradictions between `CLAUDE.md` files, `.claude/rules/`, and skills. |
| **After any incident or near miss** | The rule that would have caught it. A guardrail added after the fact is the only kind that's been tested against something real. |

The strongest habit: verify hooks are still *firing*, not just still present. A hook that silently stopped running looks identical to one that never had anything to catch.

## Status

Reference-first and in progress. All eight modules are written and their templates are usable as-is by copying them.

The configuration and hook templates have been reviewed against the current official documentation, and the shell templates were executed to confirm they do what their README claims — a scrubber that silently redacts nothing, or a hook that stops firing after a field rename, is the characteristic failure here and does not announce itself. The workflow and deploy templates are unverified end-to-end: nothing in this repo deploys anywhere, so those can only be proven in a project that adopts them.

Planned next: a `cli/` package providing `pipeline-guardrails init`, which drops the relevant configs into a repo and verifies the prerequisites (git-guard installed, 1Password CLI present, gitleaks available), and `update`, which diffs an existing repo against the latest templates. Not implemented yet — copy the templates manually until it lands.

Examples use a fictional `acme-` org and generic placeholders; substitute your own.

## License

MIT — see [LICENSE](LICENSE).
