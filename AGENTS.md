# AGENTS.md — unslop-macos27

Guidance for AI agents (and humans) working on this repository.

**Repo:** https://github.com/Rish3666/unslop-macos27  
**Scope:** Remove Apple Intelligence / Siri system models and settings on macOS 27 only.  
**Out of scope:** Ollama, LM Studio, HuggingFace, and other third-party local-model cleanup.

---

## Project status (as of 2026-09-24)

| Item | Status |
|------|--------|
| Script + README + LICENSE + CONTRIBUTING | Pushed (`main`) |
| Phases 1–5 in `cleanup.sh` | Implemented (see below) |
| Test suite `tests/run_tests.sh` | Added (unit + dry-run smoke, stubbed sudo) |
| Manual deletion on test M4 Mac | Partial: ~15 GB → ~4.1 GB UAF remaining |
| `mount -uw /` | **Broken** on this machine (see issue #1) |
| Open issues | [#1](https://github.com/Rish3666/unslop-macos27/issues/1), [#2](https://github.com/Rish3666/unslop-macos27/issues/2), [#3](https://github.com/Rish3666/unslop-macos27/issues/3), [#7](https://github.com/Rish3666/unslop-macos27/issues/7), [#8](https://github.com/Rish3666/unslop-macos27/issues/8), [#9](https://github.com/Rish3666/unslop-macos27/issues/9) |

### Test machine facts (do not assume on other machines)

- macOS 27.0 (26A428), Darwin 27.0.0, Apple Silicon (M4 / T8132)
- SIP: **disabled**; Authenticated Root: **disabled**; FileVault: **off**
- Root `/` = `/dev/disk3s1s1` still mounted **apfs, sealed, read-only**
- System volume disk3s1 reports **Sealed: Broken**, mounts at `/Volumes/Macintosh HD 1`
- `AssetsV2` content is **firmlinked to the Data volume** (same inode as `/System/Volumes/Data/System/Library/AssetsV2`)
- Free space went from ~178 Gi → ~185 Gi during manual cleanup

---

## What the script does

`cleanup.sh` — interactive bash, flags: `--dry-run/-n`, `--force/-f`, `--verbose/-v`, `--help/-h`.

1. **Preflight + SIP handler** — detects SIP / Authenticated Root; offers Recovery instructions (`csrutil disable`, `csrutil authenticated-root disable`, FileVault decrypt via `diskutil apfs`); tries `mount -uw /`.
2. **Phase 1** — `defaults write` to disable Apple Intelligence, Siri, Hey Siri, lock-screen Siri, Spotlight Siri suggestions.
3. **Phase 2** — `sudo rm -rf` of hardcoded `AI_PATHS` (GenerativeModels, Visual, user caches) — **list is incomplete** (issue #4).
4. **Caches** — clears selected `~/Library/Caches/...` AI/Siri paths.
5. **Services** — kills known AI processes; unloads Siri launch agents.
6. **Final** — optional Spotlight reindex, DNS flush, summary with SIP/auth-root/root-writable diagnosis.

Helpers: `get_sip_status`, `get_auth_root_status`, `is_root_writable`, `try_mount_writable`, `print_recovery_instructions` (includes FileVault recovery steps).

---

## Critical filesystem findings (research)

### 1. Sealed snapshot vs writable System volume

- Live root is a **sealed APFS snapshot** (`disk3s1s1` → `/`), read-only.
- `csrutil` reports SIP + authenticated-root **disabled**, but `mount -uw /` still fails with **exit 66 / Permission denied** (issue #1).
- Underlying System volume disk3s1 is **Sealed: Broken** and can be mounted at `/Volumes/Macintosh HD 1`, but its `AssetsV2` is **empty (0B)**.

### 2. Firmlink — AI models live on Data

- `/System/Library/AssetsV2` ≡ `/System/Volumes/Data/System/Library/AssetsV2` (same `st_ino` / firmlink).
- Most top-level `rm -rf` of `com_apple_MobileAsset_UAF_*` **works** via the Data path even when `/` is read-only.
- Prefer targeting `/System/Volumes/Data/System/Library/AssetsV2/` when the root snapshot is RO.

### 3. `.AssetData` is the blocker (issue #2)

- Inside each `*.asset`, the `.AssetData/` subtree returns **EROFS (errno 30)** on create/unlink/rename.
- Parent `.asset` directory **is** writable (touch works).
- `.AssetData` is **not** a mount point; same device as parent; `lsof` often shows no handles.
- `chflags -R norestricted,noschg,nouchg` does **not** fix it.
- Some dirs had the **`restricted`** flag — clear with `sudo chflags -R norestricted ...` before `rm`.
- Processes that may hold assets (kill before retry): `assistantd`, `Siri Agent`, `mobileassetd`, `mds`, `mds_stores`, `suggestd`, `corespotlightd`, `parsecd`, `nsurlsessiond`, `privacyd`, `tccd`, etc.

### 4. Remaining UAF inventory (after partial cleanup)

| Directory | Approx size |
|-----------|-------------|
| `com_apple_MobileAsset_UAF_FM_CodeLM` | 2.2G |
| `com_apple_MobileAsset_UAF_Siri_Understanding` | 1.1G |
| `com_apple_MobileAsset_UAF_Photos_SpatialPhotosRelive` | 392M |
| `com_apple_MobileAsset_UAF_Siri_TextToSpeech` | 305M |
| `com_apple_MobileAsset_UAF_IF_Planner` | 258M |
| `com_apple_MobileAsset_UAF_Speech_AutomaticSpeechRecognition` | 183M |

Also seen earlier (may already be gone): `UAF_FM_GenerativeModels`, `UAF_FM_Visual`, `UAF_SummarizationKitConfiguration`, `UAF_Siri_UnderstandingASRHammer`.

### 5. Leftover diagnostics

- Test files to remove if present: `/System/Library/AssetsV2/.write_test`, `.write_test2` (issue #6).
- `cleanup.sh` header still has placeholder GitHub URL `yourusername/ai-cleanup-macos`.

---

## Open issues

| # | Title | State |
|---|--------|--------|
| 1 | `mount -uw /` fails Permission denied (66) despite SIP + auth-root disabled | open |
| 2 | `.AssetData` returns EROFS on writable Data volume | open |
| 3 | Partial deletion: 15 GB → ~4.1 GB, rest Resource busy / Directory not empty | open |
| 4 | `AI_PATHS` incomplete — misses most `UAF_*` dirs | **closed** (dynamic glob) |
| 5 | AssetsV2 firmlink: models on Data volume | **closed** (script targets Data path) |
| 6 | Leftover test files; stale header URL; phase labels | **closed** |
| 7 | EROFS follows `.AssetData` inode — `mv` does not unlock deletion | open |
| 8 | AssetsV2 `com.apple.rootless=MobileAsset`; may underlie `.AssetData` EROFS | open |
| 9 | SSV disabled but `mount -uw /` still exit 66 | open |

### Latest research (issue #7)

- `mv .AssetData /private/tmp/...` **succeeds**, but write/unlink **inside** the tree still EROFS → protection is **per-inode**, not path-based.
- **All** remaining `.AssetData` dirs under AssetsV2 are EROFS (including non-UAF like PKITrustStore).
- Parent `.asset/` is writable; `open(O_RDWR)` on files works; `unlink`/`truncate`/`mkdir` fail EROFS.
- `.AssetData` dir `nlink` is 4–29; files `nlink=1`.
- AssetsV2 has xattr `com.apple.rootless: MobileAsset`; stripping xattrs does not clear EROFS.
- Data volume has **no** APFS snapshots; sealed snapshot is only on System (`disk3s1s1`).
- Asset build xattrs say `26A5416b` while OS is `26A428` (possible build skew).

## Script fixes already landed

- Dynamic `com_apple_MobileAsset_UAF_*` scan via `collect_ai_model_paths()` / `assets_v2_roots()` (Data path first, deduped).
- Recursive flag clear via `find -x ... -exec chflags` — macOS `chflags` has no `-R` (older `chflags -R` silently no-op'd).
- Absolute `/sbin/mount -uw /` for remount; bogus disk-specific update variant removed; success judged by mount flags.
- `is_root_writable()` greps the `/` mount line for `read-only` (old `awk '{print $4}' == *rw*` grabbed `"(apfs,"` — the parenthesized option list — so it never worked in either direction).
- `get_dir_size()` takes first `du` line and falls back to 0 (defensive numeric parse).
- Root/path dedup by device:inode (`stat -Lf '%d:%i'`) in `assets_v2_roots()` / `collect_ai_model_paths()` — firmlinked `/System/Library/AssetsV2` and the Data-volume path were both scanned, double-counting every model (dry-run reported 63.76 GB; actual ≈ 32 GB).
- `set -e` guards: `ERRORS=$((ERRORS+1))`, `local` moved into functions, guarded volume-scan loop in `recovery-delete.sh`.
- Kill broader MobileAsset daemon set before delete.
- Phase labels 1–5; header URL; `.write_test*` cleanup; unknown CLI flags rejected; source guard for tests.
- Failure blurb points at EROFS / Recovery (issues #2/#3/#7) and `recovery-delete.sh`.

## Testing

```bash
./tests/run_tests.sh
```

Covers: `bash -n` on both scripts, `get_dir_size` (double-count regression),
`is_root_writable` (rw/read-only regression), `parse_args` flag handling,
firmlink dedup in `collect_ai_model_paths`, UI menu non-TTY fallback (`rc 2` /
`--force` all-select), `--no-ui` behavior, and an integration run of
`cleanup.sh --dry-run` with a stubbed `sudo` (exits 0, no system mutation).

## UI architecture (v2.2.0)

- `ui_active()` gates all interactive rendering: false for non-TTY stdout or
  `--no-ui`. Plain prompts remain functional in every phase.
- `ui_menu_multiselect` renders an indexed checklist and returns picks via the
  **global `UI_PICKS`** — never call it via `$(...)`: command substitution
  makes stdout a pipe and `ui_active()` would always be false on a real TTY.
  Return codes: 0 selected, 1 nothing selected, 2 UI inactive (fall back to
  plain `confirm`).
- `spinner_start/stop` animate scans; the spinner runs as a background job and
  writes only when `ui_active`. The INT/TERM trap stops it and restores the
  cursor (`\033[?25h`).
- `ui_progress_render` draws the deletion progress bar; callers must close the
  line before printing failures and re-render 100% after partial deletions.
- bash 3.2 + `set -u`: iterating a possibly-empty array needs a
  `${#arr[@]} -gt 0` guard (empty expansion is an unbound-variable error).
- Phase selection (`choose_phase_plan`) flips `RUN_PHASE_*` flags; `main`
  conditionally runs each phase.

## Recommended next steps for an agent

1. **Unblock `.AssetData` (issues #2 / #3 / #7)** — highest value.
   - Document/automate Recovery-mode `rm` on the Data volume mount.
   - Investigate why `com.apple.rootless: MobileAsset` + EROFS applies to `.AssetData` only.
   - Test whether deleting the sealed System snapshot (auth-root disabled) changes behavior.
   - Compare with a Mac that never enabled Apple Intelligence.
2. **Recovery helper** — add optional script/README path that prints exact Recovery `rm` lines for discovered UAF dirs.
3. **Re-test `mount -uw /`** after a clean reboot with auth-root disabled (still exit 66 as of last test).
4. **Security posture** — re-enable SIP + authenticated-root + FileVault when finished.
5. Do not claim full 15 GB until issue #7 is solved.

---

## Conventions

- Interactive confirmation before destructive actions; support `--dry-run`.
- No auto-restart; prompt the user to reboot manually.
- Scope stays Apple Intelligence/Siri only — reject PRs that turn this into a general cleaner without discussion.
- License: MIT. Issues/PRs: https://github.com/Rish3666/unslop-macos27/issues

## Do not

- Do not share or hardcode the user’s sudo password (it was exposed in chat — treat as compromised for local sudo; suggest changing it).
- Do not claim full 15 GB recovery in README until `.AssetData` EROFS is solved.
- Do not assume `mount -uw /` works just because `csrutil` says disabled — verify writability (`touch` on a known system path or check `mount` flags for `rw`).
