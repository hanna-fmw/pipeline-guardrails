# Rollback playbook — <project name>

If prod is broken, **roll back first, debug second.** Don't fix forward unless the incident is < 5 minutes old and the fix is a one-character revert.

## Vercel (production rollback)

```sh
# 1. List recent deploys, find the last known-good one (with READY state).
vercel ls --scope <team> | head -20

# 2. Promote that deploy to production. Instant — no rebuild.
vercel promote <deployment-url> --scope <team>

# 3. Verify
curl -fsS https://<prod-url>/api/health
```

Or via the Vercel dashboard: Project → Deployments → "..." → **Promote to Production** on the last good deploy.

## Coolify (production rollback)

```sh
# 1. SSH to the Coolify server
ssh root@coolify

# 2. Find the previous image tag for the service
docker images | grep <service-name>

# 3. In the Coolify UI: Service → Deploy → Rollback to previous
#    OR: edit the docker-compose to pin the previous tag and redeploy.
```

## Database rollback

**Do NOT roll back schema changes by re-running migrations in reverse** unless the migration was explicitly reversible AND you tested the rollback in staging.

1. Most "DB rollback" incidents are recovered by reverting the *application code* to the version that matched the previous schema, leaving the schema as-is.
2. If you absolutely must revert a schema change in prod:
   - Take a backup snapshot first (`pg_dump` or platform snapshot).
   - Open a one-off SQL change in a tx, with a documented `ROLLBACK;` escape hatch.
   - Have a second engineer review it before running.

## After-rollback checklist

- [ ] Prod traffic restored (smoke test green)
- [ ] Incident channel notified
- [ ] Sentry alerts acknowledged
- [ ] Tag the bad deploy with a `bad-deploy/<date>` GitHub label
- [ ] Schedule the post-mortem within 24h
