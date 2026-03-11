# Branch Conventions

**Last reviewed:** 2026-03-11

Standard branch structure so CI, deploys, and code review behave predictably across projects.

---

## Branch layout

```
main        — production code; protected, requires PR + CI pass
staging     — staging deploy trigger; protected, requires PR + CI pass
feature/*   — feature branches; merge to staging via PR
hotfix/*    — hotfix branches; can merge directly to staging and main
```

---

## Rules

- Never commit directly to `main` or `staging`
- PRs must pass full CI before merge (no bypass)
- Hotfixes that go to `main` must also be cherry-picked to `staging`
- Delete feature branches after merge
- Branch names: lowercase, hyphens, descriptive  
  Good: `feature/add-playwright-sharding`  
  Bad: `feature/fix2`

---

## How to apply this in your project

1. Configure branch protection on `main` and `staging`: require PR, require status checks (CI), no force push.
2. Use `feature/<ticket-or-description>` for all non-hotfix work; merge to `staging` first, then promote to `main` via your release process.
3. Use `hotfix/<description>` only for production fixes; merge to `main`, then cherry-pick to `staging` so both branches stay in sync.
4. Document this flow in CONTRIBUTING.md or ONBOARDING.md so contributors follow the same conventions.
