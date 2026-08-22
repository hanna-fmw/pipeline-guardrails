# Capability-based staging: a prod-proof test environment for the AI era

A staging setup where touching production is not *forbidden* but *impossible* — built for solo devs and small teams working with AI assistants (Claude Code, Cursor, Copilot) inside the repo.

## How it was done before AI

Teams protected production with **process and trust**:

- A hosted staging server, deployed automatically from a `staging` branch
- GitHub branch protection on `main` (required reviews, required checks)
- Code review and CI pipelines as the safety net
- Separate env vars per environment, managed in the hosting platform

Crucially, every developer still *had the technical ability* to push to production — rules, reviews, and pipelines were what stopped mistakes. That works when the actors are humans who understand consequences.

## How this setup works instead

The staging workspace simply **lacks the ability** to touch production:

- Its git remote cannot reach the real repository (push URL disabled, or origin pointing at a local folder)
- Its env file contains only staging credentials — a staging database, a staging storage bucket with a bucket-scoped token
- There is no CI deploy configured from it

There is no rule to follow, because the dangerous action does not exist.

## Why this matters with AI

"Security people call it capability-based security: instead of a rule saying 'don't push' (which an AI can ignore or misunderstand), the environment simply lacks the ability to push — there's no credential and no remote to misuse. That's exactly the direction agent-sandboxing is heading in the industry, so your setup is arguably ahead of the curve for AI-assisted work, not behind it."

An AI session running inside the staging folder can misread instructions, hallucinate a command, or "helpfully" try to deploy — and none of it can reach production. Policy-based guardrails (rules files, hooks, prompts) remain useful as a second layer, but capability removal is the only layer that cannot be talked past.

---

## Setup A — no CI on the repo (deploys are manual)

Production repo: `~/_work/myapp`. Staging copy: `~/_work/myapp-staging`.

1. **Create the staging backend.** Second project on your DB provider (e.g. a free-tier Supabase project), plus a separate storage bucket with a token scoped to that bucket only.
2. **Copy the schema.** Dump schema-only from prod, apply to staging:
   ```sh
   pg_dump "$PROD_URL" --schema-only --schema=public --no-owner --no-privileges -f schema.sql
   psql "$STAGING_URL" -f schema.sql
   ```
   Watch for pieces outside the dumped schema: triggers on auth tables, realtime publications, extensions. Copy data the same way with `--data-only` when useful (include the auth schema or logins won't work).
3. **Clone locally, not from GitHub:**
   ```sh
   git clone ~/_work/myapp ~/_work/myapp-staging
   cd ~/_work/myapp-staging
   git remote set-url --push origin DISABLED
   ```
   `origin` now points at the local folder (fetch/pull still work for refreshing code); push goes to a URL that does not exist.
4. **Create `.env` in the staging folder by hand** with staging-only values. Never let an AI assistant create or edit env files — templates in chat, human creates the file.
5. **Run it** on a port that doesn't collide with your dev server, e.g. `PORT=3003 npm run dev`.
6. **Document it** in the staging folder's AI-instructions file (`CLAUDE.md` / `AGENTS.md`): what the folder is, the hard rules (no prod MCP servers, no remote "fixes"), and how to work with it.

Refresh flow: `git pull` inside the staging folder (pulls from the local prod folder). Code edits made in staging are throwaway — real changes happen in the normal repo on a branch.

## Setup B — CI deploys on push (GitHub Actions or similar)

Same as Setup A, plus the CI angle. If your staging copy must be a real GitHub clone (e.g. you want it on another machine), the clone CAN reach GitHub — so remove both capabilities:

1. `git remote set-url --push origin DISABLED_no_push` — pushing fails; fetch/pull still work on purpose.
2. **Delete the deploy workflow file** (e.g. `.github/workflows/deploy.yml`) in the staging copy so nothing in that working tree can trigger a deploy even by accident. Do not recreate it there.
3. If staging needs its own hosted deploy, deploy manually (`vercel --prod` etc.) to a *separate* hosting account/project wired to staging env vars — never to the production hosting project.

## Onboarding a team member (~5 minutes)

1. Normal `git clone` of the repo from GitHub.
2. Inside the clone: `git remote set-url --push origin DISABLED`.
3. Hand over the staging `.env` values via a password manager (1Password shared vault etc.) — never via the repo, chat, or email. They create the file themselves.
4. `npm install` / `pnpm install`, run on the agreed staging port.

Keep a short "colleague setup" section in a tracked doc (minus any secret values) so this survives vacations and handovers.

## Upgrading to a hosted staging server

When the team or the boss wants a real staging URL, nothing above is wasted — the staging DB and bucket stay exactly as they are; only where the app runs changes:

1. Create a `staging` branch in the repo, protect `main` (required reviews).
2. In the hosting platform (e.g. Vercel), point the Preview environment — or a second project — at the staging DB + staging bucket env vars.
3. Every push to `staging` now deploys a stable staging URL (e.g. `staging.example.com`).
4. Local staging clones become optional; the capability boundary moves to the hosting platform's env separation plus branch protection.

The hybrid is legitimate too: hosted staging for the team, plus a local capability-locked clone for AI-heavy sessions where you want the hard guarantee.
