# Test Placement Convention

Standard test organization for all XAC-consuming projects.

## Where Tests Live

| Test Type | Location | What It Tests |
|-----------|----------|---------------|
| Module unit tests | `modules/<name>/tests/` | Single module in isolation |
| Shared package tests | `shared/tests/` | Shared utilities, middleware, base classes |
| Backend tests | `entrypoint_backend/backend/tests/` | App entry, routes, middleware |
| Cross-module / E2E | `integration_tests/` (project root) | Multi-module flows, API contracts, security |

## Rules

1. **Module tests stay with their module.** A test for `modules/auth/` goes in `modules/auth/tests/`, not in `integration_tests/` or `shared/tests/`.

2. **Integration tests live at root.** `integration_tests/` is a top-level directory, not nested inside any module or `shared/`. It tests how modules work together.

3. **Never put integration tests in `shared/tests/`.** `shared/tests/` is only for testing the `shared/` package itself (utilities, middleware, etc.).

4. **Test file naming:** `test_<what>.py` — matches the file or feature being tested.

5. **Test directory structure mirrors source:** If the source is `modules/estimating/domain/rules.py`, the test is `modules/estimating/tests/test_rules.py`.

## Integration Test Categories

Organize `integration_tests/` by concern:

```
integration_tests/
├── API_CONTRACTS/          # Per-module API contract tests
├── CROSS_MODULE_FLOWS/     # Multi-module workflows
├── SECURITY/               # Auth enforcement, tenant isolation, rate limiting
├── EDGE_CASES/             # Error paths, observability
├── DATA/                   # Data flow tests
├── conftest.py             # Shared fixtures
└── results/                # Test run results (gitignored)
```

## What to Mock

- **Mock:** External boundaries only — Firestore, GCS, third-party APIs, payment processors.
- **Do not mock:** Our own services, controllers, or domain logic. Test the real code path.

## Running Tests

```powershell
# Module tests
pytest modules/<name>/tests/

# Shared tests
pytest shared/tests/

# Integration tests (requires servers — use restart_servers.ps1)
pytest integration_tests/

# Full local CI
.\local_ci.ps1
```
