# To-do

Roadmap items stay in GitHub issues for now (Hanna, 2026-10-30).

1. Confirm Railway's health check is really on for the portal: `railway.json` is merged and Railway lists the file as the setting's source, but the deploy record shows the path as null. Look in Railway, Settings, Healthcheck Path.
2. Prove the failure alert on a real failed deploy, and the gate's branch update when main moves during a merge; only the passing path has run.
3. signal-stack's sync PR fails on every sync (its audit), Hanna's decision to leave it red.
4. Remove the leftover worktrees `release-review` and `skip-rollout-review`, and the local branches `fix/release-from-mac`, `feat/drop-issue-line` and others already merged, once no session holds them.
