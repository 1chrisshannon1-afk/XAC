# XAC — Onboard a new consumer (one command)

**Use this when you are adding XAC to a new project repository.** Everything is done from the **new project’s repo root**.

---

## The command (run from new project repo root)

Open **PowerShell**, `cd` to the **root of the repository** that will consume XAC (e.g. `C:\repos\MyNewApp`), then run:

```powershell
irm https://raw.githubusercontent.com/1chrisshannon1-afk/XAC/main/scripts/onboard-xac.ps1 | iex
```

- **`irm`** = Invoke-RestMethod (PowerShell). This **downloads** the script from the XAC repo.
- **`| iex`** = pipes the script into Invoke-Expression so it **runs** in your session.
- No need to clone XAC or copy scripts into your repo; this one line does it.

---

## What the script does

1. **Prompts you** for: project name, config folder name (e.g. `_XAC_Config`), GCP project ID, GitHub org/repo, region.
2. **Creates in your repo:**
   - **`.github/workflows/sync-xac.yml`** — so GitHub Actions can sync **`_XAC_Base/`** from the XAC repo.
   - **`.ci/config.ps1`** — thin wrapper that sources your config folder (e.g. **`_XAC_Config/ci/config.ps1`**).
   - **`_XAC_Config/`** (or your chosen name) with **ci/** , **cursor/** , **iac/** and **CUSTOMIZE.md** (step-by-step checklist).

---

## What you do next

1. **Edit variables** in the new config folder per **CUSTOMIZE.md** (paths, GCP project, test sets, etc.).
2. **Add _XAC_Base** to the repo:
   - **Option A:** Run **Actions → Sync _XAC_Base → Run workflow** (workflow will add the subtree and open a PR), or  
   - **Option B:** Locally: `git subtree add --prefix=_XAC_Base https://github.com/1chrisshannon1-afk/XAC.git main --squash -m "chore: add _XAC_Base as git subtree"`, then push.
3. **Assemble Cursor files** (see **cursor/README.md** in your config folder) so root **`.cursorrules`** and **`.cursorignore`** are built from _XAC_Base + your config.

Full step-by-step: **docs/ADDING_A_CONSUMER.md** (in the XAC repo).
