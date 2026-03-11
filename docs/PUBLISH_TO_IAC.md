# Publishing _XAC to the IAC GitHub Repo

**Source of truth:** Local `_XAC` in the ContractorScope AI repo (or wherever _XAC is maintained).  
**Target:** [GitHub IAC](https://github.com/1chrisshannon1-afk/IAC) — the single source of truth for onboarding new companies to our infra.

## Rename the repo on GitHub (one-time)

1. Open **Settings** for [SharedWorkflows](https://github.com/1chrisshannon1-afk/SharedWorkflows).
2. Under **Repository name**, change `SharedWorkflows` to **IAC** and save.
3. GitHub will redirect old URLs to the new name. Update any bookmarks or scripts to use `IAC`.

## Sync _XAC to IAC (whenever _XAC changes)

IAC’s `main` branch should mirror the contents of _XAC so that cloning IAC gives the same layout: `ci/`, `iac/`, `monitoring/`, `docs/`, `README.md`, `REFERENCE.md`.

### Option A: Clone IAC and copy _XAC into it

From the **parent** of your project repo (so IAC sits next to your project):

```powershell
# One-time: clone IAC (after renaming the repo on GitHub)
git clone https://github.com/1chrisshannon1-afk/IAC.git

# Sync: copy _XAC contents into IAC (overwrites IAC content with _XAC)
$projectRoot = "C:\path\to\ContractorScope AI"   # your repo root
$iacRoot     = "C:\path\to\IAC"                   # sibling IAC clone
robocopy "$projectRoot\_XAC" "$iacRoot" /E /XD .git /XF .git /MIR
# Or without MIR to avoid deleting files only in IAC (e.g. .github): use /E only and manually remove obsolete files.

# Then commit and push from IAC
cd $iacRoot
git add -A
git status
git commit -m "Sync from _XAC"
git push origin main
```

### Option B: Use a sync script (optional)

You can add a script at repo root, e.g. `scripts/sync-xac-to-iac.ps1`, that:

1. Resolves the IAC clone path (sibling `IAC` or env `IAC_PATH`).
2. Runs `robocopy` or `xcopy` to copy `_XAC\*` into the IAC clone (excluding `.git`).
3. Prints instructions to `cd` into IAC and `git add / commit / push`.

### What gets published

| _XAC path        | IAC path (same)   |
|------------------|-------------------|
| `ci/`            | `ci/`             |
| `iac/`           | `iac/`            |
| `monitoring/`    | `monitoring/`     |
| `docs/`          | `docs/`           |
| `README.md`      | `README.md`       |
| `REFERENCE.md`   | `REFERENCE.md`    |

If IAC has a `.github/workflows/` with reusable workflows, either:

- Keep them only in the IAC repo and maintain them there, or  
- Add `.github/` under _XAC and include it in the sync so _XAC remains the single source of truth.

## After sync

- Consuming projects that use a sibling IAC clone: `git -C ../IAC pull` to get latest.
- New projects: clone IAC as a sibling and follow **docs/ONBOARDING.md** in _XAC (or in the IAC repo after sync).

**Last reviewed:** 2026-03-11
