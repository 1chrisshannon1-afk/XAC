# Naming Conventions

Standard naming for all XAC-consuming projects.

## Folders

| Pattern | When | Examples |
|---------|------|----------|
| `snake_case` | Python modules, test dirs, feature modules | `estimate_engine/`, `auth/`, `tests/` |
| `UPPER_SNAKE` | Test categories, integration test groups | `API_CONTRACTS/`, `CROSS_MODULE_FLOWS/` |
| `_PascalCase` or `_UPPER` | Special/infra folders (prefixed with `_`) | `_XAC/`, `_XAC_Config_ContractorScope_/`, `_archive/` |
| `kebab-case` | Frontend component folders (when React convention) | `shared-components/` |

## Files

| Pattern | When | Examples |
|---------|------|----------|
| `snake_case.py` | Python source files | `estimate_service.py`, `firestore_store.py` |
| `PascalCase.tsx` | React components | `EstimateWizard.tsx`, `ContactList.tsx` |
| `camelCase.ts` | TypeScript utilities, hooks | `useAccessState.ts`, `apiClient.ts` |
| `UPPER_SNAKE.md` | Documentation, rules, standards | `DEPLOYMENT.md`, `FOLDER_STRUCTURE.md` |
| `kebab-case.yml` | GitHub workflows, Cloud Build configs | `deploy-staging.yml`, `ci.yml` |
| `kebab-case.ps1` | PowerShell scripts (deploy, CI) | `deploy-staging.ps1`, `restart-servers.ps1` |
| `snake_case.ps1` | PowerShell scripts (alternative, both are acceptable) | `local_ci.ps1`, `config.ps1` |
| `test_<what>.py` | Test files | `test_estimate_service.py`, `test_auth.py` |

## XAC Config Folder

```
_XAC_Config_<ProjectName>/
```

- `<ProjectName>` uses PascalCase with underscores: `ContractorScope_`, `AdminPortal_`, etc.
- Trailing underscore is convention to visually distinguish from regular folders.

## Git Branches

See `_XAC/docs/BRANCH_CONVENTIONS.md`.

| Pattern | Purpose |
|---------|---------|
| `main` | Production |
| `staging` | Pre-production (deploys on push) |
| `develop` | Development integration |
| `feature/<name>` | Feature branches |
| `hotfix/<name>` | Production hotfixes |

## Commit Messages

See `_XAC/docs/COMMIT_CONVENTIONS.md`.

```
<type>(<scope>): <description>
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `build`, `perf`, `style`, `revert`.
