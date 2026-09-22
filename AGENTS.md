# AGENTS.md — unslop-macos27

Guidance for AI agents (and humans) working on this repository.

**Repo:** https://github.com/Rish3666/unslop-macos27  
**Scope:** Remove Apple Intelligence / Siri system models and settings on macOS 27 only.  
**Out of scope:** Ollama, LM Studio, HuggingFace, and other third-party local-model cleanup.

---

## Project status (as of 2026-09-23)

| Item | Status |
|------|--------|
| Script + README + LICENSE + CONTRIBUTING | Pushed (`main`, latest `08266a1`) |
| Phases 1–4 in `cleanup.sh` | Implemented (see below) |
| Manual deletion on test M4 Mac | Partial: ~15 GB → ~4.1 GB UAF remaining |
| `mount -uw /` | **Broken** on this machine (see issue #1) |
| Open issues | [#1](https://github.com/Rish3666/unslop-macos27/issues/1)–[#6](https://github.com/Rish3666/unslop-macos27/issues/6) |

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

## Open issues (file these first when continuing work)

| # | Title |
|---|--------|
| 1 | `mount -uw /` fails Permission denied (66) despite SIP + auth-root disabled |
| 2 | `.AssetData` returns EROFS on writable Data volume |
| 3 | Partial deletion: 15 GB → 4.1 GB, rest Resource busy / Directory not empty |
| 4 | `AI_PATHS` incomplete — misses most `UAF_*` dirs |
| 5 | AssetsV2 firmlink: models on Data volume, not System snapshot |
| 6 | Remove leftover test files; fix stale header URL; phase label cleanup |

---

## Recommended next steps for an agent

1. **Unblock `.AssetData` (issues #2 / #3)** — highest value. Ideas to try:
   - Boot Recovery → delete assets while Data volume is unmounted from the running system (no firmlink/NFS-style locks).
   - After a clean reboot with auth-root disabled, retest `mount -uw /` and full-tree delete.
   - Investigate APFS “sealed / restricted / rootless” xattrs and MobileAsset-specific directory flags more deeply.
   - Confirm whether `nsurlsessiond` / MobileAsset daemons recreate or pin `.AssetData` immediately after delete.
2. **Fix script** — dynamic glob of `com_apple_MobileAsset_UAF_*` on the Data path (issues #4 / #5); better error messages distinguishing snapshot-RO vs EROFS.
3. **Hygiene** — delete `.write_test*`; fix header URL; align phase numbers in `cleanup.sh` (issue #6).
4. **Docs** — update README SIP section with firmlink + `.AssetData` limitations and real macOS 27 findings.
5. **Security posture** — remind user to re-enable SIP + authenticated-root + FileVault when finished.

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
