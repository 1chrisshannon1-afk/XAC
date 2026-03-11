#!/usr/bin/env bash
# Canary health check: repeated HTTP requests with pass/fail threshold.
# Usage: ./scripts/canary-health-check.sh <SERVICE_URL> <BAKE_MINUTES> <MAX_FAILURES> [HEALTH_PATH]
# Example: ./scripts/canary-health-check.sh https://myservice.run.app 15 2 /health
#   Bake 15 minutes; fail if more than 2 non-200 responses.
set -euo pipefail

SERVICE_URL="${1:?Missing SERVICE_URL}"
BAKE_MINUTES="${2:-15}"
MAX_FAILURES="${3:-2}"
HEALTH_PATH="${4:-/health}"

FULL_URL="${SERVICE_URL%/}${HEALTH_PATH}"
INTERVAL=60
TOTAL_CHECKS=$(( (BAKE_MINUTES * 60) / INTERVAL ))
FAILED=0

echo "Canary health check: $FULL_URL for $BAKE_MINUTES minutes ($TOTAL_CHECKS checks, max $MAX_FAILURES failures)"

for i in $(seq 1 "$TOTAL_CHECKS"); do
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" "$FULL_URL" --max-time 10 2>/dev/null || echo "000")
  if [ "$HTTP" != "200" ]; then
    FAILED=$((FAILED + 1))
    echo "[$i/$TOTAL_CHECKS] HTTP $HTTP (failure $FAILED/$MAX_FAILURES)"
  else
    echo "[$i/$TOTAL_CHECKS] HTTP 200 OK"
  fi
  if [ $FAILED -gt "$MAX_FAILURES" ]; then
    echo "::error::Canary unhealthy: $FAILED failures (threshold $MAX_FAILURES)"
    exit 1
  fi
  [ $i -lt $TOTAL_CHECKS ] && sleep $INTERVAL
done

echo "Canary healthy: $FAILED failures in $TOTAL_CHECKS checks (threshold $MAX_FAILURES)"
exit 0
