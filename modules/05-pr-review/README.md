# 05 — PR Review

Where AI reviewers and humans converge. Junior teams that ship AI-generated code need a structured review step, because the cost of a missed bug in client work is reputation, not just CI minutes.

## Practice

Senior devs treat a PR as a **contract**: a self-contained change with a hypothesis ("this fixes X") and a verification plan ("here's how a reviewer can confirm"). Every PR has:

1. **A focused diff.** One feature or fix per PR. If you can't write the title in under 70 chars, split the PR.
2. **A test plan.** Bulleted, concrete steps. "Manually clicked through" doesn't count.
3. **A reviewer.** AI (CodeRabbit) reviews the mechanical layer (style, obvious bugs, test coverage). A human reviews the architectural + business-logic layer. Both are required.
4. **Required status checks** from module 04 must be green. A red PR is not reviewed.

The order matters: CI green → CodeRabbit clean → human review → merge. Never merge ahead of the AI review, because then you're trusting only one set of eyes (yours).

## Automation

### a. CodeRabbit
Free for open-source + has paid tiers for private repos. Posts inline review comments on every PR, can be configured to focus on bug detection, style, or coverage. Install via GitHub Marketplace, configure with `.coderabbit.yaml`.

See `templates/.coderabbit.yaml` — sensible defaults: blocks merge on critical findings, focuses on bug/security/perf comments, suppresses style nits (Prettier handles those).

Add `coderabbitai` to the required status checks in [branch protection](../04-ci-pipeline/templates/branch-protection.md).

### b. PR template
`.github/pull_request_template.md` — forces every PR to include summary + test plan. See `templates/pull_request_template.md`.

### c. Reviewer checklist (human side)
`templates/review-checklist.md` — a per-PR mental checklist for the human reviewer. Covers the things AI tools systematically miss:
- Does this match the task spec? (CodeRabbit can't tell)
- Are env vars added to `.env.example` AND `docs/SECRETS.md`?
- Are there any new PII handling paths that need redaction?
- Does the agent-accessibility surface (`agents.md`) still match the UI?
- Will this deploy cleanly to staging? (any new env var configured in Vercel/Coolify?)

### d. CODEOWNERS
`.github/CODEOWNERS` — auto-requests review from the right person based on changed paths. Critical for monorepos. See `templates/CODEOWNERS`.

### e. Auto-label PRs
GitHub Action (`templates/labeler.yml`) labels PRs by changed paths (`area:auth`, `area:billing`, etc.) so the AI reviewer + human can filter at a glance.

### f. Adversarial review agents

CodeRabbit reviews the diff as written. An adversarial agent is told to **break it**, which surfaces a different class of finding — the reviewer that asks "what input makes this wrong?" beats the reviewer that asks "is this idiomatic?".

Two passes, run as separate agents so neither dilutes the other:

- **Safety pass** (`templates/review-agent-safety.md`) — tries to find the input, state, or ordering that causes data loss, a permission bypass, a leaked secret, an unbounded spend, or a destructive migration. Runs on every PR that touches auth, migrations, deploy config, payments, or anything writing to production.
- **Quality pass** (`templates/review-agent-quality.md`) — duplication, dead abstraction, misplaced logic, missing test coverage for the branch just added. Not safety, but the same mechanism, and cheap to run alongside.

Rules that make this useful rather than noisy:

1. **Verify before reporting.** An agent must be able to state the concrete input and the resulting wrong output. A finding it cannot demonstrate gets dropped, not reported as a "potential issue".
2. **Separate agents, separate lenses.** Running one agent with both prompts produces a worse review than two agents with one each.
3. **Rank by blast radius, not by count.** A stale comment and a data-destroying default must not be reported in the same register — a long undifferentiated list trains the reviewer to skim.
4. **It is advisory, not a gate.** These agents propose; the human decides. Only CI and CodeRabbit block merge, because an agent that can block merge is an agent that can be prompt-injected into blocking merge.

Run locally against the diff before pushing, or wire into CI as a non-blocking commenting job. Local is cheaper and catches things before the PR exists.

### g. Built-in security review

Before writing your own, use what ships: `/security-review` runs a security pass over the changes on the current branch, and the security-guidance plugin has Claude review and fix vulnerabilities in its own changes during the session.

Run `/security-review` before opening any PR that touches auth, data access, migrations, or deploy config. It's free, it's maintained upstream, and it costs one command — the adversarial prompts in (f) are for what a general pass doesn't know about your project.

### h. Require linked issue (optional)
For client work, every PR must link an issue (the spec). A workflow check that fails if the PR body doesn't reference `#N` or `closes #N`.

## Maintenance

- **Monthly:** review CodeRabbit's flagged-but-ignored comments. Tune `.coderabbit.yaml` to suppress false positives (don't ignore real ones).
- **Quarterly:** review CODEOWNERS — has team changed? Have boundaries shifted?
- **On a missed bug post-merge:** retro the PR. Was it CodeRabbit's miss, the human's miss, or both? Update the checklist or the CodeRabbit config accordingly.
- **Cost watch:** CodeRabbit private repo pricing has tiers. Monitor monthly usage; downgrade tier if not needed.

## Files

- `templates/.coderabbit.yaml` — review focus + thresholds
- `templates/pull_request_template.md` — PR body scaffold
- `templates/review-checklist.md` — human reviewer checklist
- `templates/CODEOWNERS` — example
- `templates/labeler.yml` + `templates/labels.yml` — auto-label workflow
- `templates/review-agent-safety.md` — adversarial safety-pass agent prompt
- `templates/review-agent-quality.md` — quality-pass agent prompt
