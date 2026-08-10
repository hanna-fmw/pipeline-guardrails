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

## Usage

This repo is **both reference and template**. Two ways to use it:

1. **Read the modules** — each is a short course on the senior-dev practice + a copy-paste config.
2. **Run the CLI** (`cli/`, WIP) — `npx pipeline-guardrails init` drops the relevant configs into a new or existing repo and verifies the prerequisites (git-guard installed, 1Password CLI present, etc.).

## Staying up to date

Each module ends with a **Maintenance** section: what to re-check quarterly, what to rotate, which upstream tool to watch for breaking changes. The CLI's `update` command (planned) will diff your repo against the latest templates.

## Status

Scaffolded. Modules are being filled in incrementally — start with `01-secrets-and-env` and `06-claude-guardrails`, those are the highest-leverage.
