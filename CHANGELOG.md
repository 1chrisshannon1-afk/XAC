# Changelog

All notable changes to the XAC repo (CI, IaC, monitoring, docs) are documented here. Consumers sync only `_XAC/`; config (`_XAC_Config_*`) is never overwritten by sync. See [docs/VERSIONING_AND_CONFIG_UPDATE.md](docs/VERSIONING_AND_CONFIG_UPDATE.md).

Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/). Versioning is [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-03-11

### Added

- **VERSION** and **CHANGELOG.md** for semantic versioning. Sync can use `main` or a tag (e.g. `v1.0.0`).
- **docs/VERSIONING_AND_CONFIG_UPDATE.md** - strategy for config template updates and consumer adoption.
- **$CI_PYTHON_VERSION** and **$CI_NODE_VERSION** in config.ps1 (defaults 3.11 and 20). Local CI uses these; keep `.python-version` and `.nvmrc` in sync.
- **ci/templates/docker-compose.ci.yml**, **ci/templates/sync-xac-consumer.yml**, **scripts/onboard-xac.ps1**, **docs/ADDING_A_CONSUMER.md**, **ONBOARDING.md** (from prior sync).

### Changed

- Local CI core.ps1 reads `` from config instead of hardcoding 3.10/3.11.

### Notes for consumers

- After syncing, compare your `_XAC_Config_<Project>/` with `_XAC/ci/templates/config/` to adopt new optional files or variables. Config is never rebuilt by sync.

[1.0.0]: https://github.com/1chrisshannon1-afk/XAC/releases/tag/v1.0.0
