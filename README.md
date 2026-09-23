# Unslop macOS 27

> Disable Apple Intelligence and Siri, remove their model files, and stop idle CPU drain on macOS 27.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-27%2B-blue.svg)](https://www.apple.com/macos/)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-orange.svg)](cleanup.sh)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

---

## Why This Exists

macOS 27 ships with Apple Intelligence enabled by default. The on-device AI models consume **5-15 GB** of storage, and background Siri/Apple Intelligence processes eat CPU cycles even when idle. This script removes them.

- **Free 5-15 GB** of storage by removing Apple Intelligence model files
- **Stop idle CPU usage** from Siri and Apple Intelligence daemons
- **100% local** -- no data leaves your machine, no accounts required

## Features

| Feature | What It Does |
|---------|--------------|
| Disable Apple Intelligence | Turns off Apple's AI features at the system level |
| Disable Siri | Completely removes Siri and its background processes |
| Remove Apple Intelligence Models | Deletes 5-15 GB of on-device AI models |
| Clean System Caches | Removes AI-related caches from ~/Library |
| Disable Background Services | Kills AI daemons and unloads launch agents |
| SIP Integration | Guides you through disabling SIP if needed |
| Dry-Run Mode | Preview everything before making changes |
| Confirmation Prompts | Never deletes anything without your explicit approval |

## Installation

```bash
git clone https://github.com/Rish3666/unslop-macos27.git
cd unslop-macos27
chmod +x cleanup.sh
```

## Usage

```bash
# Always preview first -- this shows what WOULD be deleted
./cleanup.sh --dry-run

# Run the interactive cleanup (asks before each action)
./cleanup.sh

# Full auto mode (skips confirmations -- use with caution)
./cleanup.sh --force
```

### Command Line Options

| Flag | Description |
|------|-------------|
| `--dry-run`, `-n` | Preview changes without modifying anything |
| `--force`, `-f` | Skip all confirmation prompts |
| `--verbose`, `-v` | Show detailed output |
| `--help`, `-h` | Show help message |

## What Gets Cleaned

### Phase 1: Disable Apple Intelligence & Siri
Disables via `defaults write` commands:
- Apple Intelligence toggle
- Siri completely
- Siri Suggestions in Spotlight
- "Hey Siri" voice trigger
- Siri on lock screen

### Phase 2: Remove Apple Intelligence Models
Dynamically finds all `com_apple_MobileAsset_UAF_*` directories under every AssetsV2 root (Data volume first), plus user caches:
- `/System/Volumes/Data/System/Library/AssetsV2/com_apple_MobileAsset_UAF_*`
- `/System/Library/AssetsV2/com_apple_MobileAsset_UAF_*`
- `~/Library/Caches/com.apple.intelligence`
- `~/Library/Caches/com.apple.siri`
- Clears `restricted` / `schg` flags before `rm`

### Phase 3: Clean System Caches
Removes AI-related caches:
- Siri analytics and caches
- Spotlight caches
- CloudKit caches
- TCC (Transparency, Consent, Control) caches

### Phase 4: Disable Background Services
- Kills running AI processes (siri, assistantd, SiriNCService, etc.)
- Unloads Siri launch agents

## System Integrity Protection (SIP) & Recovery

On macOS 27, Apple Intelligence assets live under `AssetsV2`, which is **firmlinked to the Data volume** — not only on the sealed System snapshot. The script prefers:

```text
/System/Volumes/Data/System/Library/AssetsV2/
```

If SIP and Authenticated Root are enabled, disable them in Recovery first:

1. Script detects SIP and/or Authenticated Root status
2. Asks if you want guided instructions
3. Provides step-by-step Recovery Mode steps for your Mac type (Intel or Apple Silicon)
4. You restart manually into Recovery Mode

### In Recovery Terminal

```bash
csrutil disable
csrutil authenticated-root disable
reboot
```

### If authenticated-root fails: "FileVault must be disabled"

`fdesetup` is not available in Recovery. Use APFS tools instead:

```bash
# 1. List volumes (note System e.g. disk3s1, Data e.g. disk3s5)
diskutil apfs list

# 2. Get local volume owner UUID
diskutil apfs listcryptousers disk3s1

# 3. Unlock System and Data volumes
diskutil apfs unlockVolume disk3s1 -user <UUID>
diskutil apfs unlockVolume disk3s5 -user <UUID>

# 4. Decrypt Data volume
diskutil apfs decryptVolume disk3s5 -user <UUID>

# 5. Verify FileVault: No, then disable authenticated-root
diskutil apfs list
csrutil authenticated-root disable

# 6. Restart
reboot
```

After reboot, run `./cleanup.sh` again. It will attempt to remount the system volume writable and delete the model files.

### Stuck `.AssetData` (EROFS) — known limitation

Some asset subtrees named `.AssetData` return **Read-only file system** even when:

- SIP and Authenticated Root are both disabled
- The Data volume is mounted read-write
- The parent `.asset/` directory is writable
- The tree is `mv`'d elsewhere (EROFS follows the inode)

In that case, delete from **Recovery Terminal** (Data volume mounted), for example:

```bash
# Find your Data volume mount in Recovery (diskutil list / ls /Volumes)
rm -rf /Volumes/Data/System/Library/AssetsV2/com_apple_MobileAsset_UAF_*
```

Track progress in issues [#1](https://github.com/Rish3666/unslop-macos27/issues/1), [#2](https://github.com/Rish3666/unslop-macos27/issues/2), [#7](https://github.com/Rish3666/unslop-macos27/issues/7).

**Important:** Re-enable protections when done (boot back to Recovery):
```bash
csrutil enable
csrutil authenticated-root enable
```
Then turn FileVault back on in System Settings > Privacy & Security.

## Safety

**This script will never delete anything without asking first.**

- Always run `--dry-run` first to preview changes
- Confirmation prompts before every deletion
- Error handling -- continues gracefully if a file can't be removed
- SIP-protected files are detected and handled with clear instructions

## Expected Results

| Metric | Before | After |
|--------|--------|-------|
| Disk Space | X GB free | +5-15 GB free |
| Idle CPU | Siri/AI daemons running | Reduced background activity |
| RAM | AI services loaded | Lower memory usage |

> **Known limitation:** some `.AssetData` subtrees inside the assets return
> `EROFS (Read-only file system)` even with SIP + Authenticated Root disabled
> (issues [#2](https://github.com/Rish3666/unslop-macos27/issues/2),
> [#7](https://github.com/Rish3666/unslop-macos27/issues/7)). On affected
> setups a portion of the models can only be removed from Recovery Terminal —
> use `./recovery-delete.sh` to print the exact commands. Do not expect the
> full 5-15 GB until that issue is solved.

## Troubleshooting

**"Permission denied" errors**
```bash
sudo ./cleanup.sh
```

**Files not being removed**
- SIP may be enabled -- the script will guide you through disabling it
- Authenticated Root may be enabled -- system volume is sealed; disable in Recovery
- FileVault may block authenticated-root -- decrypt temporarily in Recovery (see SIP section above)
- **`.AssetData` EROFS**: some model subtrees stay read-only even with SIP off (see SIP section / issues #2, #7) -- delete those from Recovery
- After fixes, re-run `./cleanup.sh` (it will try to remount the volume writable)

**Want to restore Apple Intelligence?**
1. System Settings > Apple Intelligence & Siri
2. Toggle Apple Intelligence back on
3. macOS re-downloads the models automatically

## Development & Testing

A self-contained test suite lives in `tests/`. It only exercises `--dry-run`
and stubs `sudo`, so it never modifies your system:

```bash
./tests/run_tests.sh
```

## Contributing

We welcome contributions from everyone! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE) -- use it, fork it, improve it. Just keep the license notice.

## Disclaimer

This script modifies system settings and deletes files. Use at your own risk. Always run with `--dry-run` first. We are not responsible for any data loss or system issues. Back up important data before running.
