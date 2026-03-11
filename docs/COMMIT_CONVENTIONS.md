# Commit Conventions

**Last reviewed:** 2026-03-11

Use Conventional Commits format so history is consistent and tooling (changelogs, semantic versioning) can be applied later.

---

## Format

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:** `feat`, `fix`, `chore`, `docs`, `test`, `refactor`, `perf`, `ci`

---

## Examples

```
feat(auth): add OAuth2 support for Google accounts
fix(estimate-engine): handle null material costs
ci(shared): add Trivy container scanning
chore(deps): bump ruff to 0.14.0
```

---

## Rules

- Subject line max 72 characters
- Use imperative mood ("add" not "added")
- Reference issue numbers in footer: `Closes #123`
- Breaking changes: add `BREAKING CHANGE:` in footer

Benefits: enables automatic changelog generation and semantic versioning in the future.

---

## How to apply this in your project

1. Add a pre-commit or PR check that validates the first line of each commit message matches `<type>(<scope>): <description>` (regex or a small script).
2. Document the types and examples in CONTRIBUTING.md or COMMIT_CONVENTIONS.md in your repo.
3. Use the footer for `Closes #issue` and `BREAKING CHANGE:` so automation can link commits to issues and flag breaking changes.
