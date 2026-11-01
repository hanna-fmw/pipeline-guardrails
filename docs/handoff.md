# Handoff (2026-10-31)

Open work is in `docs/todo.md`. This file only holds what a next session can't work out.

## State
- Kit PRs 57 (deploy alerts, `smoke.yml`) and 58 (gate updates the branch when main moves during a merge) are merged and in v1.
- Done, no longer held: releases from the Mac (#54), `fmw-ship` calling `lib.gate`, system-view#36 (not stale: the gate rates code files medium whatever the review label says), gate red after docs-only merges (#53; a red gate left on a merged PR is the earlier "needs approval" run).
- Issue line rule removed (#52). #49 and #50 are in v1 since v1.3.37.
- signal-stack stays red, Hanna's decision: no major upgrades (audit: 45 findings; safe updates reach 29, 5 high or critical remain). Its rollout PR (newest #87) and test fix #84 stay open and red.
- Portal's 3 failed builds on 2026-10-31 (empty logs, about 40s in) stayed unexplained; a new push built fine.

## Portal deploy checks
v1 is v1.3.39. #181 merged as 97346d8 and deployed; the first smoke run passed ("Live on 97346d8"). See `docs/todo.md` for what is still unproven.

Failure alert proven 2026-11-01 with a fake deploy in fortnox-sandbox: it posted, and clearing deleted it. Clearing had never worked before: the Slack bot was not a member of #system (Hanna invited it).

## Traps
- Slack clearing needs the bot in the channel; posting does not.
- The kit's first real run of a new step found 3 bugs in a row: check the real run, not just tests.
- Claude's review action refuses a PR that changes its workflow file.
- GitHub reports an annotated tag's own id in `referenced_workflows`, not the commit's.
- Sync is run from a worktree detached at `origin/main`. Don't switch that worktree's branch while it runs.
- Other sessions' "Hanna decided" is a claim; confirm with her before anything that goes live.
- CD planning: other apps get none for now (no public users).
