# 01 — Secrets & Environment

How keys, tokens, and `.env` files are stored, shared, rotated, and inventoried. Foundation for every other safety module — if secrets are sloppy here, the rest is theatre.

## Practice

Senior devs treat secrets as **owned, rotated, inventoried**. Three rules:

1. **A secret has a name, an owner, a scope, a creation date, and a rotation date.** If you can't list all five for a given key, you don't really have control of it.
2. **Secrets never live in source control, chat, transcripts, or screenshots.** Source of truth is a **secret manager** (1Password). The repo only contains the *names* (in `.env.example`) and the loading code.
3. **Per-environment, per-project, scoped as narrowly as possible.** No "all-powerful service account" reused across three projects. If a key leaks, only one project + one environment is affected.

### The `.env` ladder

| File | Purpose | Tracked in git? |
|---|---|---|
| `.env.example` | Variable **names** + descriptive comments. No values. Updated whenever a new var is added. | ✅ Yes |
| `.env.local` | Local dev values, pulled from 1Password. Personal. | ❌ No (gitignored) |
| `.env.staging` / `.env.production` | Set in the deploy platform (Vercel / Coolify), NOT in the repo. | ❌ Never |
| `.env.test` | Fake values for unit tests (e.g. `STRIPE_KEY=sk_test_dummy`). | ✅ Yes — if dummy only |

### Storage: 1Password as the single source of truth

- One **vault per project** (or per client). Vault name matches the project.
- One **item per secret**, fields: `value`, `environment`, `created`, `rotate-by`, `scope-notes`.
- Optional **`.env` item** per env, attached as a file, for fast bulk-load. Bulk-load convenience does NOT replace per-key items.
- Team members get vault access; revocation = remove from vault.

### Rotation cadence

| Secret type | Rotation | Trigger-rotate also if |
|---|---|---|
| Production API keys (Stripe, Supabase, OpenAI, etc.) | Every 90 days | Team member offboards, suspected leak, key appears in any transcript |
| OAuth client secrets | Every 180 days | Same as above |
| Database passwords | Every 90 days | Same |
| SSH keys | Yearly | Laptop loss/replacement |
| Personal access tokens (GitHub, Vercel, etc.) | Every 90 days, scoped to one task | Always — never long-lived |

A leak that lands in a Claude transcript, screenshot, or screen recording = rotate immediately, no exceptions.

### Per-project key inventory

A `docs/SECRETS.md` (gitignored) in every project, listing every secret name, where it lives in 1Password, who owns rotation, and the rotate-by date. The CLI `pipeline-guardrails secrets audit` (planned) will diff `.env.example` against `docs/SECRETS.md` and flag undocumented vars.

## Automation

### a. `.env.example` enforcement
Pre-commit hook checks: every `process.env.X` (or `os.getenv("X")`) in the codebase has a corresponding line in `.env.example`. See `templates/check-env-example.sh`.

### b. 1Password CLI integration
- Install: `brew install --cask 1password-cli` then `op signin`.
- Load env in dev: `op run --env-file=.env.local.tmpl -- pnpm dev` — values are pulled from 1Password at runtime, never written to disk.
- `.env.local.tmpl` contains references like `OPENAI_API_KEY=op://acme-projectX/openai-prod/value`. See `templates/.env.local.tmpl`.

### c. Rotation reminders
A recurring job (launchd, cron, or a scheduled CI workflow) runs `op item list --vault acme-projectX --format=json | jq` against each project vault, parses the `rotate-by` field, and surfaces anything due within 14 days. Not shipped as a template — the scheduling half is machine-specific, and the query above is the part worth copying.

### d. Secret inventory diff
`templates/audit-secrets.sh` compares `.env.example` against `docs/SECRETS.md` and errors on any var missing from the inventory. It reads names only, never values. Wire it into `.husky/pre-push` (module 03 ships that hook) or run it in CI — the module 03 pre-push template already calls it.

### e. Block secrets in transcripts
Handled by [module 06](../06-claude-guardrails/) — the PreToolUse hook refuses to read `.env*` files, the PostToolUse hook scrubs secret-shaped strings from Bash output.

## Maintenance

- **Weekly:** glance at the rotation reminder notifications. Anything red gets rotated this week.
- **Monthly:** for each active project, run `op item list --vault $PROJECT`. Cross-check against `.env.example`. Delete obsolete items.
- **Quarterly:** review the scope of every long-lived token. Can it be narrower? Can it be replaced with a short-lived OAuth flow?
- **On team change:** rotate every secret that the leaving person could see. Don't trust "they're trustworthy."
- **On project archive:** rotate everything one last time, then revoke. Don't leave dormant keys live.

## Files

- `templates/.env.example` — starter with comments
- `templates/.env.local.tmpl` — 1Password reference template for `op run`
- `templates/check-env-example.sh` — pre-commit enforcement
- `templates/audit-secrets.sh` — pre-push diff
- `templates/SECRETS.md.template` — per-project inventory starter
