# 04 — CI Pipeline (GitHub Actions)

The public, mandatory safety net. Local hooks can be skipped (`--no-verify`); CI cannot. Every PR runs the same checks, in the same order, against the same Node/pnpm version.

## Practice

Senior devs structure CI as **fast-fail concentric rings**:

1. **Ring 1 (seconds):** lint + format check + secret scan. Cheap, catches 80% of bad PRs instantly.
2. **Ring 2 (1–2 min):** type check + unit tests. Catches obvious breaks.
3. **Ring 3 (3–5 min):** build verification + integration tests + E2E smoke. Catches the rest.
4. **Ring 4 (only on `main`):** deploy preview / production.

Each ring depends on the previous — if lint fails, type-check doesn't run. Saves CI minutes and gives clear, fast feedback.

Rules:

- **Pin tool versions.** `pnpm` via `packageManager` in `package.json`, Node via `.nvmrc`, OS via `runs-on: ubuntu-24.04` (not `latest`).
- **Cache aggressively** (`actions/setup-node` with `cache: pnpm`).
- **No `continue-on-error: true`.** A check either matters or doesn't.
- **Required status checks** on `main` in repo settings: lint, type-check, test, secret-scan all must pass before merge.
- **Single workflow file per concern.** `ci.yml` for PR checks, `deploy.yml` for deploys, `weekly-audit.yml` for scheduled scans.

## Automation

### a. `ci.yml` — runs on every PR + push to `main`

See `templates/ci.yml`. Jobs:

- `lint` — eslint + prettier check
- `secret-scan` — gitleaks against the full repo + against the PR diff
- `typecheck` — tsc --noEmit (depends on lint)
- `test` — vitest --run (depends on typecheck)
- `build` — next build / pnpm build (depends on test)

### b. Secret scan with `gitleaks`

Two passes: full history (catches a previously committed secret), and PR diff (catches one being added). The diff pass uses the `--log-opts` flag to compare HEAD to the merge base.

### c. Type-check + test job
Runs against the matrix of supported Node versions if applicable. Uploads coverage to the PR as a comment (via `codecov` or similar — optional).

### d. Build verification
Catches "works locally, breaks in build" issues (env var missing in `.env.example`, unused imports tree-shaken away in prod, etc.).

### e. Required checks + branch protection
Configure in repo Settings → Branches:
- Require status checks: `lint`, `secret-scan`, `typecheck`, `test`, `build`
- Require branches up to date before merging
- Require linear history
- Require signed commits (optional but recommended)
- No force pushes, no deletions on `main`

### f. Weekly scheduled audit
`weekly-audit.yml` runs:
- `pnpm audit` (and `npm audit` for compat)
- `gitleaks` over the full history
- Dependency freshness check (e.g. `pnpm outdated` summarised in a Slack/email notification)

### g. Dependabot (automated dependency PRs)
GitHub-native, free, configured via `.github/dependabot.yml` (see `templates/dependabot.yml`). Complements `weekly-audit.yml` — the audit *reports* what's drifting; Dependabot *opens the PR* to fix it.

Key choices baked into the template:
- **Weekly cadence** (not daily — daily becomes noise).
- **Grouped minor/patch updates** — one PR per dev/prod group, not 12 separate PRs.
- **Majors ignored** for framework deps (Next.js, React) — those get bumped manually with a migration PR.
- **GitHub Actions ecosystem enabled** — action versions are security-sensitive (compromised action = supply chain attack).
- Dependabot PRs hit the same CI as human PRs, so a green check on a Dependabot PR means it's safe to merge. CodeRabbit will still review.

## Maintenance

- **On a new project:** copy `templates/ci.yml` and `templates/weekly-audit.yml` into `.github/workflows/`. Configure branch protection in repo settings (one-time).
- **Quarterly:** check pinned versions of `actions/*`, `gitleaks`, Node minor. Bump.
- **On a failed weekly audit:** triage same week. Don't accumulate.
- **On a new secret-leak class** (e.g. new SaaS provider with a new key format): update gitleaks config (`templates/.gitleaks.toml`) + the regex set in module 06.

## Files

- `templates/ci.yml` — main PR workflow
- `templates/weekly-audit.yml` — scheduled audit workflow
- `templates/.gitleaks.toml` — extended gitleaks config with project-specific patterns
- `templates/branch-protection.md` — checklist to set in GitHub UI
- `templates/dependabot.yml` — automated dependency PRs
