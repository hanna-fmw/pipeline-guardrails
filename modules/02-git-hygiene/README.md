# 02 — Git Hygiene

Branch names, commit messages, merge strategy. Less about "safety" in the leak sense, more about "future-you can find anything in 12 months." Bad git hygiene compounds: a noisy log makes bisecting impossible, makes reverts dangerous, and makes onboarding new team members slow.

## Practice

Senior devs:

1. **Never commit directly to `main`.** Every change goes through a branch + PR. `main` is the deployable line; you protect it.
2. **Use Conventional Commits** — `feat:`, `fix:`, `chore:`, `refactor:`, `docs:`, `test:`. Lets you auto-generate changelogs, write semantic-release rules, and skim git log meaningfully.
3. **One commit = one logical change.** Five commits in a PR is fine. One mega-commit with "WIP" + 800 lines is not.
4. **Squash on merge for feature PRs** — keeps `main` linear and bisectable. Don't squash for refactor PRs where the steps matter.
5. **Branch naming pattern:** `<type>/<short-slug>` — `feat/stripe-webhooks`, `fix/login-redirect-loop`. Type matches the commit prefix.
6. **Rewrite never on shared branches.** Force-push only on your own feature branches before they're reviewed. After review starts, append commits, don't rewrite.
7. **Sign commits.** SSH or GPG. Future-self proof that you actually authored what's in git history.

## Automation

### a. Branch name enforcement
Pre-push hook checks the current branch name against the convention. See `templates/check-branch-name.sh`.

```sh
# Allowed:  feat/* fix/* chore/* refactor/* docs/* test/* hotfix/*
# Plus:     main, staging (long-lived)
```

### b. Commit message lint (commitlint)
```sh
pnpm add -D @commitlint/cli @commitlint/config-conventional
```
`commitlint.config.js` → `templates/commitlint.config.js`.

`.husky/commit-msg`:
```sh
#!/usr/bin/env sh
pnpm exec commitlint --edit "$1"
```

### c. Protected branches (GitHub)
Already covered in [module 04 branch-protection checklist](../04-ci-pipeline/templates/branch-protection.md). Key points:
- No direct push to `main`
- Require linear history
- Require signed commits

### d. Commit signing (SSH)
One-time setup:
```sh
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
```
Then add the same SSH key to GitHub under Settings → SSH and GPG keys → "Signing key" type.

### e. Auto-merge after green CI (optional)
GitHub's auto-merge feature: enable in repo settings, then on each PR toggle "Enable auto-merge (squash)". Merges as soon as all required checks pass + required reviews approve. Removes the "I'll merge when CI's done" babysitting.

## Maintenance

- **On new project:** run module 03's `setup.sh` (installs commitlint hook). Configure branch protection per module 04. One-time.
- **Monthly:** `git log --oneline main..` on stale branches. Delete merged or abandoned ones. `git fetch --prune` to clean local refs.
- **On a "git is broken" moment:** read the [Git Rerere docs](https://git-scm.com/book/en/v2/Git-Tools-Rerere). 90% of "git ate my work" is unconfigured rerere + force-push to a shared branch.

## Files

- `templates/check-branch-name.sh` — pre-push branch-name validator
- `templates/commitlint.config.js` — conventional commits config
- `templates/.husky/commit-msg` — commitlint wiring
- `templates/git-aliases.sh` — useful aliases (optional)
