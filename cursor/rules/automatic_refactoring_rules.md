# Automatic Refactoring Rules for Files > 500 Lines

## Safety First — Human Approval Required

- NEVER execute refactoring automatically without explicit human approval.
- ALWAYS provide preview/dry-run before making changes.
- ALWAYS offer rollback mechanisms.
- ALWAYS test thoroughly before and after refactoring.

## Detection

- Files exceeding 500 lines trigger refactoring evaluation.
- Scope: Python (.py), JavaScript/TypeScript (.js/.ts/.tsx).
- Excluded: config files, generated files, venv/node_modules, test fixtures.

## Safety Measures

### Pre-Refactoring

1. Ruff quality check must pass.
2. File must parse without syntax errors.
3. Warn if test coverage < 80%, block if < 50%.
4. Backup original file before changes.
5. Check git status — warn if uncommitted changes.

### Operation Limits

- Max changes per file: 50 lines or 10 functions (whichever is smaller).
- Max execution time: 300 seconds.
- Circuit breaker: stop after 3 consecutive failures.
- Atomic: all changes succeed or all are rolled back.

## Strategies

| Strategy | When |
|----------|------|
| Extract function/method | Function > 50 lines, multiple responsibilities |
| Extract class | Class > 200 lines, multiple responsibilities |
| Extract module | File > 1000 lines, clear domain boundaries |
| Extract configuration | Hardcoded values, magic numbers > 10 |

For files > 2000 lines: multi-file extraction (services first, then data models, then business logic).

## Agent Behavior

| Action | Allowed? |
|--------|----------|
| Detect large files | Yes |
| Analyze structure | Yes |
| Generate plan | Yes |
| Create preview | Yes |
| Execute changes | Only after explicit human approval |

## Post-Refactoring

1. All tests must pass.
2. New tests for extracted code (90%+ coverage target).
3. Ruff check must pass.
4. Verify no performance regression (< 5% degradation).

## Rollback

- Backup created before refactoring.
- Full rollback: restore original file.
- Partial rollback: revert specific changes.
- Module rollback: remove extracted modules and inline code.
