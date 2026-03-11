# XAC Versioning and Config Update Strategy

**Goal:** When _XAC syncs (e.g. every Monday), consumer config stays intact. When the platform's config structure or contract changes, consumers have a clear way to adopt changes without losing their settings.

---

## 1. What Sync Does Today

- **Sync updates only `_XAC/`** via `git subtree pull`. The consumer's **`_XAC_Config_<Project>/` is never touched** by sync.
- **Config is consumer-owned.** It is created once by `onboard-xac.ps1` and then edited by the team. Sync does not overwrite or "rebuild" it.

So: **weekly Monday sync does not require rebuilding config.** Config is not rebuilt every week.

---

## 2. The Problem: When XAC Changes a Ton

If XAC's **contract** or **structure** changes (e.g. new required variables in `config.ps1`, new folders, renamed keys, new template files), then:

- **New consumers** get the new structure from the latest `onboard-xac.ps1`.
- **Existing consumers** still have the old structure. They are only updated if we give them a way to:
  - see what's new, and
  - optionally pull those changes into their config without wiping their custom values.

So we need:

1. **Versioning** for XAC (so consumers can choose when to upgrade).
2. **Config template updates** that don't overwrite consumer data by default; the user decides whether (and when) to update.

---

## 3. Versioning Plan

### 3.1 XAC repo

- **Semantic versioning:** Use tags like `v1.0.0`, `v1.1.0`, `v2.0.0` in the XAC repo.
  - **MAJOR:** Breaking changes (e.g. config schema change, required new variables, folder renames).
  - **MINOR:** New optional features, new templates, new files that are additive.
  - **PATCH:** Bug fixes, docs, non-breaking tweaks in _XAC only.
- **Default sync ref:** Consumers can sync to `main` (latest) or to a tag (e.g. `v1.2.0`) for stability.
- **Changelog:** Maintain `_XAC/CHANGELOG.md` (or `docs/CHANGELOG.md`) describing what changed per version, especially config and contract changes.

### 3.2 Consumer sync workflow (e.g. every Monday)

- **Trigger:** Scheduled (e.g. Monday 00:00 UTC) or on-demand. Runs `sync-xac.yml` with a chosen ref (e.g. `main` or `v1.2.0`).
- **Behavior:**
  1. `git subtree pull` updates **only `_XAC/`**.
  2. Open a PR with the diff in `_XAC/` (no changes to `_XAC_Config_*`).
- **Result:** Platform code and shared logic update; **config files are not rebuilt.** Team reviews the PR and merges when ready.

### 3.3 Pinning to a version (optional)

- In `sync-xac.yml`, the default `xac_ref` can stay `main`, or the consumer can set it to a tag (e.g. `v1.1.0`) so Monday sync pulls that tag.
- Documentation: "To stay on a specific XAC version, run Sync _XAC with `xac_ref=v1.1.0`."

---

## 4. Config Template Updates: "Blank" Templates and User Choice

Principle: **Sync delivers up-to-date "blank" config templates inside _XAC; the consumer decides whether to update their live config from those templates.**

### 4.1 Where templates live (in XAC)

- Keep **canonical config templates** in the XAC repo, e.g.:
  - **`_XAC/ci/templates/config/`** (or `_XAC/config-templates/`)
  - with the same layout as `_XAC_Config_<Project>/`: `ci/config.ps1`, `ci/deploy-staging-shared.yml`, `cursor/`, `docker/`, `iac/`, `cicd/`, `briefs/` as needed.
- These are **reference templates** (with placeholders like `{{XAC_CONFIG_NAME}}`, `{{GCP_PROJECT}}`). They are updated in XAC when the platform's contract or structure changes.
- **Sync updates `_XAC/`**, so **templates inside _XAC are updated** on every sync. No separate "config sync" step.

### 4.2 Consumer side: no auto-overwrite of config

- **`_XAC_Config_<Project>/`** remains **fully consumer-owned**. No workflow or script should overwrite it by default.
- After sync, the consumer has:
  - **Updated _XAC/** (including `_XAC/ci/templates/config/`).
  - **Unchanged _XAC_Config_<Project>/** (their current config).

### 4.3 How the consumer adopts new structure (user decides)

**Option A — Manual diff and copy (recommended baseline)**  
- Compare `_XAC/ci/templates/config/` with `_XAC_Config_<Project>/`.
- Manually add new files, new variables, or new sections. Don't overwrite existing values.
- Document in XAC: "After syncing, check CHANGELOG and compare your config with `_XAC/ci/templates/config/`."

**Option B — Optional "config upgrade" script (future)**  
- Script in XAC, e.g. `_XAC/scripts/upgrade-config.ps1`, run by the consumer from repo root.
- Behavior:
  - Reads **template** from `_XAC/ci/templates/config/`.
  - Compares with **existing** `_XAC_Config_<Project>/`.
  - **Only adds** missing files or missing keys; **does not** overwrite existing values (or only overwrites after explicit prompt).
- User runs it only when they want to pull in new structure (e.g. after reading CHANGELOG).

**Option C — "Blank" sync into a separate folder**  
- Sync could also write "blank" config into something like `_XAC_Config_<Project>_.templates/` (or keep only under _XAC).  
- Consumer then diffs that vs `_XAC_Config_<Project>/` and merges by hand or via upgrade script.  
- Same idea: templates in _XAC; no overwrite of _XAC_Config_* by sync.

Recommendation: **Implement Option A in docs and CHANGELOG; add Option B (upgrade script) later if needed.**

---

## 5. When Config and Base Structure Change "a Ton"

### 5.1 Breaking changes (MAJOR)

- Bump XAC to a new MAJOR version (e.g. `v2.0.0`).
- In CHANGELOG:
  - List breaking changes (e.g. "`config.ps1` must define `$CI_NEW_REQUIRED_VAR`", "`gcp_cicd/` moved under `ci/`").
  - Provide a short **migration guide** (manual steps or link to upgrade script).
- Consumers can:
  - Stay on the previous major (e.g. sync to `v1.x` tag) until they're ready, or
  - Sync to `v2.0.0`, then follow the migration guide and optionally run the upgrade script.

### 5.2 Additive changes (MINOR)

- New optional files or variables: document in CHANGELOG; templates in _XAC get the new files.
- Consumers sync as usual; they can add the new files/keys when they want (manual or upgrade script).

### 5.3 Summary table

| Scenario                         | Who updates | How |
|----------------------------------|-------------|-----|
| Weekly Monday sync               | _XAC only   | `git subtree pull` -> PR -> merge. Config unchanged. |
| New optional config file        | Consumer    | After sync, copy from `_XAC/ci/templates/config/` or run upgrade script. |
| New required variable (breaking) | Consumer    | After upgrading XAC (tag or main), add variable per CHANGELOG/migration guide; optionally upgrade script. |
| Big restructure (e.g. folder rename) | Consumer | Follow MAJOR version migration guide; merge or re-create config from new templates. |

---

## 6. Implementable Next Steps

1. **XAC repo**
   - Add `_XAC/CHANGELOG.md` (or under `docs/`).
   - Introduce a versioned layout under **`_XAC/ci/templates/config/`** that mirrors `_XAC_Config_<Project>/` and is used by onboarding and by docs.
   - Tag XAC with a starting version (e.g. `v1.0.0`).
   - Document in ADDING_A_CONSUMER / ONBOARDING: "Sync updates only _XAC. Config is never rebuilt by sync."

2. **Consumer repo**
   - In XAC_SYNC.md (or equivalent), add a short "Versioning" section: sync can use `main` or a tag; config is not touched; to adopt new config structure, compare with `_XAC/ci/templates/config/` and see CHANGELOG.

3. **Scheduled Monday sync**
   - In XAC, add a workflow (e.g. `notify-consumers.yml`) that runs on a schedule (e.g. Monday 00:00 UTC) and triggers `sync-xac.yml` in each consumer with `xac_ref=main` (or a configurable ref). Consumers get a PR; they merge when ready. No config rebuild.

4. **Optional later**
   - Add `_XAC/scripts/upgrade-config.ps1` that merges missing keys/files from templates into existing `_XAC_Config_*` without overwriting existing values, and document it in CHANGELOG and CONSUMER docs.

---

## 7. Direct Answers to Your Questions

- **If it syncs every Monday, what happens to their config files?**  
  Nothing. Sync only updates `_XAC/`. Config is not touched.

- **Do they need to be rebuilt every week?**  
  No. Rebuild is only needed when the consumer chooses to adopt a new config structure (e.g. after a MAJOR or when they want new optional files).

- **What if the config and base structure changes a ton?**  
  Use MAJOR version + CHANGELOG + migration guide. Consumers either stay on an older XAC version or upgrade and follow the guide (and optionally an upgrade script). Templates in _XAC provide the "blank" target structure.

- **Should it sync blank config files and folders, then the user decides whether to update?**  
  Yes. Sync updates _XAC, which includes the **blank/reference templates** (e.g. under `_XAC/ci/templates/config/`). The **live** config stays in `_XAC_Config_<Project>/` and is **not** overwritten. The user decides when to pull new structure (manual diff/copy or optional upgrade script). No automatic overwrite of consumer config.
