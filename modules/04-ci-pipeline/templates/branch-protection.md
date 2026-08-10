# Branch protection checklist (one-time, per repo)

GitHub → Settings → Branches → Add rule → Branch name pattern: `main`

- [x] Require a pull request before merging
  - [x] Require approvals: **1** (or 2 for client work)
  - [x] Dismiss stale approvals on new commits
  - [x] Require review from Code Owners (if `.github/CODEOWNERS` exists)
- [x] Require status checks to pass before merging
  - [x] Require branches to be up to date
  - **Required checks** (after `ci.yml` has run at least once):
    - `lint`
    - `secret-scan`
    - `typecheck`
    - `test`
    - `build`
    - `coderabbitai` (after module 05 installed)
- [x] Require conversation resolution before merging
- [x] Require linear history
- [x] Require signed commits *(optional but recommended; set up commit signing via SSH or GPG first)*
- [x] Do not allow bypassing the above settings (no admin override)
- [x] Restrict who can push to matching branches → empty (no direct pushes)
- [x] Allow force pushes → **disabled**
- [x] Allow deletions → **disabled**

## Tag protection

Settings → Tags → Add rule:
- Pattern: `v*` → No force pushes, no deletions.

## Secrets

Settings → Secrets and variables → Actions:
- `GITLEAKS_LICENSE` *(only if using gitleaks org license — free tier doesn't need it)*
- `SLACK_WEBHOOK_URL` *(optional, for weekly audit notifications)*

Repo secrets are encrypted, scoped to this repo. Never commit them, never echo them in workflow logs (`::add-mask::` if you must use them).
