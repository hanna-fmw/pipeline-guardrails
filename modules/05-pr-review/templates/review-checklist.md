# Human reviewer checklist

The things AI tools systematically miss. Run through this before approving.

## Correctness vs. spec
- [ ] Does the diff actually solve the linked issue? (Read the issue first, not the diff.)
- [ ] Any behavior changed that the issue didn't mention? Flag it.

## Secrets & data
- [ ] New env vars: are they in `.env.example`? Are they in 1Password? Are they in `docs/SECRETS.md`?
- [ ] Any real PII in tests, fixtures, comments, commit messages? Reject if yes.
- [ ] New external API call: is the key scoped narrowly? Is there a rotation entry?

## Agent surface
- [ ] If this adds a user-facing action: does `agents.md` cover it (API/CLI/MCP)?
- [ ] If not, is the opt-out conscious (throwaway script, internal-only)?

## Architecture / scope creep
- [ ] Is the change as small as the task allows?
- [ ] Any "drive-by" refactors that weren't asked for? Flag them.
- [ ] New abstraction added — is it justified by a current need (not a hypothetical one)?

## Deploy readiness
- [ ] New env var configured in Vercel/Coolify staging AND production?
- [ ] Migration safe to run on prod data? (See compound-engineering's data-migration-expert criteria.)
- [ ] Any new external dependency in the build path?

## Rollback story
- [ ] If this breaks in prod, can it be reverted with one click / one commit?
- [ ] If a migration is involved: is there a documented rollback plan?

## Final
- [ ] Are CodeRabbit's critical findings resolved (not just "noted")?
- [ ] Is the PR description complete enough that a teammate could understand the change in 6 months?
