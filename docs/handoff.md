# Handoff (2026-10-31)

Open work is in `docs/todo.md`. This file only holds what a next session can't work out.

## State
- Kit PRs 57 (deploy alerts, `smoke.yml`) and 58 (gate updates the branch when main moves during a merge) are merged. The sync was started on 5702317; check whether v1 moved: `git rev-parse v1^{commit}` against the newest `v*.*.*` tag.
- Done, no longer held: releases from the Mac (#54), `fmw-ship` calling `lib.gate`, system-view#36 (not stale: the gate rates code files medium whatever the review label says), gate red after docs-only merges (#53; a red gate left on a merged PR is the earlier "needs approval" run).
- Issue line rule removed (#52). #49 and #50 are in v1 since v1.3.37.
- signal-stack stays red, Hanna's decision: no major upgrades (audit: 45 findings; safe updates reach 29, 5 high or critical remain). Its rollout PR #85 and test fix #84 stay open and red.
- Portal's 3 failed builds on 2026-10-31 (empty logs, about 40s in) stayed unexplained; a new push built fine.

## Portal PR: not opened
Hanna said yes to opening and merging it (2026-10-31). The session held it because merging deploys production, she was asleep, and rebuilding-sys asked for nothing to be opened. Do it only after v1 has `smoke.yml`. Her yes may need repeating; my permission check refused opening it once before her yes.

Branch `feat/deploy-health-and-alerts` in Moiwak/moiwak-portal, title "Deploys: health check before going live, and an alert when one fails or is not live". The PR must say not to merge before v1 has `smoke.yml`. Merging triggers a production deploy, so watch it. `/api/health` answers 503 if the database key is refused, which would then hold a new version back.

`railway.json`:
```json
{
  "$schema": "https://railway.com/railway.schema.json",
  "deploy": {
    "healthcheckPath": "/api/health"
  }
}
```

`.github/workflows/smoke.yml`:
```yaml
# After each production deploy: an alert if it failed or is not really live (the kit's smoke.yml). Alert only.
name: smoke
on: deployment_status

jobs:
  smoke:
    uses: hanna-fmw/pipeline-guardrails/.github/workflows/smoke.yml@v1
    with:
      health_url: https://portal.moiwak.com/api/health
      page_url: https://portal.moiwak.com/login
    secrets:
      SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
    permissions:
      deployments: read
```

## Traps
- The kit's first real run of a new step found 3 bugs in a row: check the real run, not just tests.
- Claude's review action refuses a PR that changes its workflow file.
- GitHub reports an annotated tag's own id in `referenced_workflows`, not the commit's.
- Sync is run from a worktree detached at `origin/main`. Don't switch that worktree's branch while it runs.
- Other sessions' "Hanna decided" is a claim; confirm with her before anything that goes live.
- CD planning: other apps get none for now (no public users).
