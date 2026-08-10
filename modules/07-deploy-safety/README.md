# 07 — Deploy Safety

The final gate. Code that survives lint, tests, CodeRabbit, and human review can still break production — wrong env var, missing migration, regional outage, or a regression that only shows up under real data. This module is about **catching it before clients do** and **recovering fast when it sneaks through**.

## Practice

Senior devs treat deploys as a **2-step ritual, not a button**:

1. **Pre-deploy verification** — confirm env vars, migrations, and dependent services are ready *before* hitting deploy. Cheap; prevents 80% of deploy failures.
2. **Deploy with a preview/staging step** — never deploy straight to prod. Preview URL → manual smoke test → promote to prod.
3. **Post-deploy monitoring** — for the first 15 minutes after promotion, watch error rates, latency, and the smoke endpoints. Roll back the moment something deviates.
4. **One-click rollback path** — every deploy must be reversible without a code change. Vercel has instant rollback; Coolify has previous image; Railway has redeploy-previous.

Rules:

- **No deploys on Friday afternoon** unless it's a hotfix. The cost of a 12-hour incident on a weekend is higher than the cost of waiting until Monday.
- **No deploys with red CI**, ever. Don't "I'll fix forward."
- **Migrations and code in separate deploys** when possible. Migrate first (with backwards-compatible schema), deploy code that uses the new schema, then deploy a code change that removes the old.
- **Staging is real.** If you only deploy to staging the moment before prod, it's a fiction. Use it for every PR.

## Automation

### a. Pre-deploy verification script
`templates/preflight.sh` — runs locally or in CI before `vercel deploy --prod` / `coolify deploy`. Checks:
- Required env vars present in target env (`vercel env ls` / Coolify API)
- Migrations applied to target DB (Prisma: `prisma migrate status`)
- Smoke endpoint on staging returns 200
- Git commit signed + on `main` (no accidental feature-branch deploy)

### b. GitHub Actions deploy workflow
`templates/deploy.yml` — runs on push to `main`. Steps:
1. Preflight check (above)
2. Deploy to staging (Vercel preview / Coolify staging)
3. Smoke test against staging URL
4. Wait for manual approval (GitHub Environments + required reviewer)
5. Deploy to prod
6. Post-deploy smoke test against prod
7. Notify on success/fail

GitHub Environments give per-environment secrets + per-environment required reviewers — paid feature, but well worth it for client work.

### c. Vercel-specific gates
- **Commit author email match** — Hobby plan blocks deploys when `git log --format=%ae -1` doesn't match the Vercel account's verified email. Already documented in `~/.claude/rules/github-accounts.md`. Pre-deploy script checks this BEFORE pushing.
- **maxDuration** — set explicitly in `vercel.json` per route. Default ceilings differ by plan; surprise timeouts cost real money + bad UX.
- **Preview environment protection** — gate preview URLs with Vercel password protection or Cloudflare Access.

### d. Coolify-specific gates
- **Don't publish DB container ports on 0.0.0.0**.
- **Don't set Ports Mappings** — blocks zero-downtime rolling updates.
- Preflight script should hit Coolify's API to confirm the previous successful deploy is still queryable (rollback target).

### e. Post-deploy smoke test
`templates/smoke-test.sh` — `curl`s key endpoints, checks response codes + body sentinels. Runs both immediately after deploy AND on a 5-min schedule for the first hour.

### f. Rollback playbook
`templates/ROLLBACK.md` — per-deploy-target, copy-pasteable rollback steps for Vercel + Coolify. Lives in the repo; updated whenever the deploy pipeline changes.

### g. Sentry (or equivalent) error monitoring
Spike alerts on error rate or new error types in the first 15 min post-deploy. Webhook to Slack/Discord. See `templates/sentry-alert-rules.md`.

## Maintenance

- **Quarterly:** rollback drill. Pick a staging environment, roll back, confirm the documented steps work. Update `ROLLBACK.md` if anything has shifted.
- **Per-deploy:** confirm the rollback target is set BEFORE deploying (Vercel: previous deploy still listed; Coolify: previous image tag still present).
- **On any prod incident:** post-mortem document → which guardrail missed → which guardrail to add.
- **Pricing watch:** Vercel/Coolify usage tiers. Caps protect against runaway costs (DDoS, infinite-loop API call).

## Files

- `templates/preflight.sh` — pre-deploy verification
- `templates/deploy.yml` — GH Actions deploy workflow
- `templates/smoke-test.sh` — post-deploy smoke test
- `templates/ROLLBACK.md` — rollback playbook template
- `templates/sentry-alert-rules.md` — alert config
- `templates/vercel.json` — sample with maxDuration set per route
