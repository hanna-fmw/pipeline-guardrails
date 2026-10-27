# Backups and restore

3-2-1: the live database (copy 1), Cloudflare R2 twice a day (copy 2, `.github/workflows/backup.yml`), an external drive monthly (copy 3, `pull-backups-to-drive.sh` in pipeline-guardrails). A failed backup posts 🔴 to Slack; the scheduled-jobs watcher notices one that never runs.

## Setup (once)

Every key goes into the project's Infisical folder `/backup`, under the names below; nothing is typed in anywhere else.

1. **R2:** create bucket `<project>-backups` (EU jurisdiction). Lifecycle rule: delete `db/` after 90 days; keep `storage/`. Create an R2 API token with Object Read & Write on that bucket only. Save `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_ENDPOINT` (the EU endpoint).
2. **Supabase:** Storage → S3 connection → new access key: save `STORAGE_ACCESS_KEY_ID`, `STORAGE_SECRET_ACCESS_KEY`. Save the database password as `BACKUP_PG_PASSWORD`. Put the session pooler host (Connect → Session pooler) and region in `backup.yml`; they are not secret.
3. **GitHub secrets:** `pipeline-guardrails/scripts/secrets-from-infisical.sh <owner>/<repo> <infisical project id> <env> /backup BACKUP_PG_PASSWORD R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_ENDPOINT STORAGE_ACCESS_KEY_ID STORAGE_SECRET_ACCESS_KEY`. `SLACK_BOT_TOKEN` is already set by the pipeline install.
4. Run the workflow once by hand (Actions → backup → Run workflow), then do the restore test below.

Drive copy, monthly: `pull-backups-to-drive.sh <infisical project id> <env> <project>-backups <drive folder>`.

## Restore the database

1. Download the dump you want: `aws s3 cp s3://<project>-backups/db/<file>.dump . --endpoint-url <R2 endpoint>`.
2. **Into the same project** (data lost or broken): restore only what you need, e.g. one table: `pg_restore --data-only --table=<table> -d "<connection string>" <file>.dump`. Take a fresh dump first.
3. **Into a new project** (project lost): create it, apply the repo's migrations, then `pg_restore --data-only --disable-triggers -d "<new connection string>" <file>.dump`. Point the app's env vars at the new project.
4. Secrets kept in Supabase Vault are encrypted per project: in a new project they do not decrypt, so enter them again.

## Restore Storage files

`rclone copy dst:<project>-backups/storage/<bucket> src:<bucket>` with the same `RCLONE_CONFIG_*` settings the workflow uses. Files deleted in the app are still in the backup, so restore single folders when that matters.

## Test (once after setup, then every quarter)

Restore the latest dump into a fresh local Supabase (`supabase start`), check that the main tables have rows and that a few Storage files open, and write the date here.

- Last tested: never
