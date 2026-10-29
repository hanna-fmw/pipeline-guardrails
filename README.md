# pipeline-guardrails

A pull-request pipeline for small teams that let AI agents write code, modelled on [how the Claude Code team does code review](https://claude.dev/blog/solving-code-review-at-anthropic/). Machines do most of the reading; a person decides what to build, reads the evidence, and approves risky changes.

## The pipeline

| Layer | Where | What happens |
|---|---|---|
| Before the PR | your machine | Claude formats and lints each file it saves (`templates/.claude/settings.json`), runs the tests, and a fresh agent reviews the diff |
| Required checks | `checks.yml` | lint, typecheck, test, build (whichever scripts exist), workflow and shell-script lint, vulnerable packages, leaked secrets in the PR's commits |
| Claude review | `claude-review.yml` (kind: review) | a plain-English summary of what the PR does and what to try before merging, parallel bug hunters, a verifier per finding, inline comments for confirmed bugs, nits and pre-existing issues in a summary, risk label |
| Security review | `claude-review.yml` (kind: security) | same shape, security problems only |
| Convergence | both reviews | round 1 reads the whole PR, later rounds only new commits, never repeats a finding, marks its own fixed threads (the gate resolves them), stops after 3 rounds |
| Gate | `gate.yml` | one check: green checks, every thread resolved, up to date with main, owner-approved label for medium and high risk (removed on every push), CI files and CODEOWNERS paths always high; green low-risk PRs (docs/tests only) merge themselves |
| Fix | `claude-fix.yml` | `@claude <what to do>` on a PR: Claude pushes the change and the pipeline runs again; in an issue: Claude does it and opens the PR |
| Rollback | `revert.yml` | `/revert` on a merged PR opens the undo PR |
| Dependencies | `templates/.github/dependabot.yml` | weekly grouped npm updates, monthly action updates |

Depth per repo: `quick`, `standard` (2 hunters, 1 verifier each) or `deep` (4 hunters, 3 voting verifiers), set by the repo variable `PIPELINE_DEPTH` (default `standard`).

## Approving a PR

The one written-down flow; skills, rules and other docs point here instead of repeating it.

1. The pipeline runs; Slack shows the PR only once it needs the owner (green and waiting, or only approval missing).
2. The owner says yes. The session that made the PR then runs `scripts/approve.sh <owner/repo> <pr> [its worktree]`, the one way to act on that yes. The yes covers the latest commit only; any push removes the label.
3. It adds `owner-approved`, which re-runs the gate; the gate merges a green PR. Not merged within 15 minutes: it says so, and the gate comment on the PR says why. A PR that changes workflow files cannot be merged by the gate's token (and its own workflows could fake a green check), so the owner presses **Squash and merge** there.
4. Deploy: the host (Vercel, Railway) deploys `main` on its own; nothing to run.
5. Cleanup: the branch is deleted on merge, `Closes #N` issues close, the Slack message is deleted, and `approve.sh` removes the worktree it was given.
6. Something wrong after merge: `/revert` on the PR.

## Roadmap

What the CI/CD baseline still lacks lives as [issues labelled `roadmap`](https://github.com/hanna-fmw/pipeline-guardrails/issues?q=label%3Aroadmap): tests on a throwaway database, safe releases (staging, smoke checks, rollback), error alerts, feature flags, and a backups baseline. A project's own issues track only its local part.

## Install in a repo

```bash
./install.sh <repo-folder>
```

It writes the one pipeline file (identical in every repo, it only calls `router.yml` here, so nothing in a repo ever needs updating) plus a PR template, `REVIEW.md`, Dependabot config and the Claude format hook, then sets the repo to squash-only merges. Existing `REVIEW.md`, PR template and Claude settings are kept. One-time setup:

1. Install the [Claude GitHub App](https://github.com/apps/claude) on the repo.
2. `claude setup-token`, then save the token once in Infisical (project `personal`, env `dev`, folder `/github`, name `CLAUDE_CODE_OAUTH_TOKEN`). The installer copies it into the repo's secret without showing it. Reviews then run on your Claude subscription, not per-token billing.
3. Add the project's checks as package.json scripts: `lint`, `typecheck`, `test`, `build`.
4. Fill in `REVIEW.md`: what failure looks like here, what is always high risk, what to skip.

## Shared rules

`rules/shared.md` is the one home of the rules every agent follows in these repos, also without the owner's machine. Every Claude step (review, security, `@claude`, `ai:auto`) loads it first through `.github/actions/rules`, as the runner's `~/.claude/CLAUDE.md`; cloud setup scripts fetch the same file raw. No repo holds a copy.

## What a repo holds

Kit-managed (`scripts/sync.sh --list`): written by `install.sh`, never edited in the repo, and put back by `sync.sh`, which the daily check runs, through a PR it merges itself. The pipeline file only calls `router.yml`, so a kit change never needs a repo change. The repo's own (seeded once, then the repo's): `REVIEW.md`, `.github/dependabot.yml`, the opt-in `backup.yml`, and the repo variable `PIPELINE_DEPTH`.

## Versions

Repos pin a release, never `main`: `@v1` moves to each new v1.x.y, so fixes reach every repo while a breaking change (v2) waits until each repo moves on purpose. Every commit on `main` that passes the self-test (`selftest.yml`: the checks workflow on this repo plus `tests/run.sh`) is released by itself as the next patch version, with notes; `scripts/release.sh vX.Y.Z` is only for a minor or major bump. Which repo pins what, and who is behind, shows in bb (Components), through the system register's daily check.

## Backups (projects with a database)

Opt-in, per repo: copy `templates/.github/workflows/backup.yml` and `templates/RESTORE.md` into the repo and fill in the placeholders. It backs a Supabase project up twice a day to a Google shared drive (no stored key) or Cloudflare R2 (database dump plus every Storage file), posts 🔴 to Slack when a run fails, and `scripts/pull-backups-to-drive.sh` makes the monthly third copy. Keys come from Infisical (`scripts/keys.sh`). Setup, restore and the quarterly restore test are in `RESTORE.md`.

## On the GitHub free plan

Private repos on the free plan cannot lock the merge button (rulesets need GitHub Pro or a public repo). Everything above still runs; the gate is a red or green check, and you merge only on green. A PR runs the workflow files on its own branch, so a PR that edits `.github/` could fake a green gate; that is why those paths are always high risk and need your own review. With Pro, make `gate` a required status check, require conversation resolution, and block direct pushes to `main`.

## Reference modules

| # | Module | Covers |
|---|---|---|
| 06 | [claude-guardrails](modules/06-claude-guardrails/) | Claude Code hooks that block secrets and PII before they enter transcripts |

## Keeping it working

Guardrails fail silently: a renamed hook field or a model that no longer needs a workaround looks fine until something gets through.

- **New model or Claude Code release:** re-run one real PR through the pipeline and check that the reviews still post.
- **A bug got through:** ask which layer should have caught it, then add a line to that repo's `REVIEW.md`, a lint rule, or a check here.
- **A finding keeps coming back:** fix it at the source (`REVIEW.md`, `CLAUDE.md`, a lint rule), not per PR.

## License

MIT, see [LICENSE](LICENSE).
