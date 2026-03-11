#!/usr/bin/env bash
# Verify a project is correctly set up to use SharedWorkflows.
# Run from the consuming project root.
set -euo pipefail

ERRORS=0
WARNINGS=0

echo "=== SharedWorkflows Setup Verification ==="
echo ""

# Check .ci/config.ps1 exists
if [ -f ".ci/config.ps1" ]; then
  echo "[OK] .ci/config.ps1 exists"
else
  echo "[FAIL] .ci/config.ps1 not found — copy from SharedWorkflows/templates/config.ps1.template"
  ERRORS=$((ERRORS+1))
fi

# Check local_ci.ps1 exists
if [ -f "local_ci.ps1" ]; then
  echo "[OK] local_ci.ps1 exists"
else
  echo "[FAIL] local_ci.ps1 not found — copy from SharedWorkflows/templates/local_ci.ps1.template"
  ERRORS=$((ERRORS+1))
fi

# Check requirements.txt
if [ -f "requirements.txt" ]; then
  echo "[OK] requirements.txt exists"
else
  echo "[FAIL] requirements.txt not found"
  ERRORS=$((ERRORS+1))
fi

# Check docker compose file
COMPOSE_FILE="docker-compose.ci.yml"
if [ -f "$COMPOSE_FILE" ]; then
  echo "[OK] $COMPOSE_FILE exists"
else
  echo "[WARN] $COMPOSE_FILE not found — local CI needs a docker compose file for emulators"
  WARNINGS=$((WARNINGS+1))
fi

# Check GitHub workflow
if ls .github/workflows/deploy-staging*.yml 2>/dev/null | head -1 > /dev/null; then
  echo "[OK] GitHub deploy workflow found"
  # Check for unresolved placeholders
  if grep -rq "YOUR_" .github/workflows/deploy-staging*.yml 2>/dev/null; then
    echo "[FAIL] GitHub workflow still has YOUR_ placeholders — fill them in"
    ERRORS=$((ERRORS+1))
  else
    echo "[OK] No unresolved YOUR_ placeholders in workflows"
  fi
else
  echo "[WARN] No deploy-staging workflow in .github/workflows/"
  WARNINGS=$((WARNINGS+1))
fi

# Check .secrets.baseline (optional)
if [ -f ".secrets.baseline" ]; then
  echo "[OK] .secrets.baseline exists"
else
  echo "[WARN] .secrets.baseline not found (optional — preflight will warn)"
  WARNINGS=$((WARNINGS+1))
fi

echo ""
echo "=== Results ==="
echo "Errors:   $ERRORS"
echo "Warnings: $WARNINGS"
[ $ERRORS -gt 0 ] && echo "Fix errors before running CI." && exit 1
echo "Setup looks good. Run local_ci.ps1 to test."
exit 0
