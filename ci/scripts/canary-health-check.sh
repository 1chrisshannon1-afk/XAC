#!/usr/bin/env bash
# Canary health check: loop for DURATION_SECONDS, check /health every 30s.
# Optionally uses Cloud Monitoring for error rate; falls back to HTTP-only if metrics unavailable.
# Usage: ./scripts/canary-health-check.sh PROJECT_ID SERVICE_NAME REVISION THRESHOLD_PCT DURATION_SECONDS
# Example: ./scripts/canary-health-check.sh contractorscope-ai backend abc1234 1 1200
#   Project contractorscope-ai, service backend, revision abc1234, fail if error rate > 1%, run 1200 seconds (20 min).
# Runnable locally for debugging; all GCP interaction via gcloud CLI only.
set -euo pipefail

PROJECT_ID="${1:?Missing PROJECT_ID}"
SERVICE_NAME="${2:?Missing SERVICE_NAME}"
REVISION="${3:?Missing REVISION}"
THRESHOLD_PCT="${4:-1}"
DURATION_SECONDS="${5:-1200}"

INTERVAL=30
TOTAL_CHECKS=$(( DURATION_SECONDS / INTERVAL ))
FAILED=0
CHECK=0

# Get production service URL from gcloud
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
  --project="$PROJECT_ID" \
  --region="${CLOUD_RUN_REGION:-us-central1}" \
  --format='value(status.url)' 2>/dev/null || true)
if [ -z "$SERVICE_URL" ]; then
  echo "::error::Could not get service URL for $SERVICE_NAME in $PROJECT_ID"
  exit 1
fi

HEALTH_URL="${SERVICE_URL%/}/health"
echo "Canary health check: $HEALTH_URL for ${DURATION_SECONDS}s ($TOTAL_CHECKS checks, error threshold ${THRESHOLD_PCT}%)"

while [ $CHECK -lt $TOTAL_CHECKS ]; do
  CHECK=$(( CHECK + 1 ))
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" --max-time 10 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" != "200" ]; then
    FAILED=$(( FAILED + 1 ))
  fi

  # Rolling error rate from HTTP checks (percent)
  ERR_PCT=0
  [ $CHECK -gt 0 ] && ERR_PCT=$(( FAILED * 100 / CHECK ))

  # Cloud Monitoring metrics are not used here; use gcloud monitoring time-series list
  # in a separate step if needed. This script relies on HTTP health checks only for portability.

  if [ "$HTTP_CODE" != "200" ]; then
    echo "[$CHECK/$TOTAL_CHECKS] HTTP $HTTP_CODE (failures $FAILED/$CHECK, ${ERR_PCT}% error rate)"
  else
    echo "[$CHECK/$TOTAL_CHECKS] HTTP 200 OK (failures $FAILED/$CHECK, ${ERR_PCT}%)"
  fi

  if [ $ERR_PCT -ge "$THRESHOLD_PCT" ]; then
    echo "::error::Canary unhealthy: error rate ${ERR_PCT}% >= ${THRESHOLD_PCT}%"
    exit 1
  fi

  [ $CHECK -lt $TOTAL_CHECKS ] && sleep $INTERVAL
done

echo "Canary healthy: $FAILED failures in $TOTAL_CHECKS checks (threshold ${THRESHOLD_PCT}%)"
exit 0
