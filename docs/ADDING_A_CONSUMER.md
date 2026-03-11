# Adding a New Consumer to XAC

New companies get 100% set up with **one script** (other than editing their variables in the generated config folder).

## In the new company repo

### 1. Run the one command (from new project repo root)

One URL, one action. No copying scripts into the consumer repo.

```powershell
irm https://raw.githubusercontent.com/1chrisshannon1-afk/XAC/main/scripts/onboard-xac.ps1 | iex
```

The script prompts for: project name, config folder name, GCP project ID, GitHub org/repo, region. It then:

- Downloads `.github/workflows/sync-xac.yml` from XAC and writes it to your repo (so GitHub Actions can run Sync _XAC)
- Creates `.ci/config.ps1` (thin wrapper that sources your _XAC_Config_* folder)
- Creates `local_ci.ps1` at root (stub that calls _XAC/ci/local_ci.ps1 — all logic stays in _XAC)
- Creates `_XAC_Config_<Project>/` with `ci/`, `cursor/`, `docker/`, `iac/`, `cicd/`, `briefs/` and all template files

### 2. Edit variables in the config folder

Edit only the generated config folder (no other setup):

- **ci/config.ps1** — paths, test sets, GCP key, Node jobs
- **iac/** — Terraform services, secrets, `terraform.tfvars` (copy from `.example`)
- **cursor/cursorrules.project**, **cursorignore.project** — project rules and ignores
- **ci/deploy-staging-shared.yml** — service names, dockerfile path, test matrices if needed
- **docker/** — add your Dockerfiles; point root `docker-compose` at them

### 3. Add _XAC to the repo

Either run **Actions -> Sync _XAC -> Run workflow** (it will add _XAC and open a PR), or:

```bash
git subtree add --prefix=_XAC https://github.com/1chrisshannon1-afk/XAC.git main --squash -m "chore: add _XAC as git subtree"
git push
```

### 4. Assemble .cursorrules and .cursorignore

Follow _XAC/cursor/README.md to combine _XAC base + your config folder into root `.cursorrules` and `.cursorignore`.

---

## In the XAC repo (register the consumer)

1. Add the new repo to **docs/CONSUMERS.json**.
2. Ensure **CONSUMER_DISPATCH_TOKEN** has access to the new repo (PAT repository access).
3. After that, pushes to XAC main will trigger sync-xac.yml in the new repo and open a sync PR.

