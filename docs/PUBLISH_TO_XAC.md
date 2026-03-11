# Publishing _XAC_Base to the XAC GitHub Repo

**Source of truth:** Local `_XAC_Base` in your project repo (or wherever _XAC_Base is maintained).  
**Target:** [GitHub XAC](https://github.com/1chrisshannon1-afk/XAC) — the single source of truth for onboarding new companies to our infra.

## Repo name on GitHub

The repo is named **XAC** (renamed from SharedWorkflows). Update any bookmarks or scripts to use `XAC`.

## Sync _XAC_Base to XAC (whenever _XAC_Base changes)

XAC's `main` branch should mirror the contents of _XAC_Base so that cloning XAC gives the same layout: `ci/`, `iac/`, `monitoring/`, `docs/`, `README.md`, `REFERENCE.md`.

### Option A: Clone XAC and copy _XAC_Base into it

From the **parent** of your project repo (so XAC sits next to your project):

```powershell
# One-time: clone XAC
git clone https://github.com/1chrisshannon1-afk/XAC.git

# Sync: copy _XAC_Base contents into XAC (overwrites XAC content with _XAC_Base)
$projectRoot = "C:\path\to\your-project"   # your repo root
$xacRoot     = "C:\path\to\XAC"            # sibling XAC clone
robocopy "$projectRoot\_XAC_Base" "$xacRoot" /E /XD .git /XF .git /MIR
# Or without MIR to avoid deleting files only in XAC (e.g. .github): use /E only and manually remove obsolete files.

# Then commit and push from XAC
cd $xacRoot
git add -A
git status
git commit -m "Sync from _XAC_Base"
git push origin main
```

### Option B: Use the sync script

From your project repo root:

```powershell
.\repo_tooling\sync-xac-to-iac.ps1
```

Then `cd` into the clone path it prints and run `git add -A`, `git commit -m "Sync from _XAC_Base"`, `git push origin main`. Set `$env:XAC_CLONE = "C:\path\to\XAC"` if your XAC clone is elsewhere.

### What gets published

| _XAC_Base path   | XAC path (same)   |
|------------------|-------------------|
| `ci/`            | `ci/`             |
| `iac/`           | `iac/`            |
| `monitoring/`    | `monitoring/`     |
| `docs/`          | `docs/`           |
| `README.md`      | `README.md`       |
| `REFERENCE.md`   | `REFERENCE.md`    |

If XAC has a `.github/workflows/` with reusable workflows, either:

- Keep them only in the XAC repo and maintain them there, or  
- Add `.github/` under _XAC_Base and include it in the sync so _XAC_Base remains the single source of truth.

## After sync

- Consuming projects that use a sibling XAC clone: `git -C ../XAC pull` to get latest.
- New projects: clone XAC as a sibling and follow **docs/ONBOARDING.md** in _XAC_Base (or in the XAC repo after sync).

**Last reviewed:** 2026-03-11
