# 03 — Local Git Hooks

Last line of defense before code leaves the developer's machine. Fires on `git commit` and `git push`. CI catches what these miss, but CI is slow and public — fixing it locally is cheaper and quieter.

## Practice

Senior devs run three classes of check locally, on every commit:

1. **Secret + PII scan** (global, every repo, every time) — secrets and real client data must never reach a commit object, because git history is forever.
2. **Lint + format on changed files** (lint-staged) — keeps the diff clean and consistent without burning CPU on the whole repo.
3. **Type check + tests on changed scope** — catches the obvious breaks before CI does.

Plus a **global `.gitignore`** so the same noise (OS files, editor configs, AI-assistant state) is silently excluded everywhere, not maintained per-repo.

The principle: **hooks fail loud, fast, and locally**. They never "pass with warnings." A passing hook means safe to push.

## Automation

### a. Pre-commit: secret + PII scan
Install [`git-guard`](https://github.com/hanna-fmw/git-guard) — sets `core.hooksPath ~/.git-hooks`, which applies to every repo **that does not set its own**. husky sets a repo-local `core.hooksPath`, and git honours only one, so in any husky repo the global hook is skipped entirely and the scans must be called from `.husky/pre-commit` instead (the template does this). Add patterns for: your real name + variants, real client emails, server IPs, machine-local paths (`/Users/<you>/...`). Block any match. See its README for pattern setup.

For the AI-leak class specifically: `git-guard` catches the *path/value* class. Pair with [`gitleaks`](https://github.com/gitleaks/gitleaks) for *format* class (AWS keys, GitHub PATs, Stripe keys, JWTs).

```sh
brew install gitleaks
# add to ~/.git-hooks/pre-commit (after git-guard's existing logic):
gitleaks git --staged --redact --no-banner || exit 1
```

### b. Global `.gitignore`
```sh
git config --global core.excludesFile ~/.gitignore_global
```
Then `~/.gitignore_global` (see `templates/.gitignore_global`):
- OS: `.DS_Store`, `Thumbs.db`
- Editors: `.vscode/`, `.idea/`, `*.swp`
- AI assistants: `.claude/`, `CLAUDE.md`, `.cursor/`, `.aider*`, `.windsurf/`
- Env: `.env`, `.env.*`, `!.env.example`
- Local notes: `docs/`, `NOTES.md`, `SCRATCH.md`
- Secrets: `*.pem`, `*.key`, `id_rsa*`

### c. Pre-commit: lint + format (lint-staged + husky)
```sh
pnpm add -D husky lint-staged
pnpm exec husky init
```
`package.json`:
```json
{
  "lint-staged": {
    "*.{ts,tsx,js,jsx}": ["eslint --fix", "prettier --write"],
    "*.{md,json,yml,yaml}": ["prettier --write"]
  }
}
```
`.husky/pre-commit`:
```sh
pnpm exec lint-staged
bash ./scripts/check-env-example.sh    # from module 01
```

### d. Pre-push: type-check + tests
`.husky/pre-push`:
```sh
pnpm typecheck && pnpm test --run
```
For monorepos, scope to changed packages: `turbo run typecheck test --filter=...[origin/main]`.

### e. Commit message lint (commitlint)
Enforce Conventional Commits — see [module 02](../02-git-hygiene/).

## Maintenance

- **On new project:** run `pipeline-guardrails init` (planned) — installs husky, lint-staged, the scripts, and the `.gitignore_global` line. Until the CLI exists, see `templates/setup.sh`.
- **Quarterly:** `brew upgrade gitleaks` + re-check `git-guard` pattern file for new client/server names.
- **On new AI tool adoption** (e.g. new IDE assistant): add its state dir to `~/.gitignore_global` the same day.
- **When `git-guard` blocks something incorrectly:** never `--no-verify`. Either fix the pattern or fix the file.

## Files

- `templates/.gitignore_global` — paste-ready global ignore
- `templates/.husky/pre-commit` — sample
- `templates/.husky/pre-push` — sample
- `templates/package.json.snippet` — lint-staged + scripts
- `templates/setup.sh` — bootstrap a new repo (idempotent)
