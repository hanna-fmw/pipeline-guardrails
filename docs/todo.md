# To-do

Roadmap items stay in GitHub issues for now (Hanna, 2026-10-30).

1. Delete the portal's `railway.json` with its next change, not on its own (a merge deploys production). Railway read the file from 97346d8 on, yet the health check only ran after Hanna set it in the dashboard (build logs, 2026-11-01), against its docs; cause unknown. The dashboard setting is the one that works.
2. Prove the gate's branch update when main moves during a merge; only the passing path has run.
3. signal-stack's sync PR fails on every sync (its audit), Hanna's decision to leave it red.
4. Remove the leftover worktrees `release-review` and `skip-rollout-review`, and the local branches `fix/release-from-mac`, `feat/drop-issue-line` and others already merged, once no session holds them.
