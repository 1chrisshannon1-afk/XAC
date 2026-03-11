# Folder Structure Convention

Standard layout for all XAC-consuming projects.

## Required Layout

```
project-root/
  _XAC/                              # Shared infra (CI, IaC, monitoring, docs, cursor, hooks)
  _XAC_Config_<ProjectName>/         # ALL project-specific config (central hub)
    ci/config.ps1                    #   Master config -- project identity, GCP, paths, test sets
    cursor/                          #   Cursor rules/ignore project additions
    docker/                          #   Dev-only Dockerfiles
    iac/                             #   Terraform project config
    briefs/                          #   Agent briefs

  .ci/                               # Thin wrapper -- sources _XAC_Config/ci/config.ps1
  .cursor/rules/                     # Assembled from _XAC + _XAC_Config cursor rules
  .github/workflows/                 # GitHub Actions (uses XAC reusable workflows)

  entrypoint_backend/                # Backend entry point
  modules/<name>/                    # Feature modules (domain-driven)
    tests/                           #   Module unit tests
  shared/                            # Shared backend code
    tests/                           #   Shared package unit tests
  shared_frontend/                   # Shared frontend components
  integration_tests/                 # Cross-module and E2E tests (at root)

  gcp_cicd/                          # GCP deploy scripts + Cloud Build configs (sources .ci/config.ps1)
  repo_tooling/                      # Dev scripts, utilities
  repo_docs/                         # Project documentation
  _archive/                          # Deprecated content

  .cursorrules                       # Agent rules (assembled from XAC base + project)
  .cursorignore                      # Index exclusions (assembled from XAC base + project)
  local_ci.ps1                       # CI entry (sources .ci/config.ps1, runs _XAC engine)
  deploy_staging.ps1                 # Deploy to staging
  docker-compose.yml                 # Dev compose (references _XAC_Config/docker/ Dockerfiles)
  README.md                          # Project overview
```

## Key Conventions

1. **_XAC_Config_<ProjectName>/** is the central config hub. All project-specific settings, Dockerfiles, cursor rules, and IaC live here. Root files are thin wrappers or reference it.
2. **_XAC/** is shared infra. Do not add project-specific content; changes affect all projects.
3. **.ci/config.ps1** is a thin wrapper that sources _XAC_Config/ci/config.ps1. All config edits go in the canonical source.
4. **gcp_cicd/** holds deploy scripts and Cloud Build YAMLs. Its settings (GCP project, service account) come from .ci/config.ps1 via gcp-env.ps1.
5. **docker-compose*.yml** files reference Dockerfiles in _XAC_Config/docker/.
6. **modules/<name>/tests/** for module unit tests. **integration_tests/** at root for cross-module/E2E.
7. **_archive/** (lowercase) for deprecated content.
8. **ci_logs/** is a gitignored output directory. Do not commit.
