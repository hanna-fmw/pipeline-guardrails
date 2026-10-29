# Shared rules

For any AI agent working in one of these repos, also one that runs without the owner's machine (a cloud session, CI).

- **Secrets:** never print, commit or write a credential, and never create or edit `.env*` or other key files, not even with placeholders. Keys come from the environment at run time.
- **Git:** a repo with `.github/workflows/pipeline.yml` takes every change through a pull request, never a commit to main. A repo owned by an employer's organisation: work on a branch, never main. Any other repo: commit and push to main. Never set an author name or email (the repo's config decides), and no Co-Authored-By lines.
- **Swedish** text uses real å, ä, ö.
- **Notes, in a private repo:** plans, handoffs and notes go in `docs/`, which is committed, so never a secret in it. Open items go in `docs/todo.md`; code work is a GitHub issue. In a public repo, nothing personal is committed.
