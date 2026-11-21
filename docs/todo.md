# To-do

Roadmap items stay in GitHub issues for now (Hanna, 2026-10-30).

1. Delete the portal's `railway.json` with its next change, not on its own (a merge deploys production). Railway read the file from 97346d8 on, yet the health check only ran after Hanna set it in the dashboard (build logs, 2026-11-01), against its docs; cause unknown. The dashboard setting is the one that works.
2. Prove the gate's branch update when main moves during a merge; only the passing path has run.
3. signal-stack's sync PR fails on every sync (its audit), Hanna's decision to leave it red.
4. Remove the leftover worktree `release-review` and its branch `worktree-release-review` once no session holds them.

- [ ] 2026-11-21 (from ops): `scripts/keys.sh` (get) calls Infisical without naming its login; it works only where the folder is bound to the right one (this Mac's default is work). Please add `--profile`.
- [ ] 2026-11-21 (from ops): From moiwak-portal via ops: the Moiwak GitHub org (free plan, 2,000 private Actions minutes/month) ran out of minutes on 2026-11-21; jobs no longer start until 2026-12-01. This month: shopify-site pipeline ~430 runs (385 on pull_request, every push), moiwak-portal pipeline ~55 runs (~150 job-seconds each; every job billed as a full minute), portal smoke.yml 630 deployment_status runs (0 s). Hanna does not want a paid plan. Cut the kit's minutes to fit 2,000 a month: full set on ready-for-review/merge, not every push; skip Claude review/security on docs-only changes; cancel superseded runs; fewer jobs per run. Until 1 Dec Moiwak sessions merge on local checks.