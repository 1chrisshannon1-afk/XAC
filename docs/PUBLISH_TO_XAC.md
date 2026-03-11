# Publishing _XAC to the XAC GitHub Repo

**Source of truth:** Local `_XAC` in the ContractorScope AI repo (or wherever _XAC is maintained).  
**Target:** [GitHub XAC](https://github.com/1chrisshannon1-afk/XAC) â€” the single source of truth for onboarding new companies to our infra.

## Repo name on GitHub

The repo is named **XAC** (renamed from SharedWorkflows). Update any bookmarks or scripts to use `XAC`.

## Sync _XAC to XAC (whenever _XAC changes)

XAC's `main` branch should mirror the contents of _XAC so that cloning XAC gives the same layout: `ci/`, `iac/`, `monitoring/`, `docs/`, `README.md`, `REFERENCE.md`.

### Option A: Clone XAC and copy _XAC into it

From the **parent** of your project repo (so XAC sits next to your project):

```powershell
# One-time: clone XAC
git clone https://github.com/1chrisshannon1-afk/XAC.git

# Sync: copy _XAC contents into XAC (overwrites XAC content with _XAC)
$projectRoot = "C:\path\to\ContractorScope AI"   # your repo root
$xacRoot     = "C:\path\to\XAC"                   # sibling XAC clone
robocopy "$projectRoot\_XAC" "$xacRoot" /E /XD .git /XF .git /MIR
# Or without MIR to avoid deleting files only in XAC (e.g. .github): use /E only and manually remove obsolete files.

# Then commit and push from XAC
cd $xacRoot
git add -A
git status
git commit -m "Sync from _XAC"
git push origin main
```

### Option B: Use the sync script

From ContractorScope AI repo root:

```powershell
.\repo_tooling\sync-xac-to-iac.ps1
```

Then `cd` into the clone path it prints and run `git add -A`, `git commit -m "Sync from _XAC"`, `git push origin main`. Set `$env:XAC_CLONE = "C:\path\to\XAC"` if your XAC clone is elsewhere.

### What gets published

| _XAC path        | XAC path (same)   |
|------------------|-------------------|
| `ci/`            | `ci/`             |
| `iac/`           | `iac/`            |
| `monitoring/`    | `monitoring/`     |
| `docs/`          | `docs/`           |
| `README.md`      | `README.md`       |
| `REFERENCE.md`   | `REFERENCE.md`    |

If XAC has a `.github/workflows/` with reusable workflows, either:

- Keep them only in the XAC repo and maintain them there, or  
- Add `.github/` under _XAC and include it in the sync so _XAC remains the single source of truth.

## After sync

- Consuming projects that use a sibling XAC clone: `git -C ../XAC pull` to get latest.
- New projects: clone XAC as a sibling and follow **docs/ONBOARDING.md** in _XAC (or in the XAC repo after sync).

**Last reviewed:** 2026-03-11

