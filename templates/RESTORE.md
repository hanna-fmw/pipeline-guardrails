# Backups and restore

3-2-1: the live database (copy 1), a Google shared drive (or R2) twice a day (copy 2, `.github/workflows/backup.yml`), an external disk monthly (copy 3). A failed backup posts 🔴 to Slack; the scheduled-jobs watcher notices one that never runs.

## Setup (once)

Keys go into the project's Infisical folder `/backup`, under the names below; nothing is typed in anywhere else.

1. **Google (dest drive)**, in the project's Google Cloud project: a service account `backup-writer` with no key, a workload identity pool `github` with an OIDC provider for `https://token.actions.githubusercontent.com` limited to `assertion.repository == '<owner>/<repo>' && assertion.ref == 'refs/heads/main' && assertion.job_workflow_ref.startsWith('hanna-fmw/pipeline-guardrails/.github/workflows/backup.yml@')` (only this backup job on main, never a PR branch), and `roles/iam.workloadIdentityUser` on the service account for that repo. Then a shared drive `<Project> backups` with the service account as Content manager. Put the drive id, provider and service account in `backup.yml`; none is secret.
   **R2 instead (dest r2):** bucket `<project>-backups` (EU), an API token for that bucket only; save `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_ENDPOINT`.
2. **Supabase:** Storage → S3 connection → new access key: save `STORAGE_ACCESS_KEY_ID`, `STORAGE_SECRET_ACCESS_KEY`. Save the database password as `BACKUP_PG_PASSWORD`. Put the session pooler host (Connect → Session pooler) and region in `backup.yml`.
3. **GitHub secrets:** `pipeline-guardrails/scripts/keys.sh to-github <owner>/<repo> <infisical project id> <env> /backup BACKUP_PG_PASSWORD STORAGE_ACCESS_KEY_ID STORAGE_SECRET_ACCESS_KEY` (plus the three R2 names for dest r2). `SLACK_BOT_TOKEN` is already set by the pipeline install.
4. Run the workflow once by hand (Actions → backup → Run workflow), then do the restore test below.

Copy 3, monthly: download the shared drive onto the external disk (Drive → the shared drive → select all → Download). For dest r2: `pull-backups-to-drive.sh <infisical project id> <env> <project>-backups <disk folder>`.

## Restore the database

1. Get the dump you want from `db/` in the shared drive (or bucket).
2. **Into the same project** (data lost or broken): restore only what you need, e.g. one table: `pg_restore --data-only --table=<table> -d "<connection string>" <file>.dump`. Take a fresh dump first.
3. **Into a new project** (project lost): create it, apply the repo's migrations, then `pg_restore --data-only --disable-triggers -d "<new connection string>" <file>.dump`. Point the app's env vars at the new project.
4. Secrets kept in Supabase Vault are encrypted per project: in a new project they do not decrypt, so enter them again.

## Restore Storage files

Download the folder from `storage/<bucket>` and upload it to that Storage bucket (or `rclone copy` it back with the same `RCLONE_CONFIG_SRC_*` settings the workflow uses). Files deleted in the app are still in the backup, so restore single folders when that matters.

## Test (once after setup, then every quarter)

Restore the latest dump into a fresh local Supabase (`supabase start`), check that the main tables have rows and that a few Storage files open, and write the date here.

- Last tested: never
