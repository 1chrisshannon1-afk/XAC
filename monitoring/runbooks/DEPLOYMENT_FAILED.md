# Runbook: Deployment Failed

**Last reviewed:** 2026-03-11  
**Severity:** WARNING

## What this alert means

A Cloud Build job has failed. The pipeline that builds and/or deploys the service did not complete successfully.

## Immediate actions (first 5 minutes)

1. Open **Cloud Build → History** and find the failed build.
2. Open the build log and identify the failing step (e.g. `docker build`, `pytest`, `gcloud run deploy`).
3. If the failure is a test failure, check the test output; if it is a permission error, check IAM and WIF.

## Investigation steps

- **List recent failed builds:**
  ```bash
  gcloud builds list \
    --filter="status=FAILURE" \
    --project=PROJECT_ID \
    --limit=5
  ```
- **View log for a specific build:**
  ```bash
  gcloud builds log BUILD_ID --project=PROJECT_ID
  ```
- Check whether the failure is consistent (same step every time) or flaky (intermittent).

## Common causes and fixes

| Cause | How to confirm | Fix |
|-------|----------------|-----|
| Docker build error | Log shows Dockerfile step failure | Fix Dockerfile or dependency; fix base image tag. |
| Test failure | Log shows pytest or test runner failure | Fix failing test or revert the commit that introduced it. |
| Permission error | Log shows 403 or "permission denied" | Grant the Cloud Build SA or CI SA the missing role (e.g. run.admin, secretmanager.secretAccessor). |
| Artifact Registry quota | Log shows quota exceeded | Request quota increase or clean old images. |
| Network / transient | Failure is intermittent | Retry the build; if it persists, treat as one of the above. |

## Escalation

If the same build fails repeatedly and the fix is not obvious, escalate to the platform or DevOps owner. Blocking deploys may require a hotfix path (e.g. deploy from a branch with tests skipped in emergency).

## How to silence this alert

Not recommended — deployment failures should always be investigated. If you must (e.g. known broken branch), document and set a short mute with a ticket to fix.
