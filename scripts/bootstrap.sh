#!/usr/bin/env bash
# Bootstrap a new project for SharedWorkflows.
# Run from the consuming project root.
# Usage: ../SharedWorkflows/scripts/bootstrap.sh
set -euo pipefail

SHARED_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== SharedWorkflows Bootstrap ==="
echo "SharedWorkflows location: $SHARED_DIR"
echo "Project root: $(pwd)"
echo ""

# Create .ci/ directory
mkdir -p .ci
echo "[1/4] Created .ci/ directory"

# Copy config template
if [ ! -f ".ci/config.ps1" ]; then
  cp "$SHARED_DIR/templates/config.ps1.template" .ci/config.ps1
  echo "[2/4] Copied config template to .ci/config.ps1 — EDIT THIS FILE"
else
  echo "[2/4] .ci/config.ps1 already exists — skipping"
fi

# Copy local_ci wrapper
if [ ! -f "local_ci.ps1" ]; then
  cp "$SHARED_DIR/templates/local_ci.ps1.template" local_ci.ps1
  echo "[3/4] Copied local_ci.ps1 wrapper"
else
  echo "[3/4] local_ci.ps1 already exists — skipping"
fi

# Copy deploy workflow template
mkdir -p .github/workflows
if [ ! -f ".github/workflows/deploy-staging.yml" ]; then
  cp "$SHARED_DIR/templates/deploy-staging.yml.template" .github/workflows/deploy-staging.yml
  echo "[4/4] Copied deploy-staging.yml template — EDIT THIS FILE (replace YOUR_ placeholders)"
else
  echo "[4/4] deploy-staging.yml already exists — skipping"
fi

echo ""
echo "=== Next Steps ==="
echo "1. Edit .ci/config.ps1 — fill in all project-specific values"
echo "2. Edit .github/workflows/deploy-staging.yml — replace all YOUR_ placeholders"
echo "3. Create docker-compose.ci.yml for emulators (see docs/ONBOARDING.md)"
echo "4. Run: ./scripts/verify-setup.sh (from SharedWorkflows) to check"
echo "5. Run: .\local_ci.ps1 to test locally"
