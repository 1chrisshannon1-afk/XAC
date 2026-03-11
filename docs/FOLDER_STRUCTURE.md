# Folder Structure Convention

Standard layout for all XAC-consuming projects. Three XAC folders separate shared infrastructure, project configuration, and project-specific operations.

## The Three XAC Folders

```
project-root/
  _XAC_Base/                           # SHARED platform (never project-specific)
  _XAC_Config/                         # Project XAC config (CI, cursor rules, IaC)
  _Config_Project/                     # Project ops (docker, deploy, GCP scripts, docs)
```

| Folder | Ownership | Changes when... | Contains |
|--------|-----------|-----------------|----------|
| `_XAC_Base/` | XAC maintainers | XAC is updated (sync workflow) | CI engine, hooks, templates, IaC modules, monitoring, docs |
| `_XAC_Config/` | Project team + XAC onboarding | CI config changes, cursor rules change, IaC changes | `ci/config.ps1`, `ci/local_ci.ps1`, cursor rules, Terraform |
| `_Config_Project/` | Project team | Docker, deploy scripts, GCP setup, project docs change | Dockerfiles, compose files, deploy scripts, GCP scripts, tooling configs |

## Full Layout

```
project-root/
  _XAC_Base/                           # Shared platform — do not add project content
    ci/
      local_ci/core.ps1                #   CI engine (called by _XAC_Config/ci/local_ci.ps1)
      hooks/                           #   Pre-commit, pre-push hooks
      scripts/                         #   Bootstrap, verify-setup
      templates/                       #   config.ps1, Dockerfile, docker-compose.ci.yml templates
    cursor/                            #   Base cursor rules and ignore patterns
    docs/                              #   XAC conventions and references
    iac/modules/                       #   Terraform modules (project-baseline, cloud-run, etc.)
    monitoring/                        #   Dashboards, runbooks
    scripts/onboard-xac.ps1            #   One-command onboarding

  _XAC_Config/                         # Project XAC configuration
    ci/
      config.ps1                       #   Master config (GCP, paths, test sets, ruff excludes)
      local_ci.ps1                     #   Local CI entry point (loads config, runs engine)
      hooks/                           #   Project-specific pre-commit extras
    cursor/                            #   Project cursor rules and ignore additions
    iac/                               #   Project Terraform (uses _XAC_Base/iac/modules/)

  _Config_Project/                     # Project-specific operations
    docker/                            #   Dockerfiles and docker-compose files
    gcp/                               #   GCP setup scripts (one-time and operational)
    gcp_cicd/                          #   Cloud Build YAMLs, gcp-env.ps1
    scripts/                           #   Deploy, CI support, utilities, restart_servers
    tooling/                           #   Canonical source for root config files (synced to root)
    cicd/                              #   CI/CD pipeline docs
    docs/                              #   Project-specific standards (testing, etc.)
    github/                            #   GitHub config (workflows, CODEOWNERS, templates)
    briefs/                            #   Agent briefs for this project

  .ci/config.ps1                       # Thin wrapper → _Config_Project/ci/config.ps1
  .cursor/rules/                       # Assembled from _XAC_Base + _XAC_Config cursor rules
  .github/workflows/                   # GitHub Actions (synced from _Config_Project/github/)

  entrypoint_backend/                  # Backend entry point
  modules/<name>/                      # Feature modules (domain-driven)
    tests/                             #   Module unit tests
  shared/                              # Shared backend code
  shared_frontend/                     # Shared frontend components
  integration_tests/                   # Cross-module and E2E tests (at root)
  repo_tooling/                        # Dev scripts, utilities

  (root config files)                  # See ROOT_FILES_MANIFEST.md for why each is at root
```

## Key Conventions

1. **No root-level stub scripts.** Docker, CI, deploy, and server management scripts live in their canonical locations. Users invoke them with full paths (e.g. `.\_Config_Project\docker\docker-start.ps1`).

2. **_XAC_Base/** is shared infrastructure. Do not add project-specific content. Changes affect all consuming projects.

3. **_XAC_Config/** holds project CI configuration, cursor rules, and IaC. This is where you configure *how* XAC works for your project.

4. **_Config_Project/** holds project-specific operational content: Dockerfiles, deploy scripts, GCP setup, CI support scripts. This is content the developer creates for their specific project.

5. **.ci/config.ps1** is a thin wrapper that sources `_Config_Project/ci/config.ps1`. All config edits go in the canonical source.

6. **Root config files** (pytest.ini, ruff.toml, etc.) exist because tools require them at root. Their canonical sources are in `_Config_Project/tooling/`. See `ROOT_FILES_MANIFEST.md`.

7. **modules/<name>/tests/** for module unit tests. **integration_tests/** at root for cross-module/E2E.
