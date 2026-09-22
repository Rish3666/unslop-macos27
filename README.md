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
Deletes Apple's on-device AI model files:
- `/System/Library/AssetsV2/com_apple_MobileAsset_UAF_FM_GenerativeModels`
- `/System/Library/AssetsV2/com_apple_MobileAsset_UAF_FM_Visual`
- `~/Library/Caches/com.apple.intelligence`
- `~/Library/Caches/com.apple.siri`
- Other system-level AI assets

### Phase 3: Clean System Caches
Removes AI-related caches:
- Siri analytics and caches
- Spotlight caches
- CloudKit caches
- TCC (Transparency, Consent, Control) caches

### Phase 4: Disable Background Services
- Kills running AI processes (siri, assistantd, SiriNCService, etc.)
- Unloads Siri launch agents

## System Integrity Protection (SIP)

Apple Intelligence model files are protected by SIP. The script will prompt you to disable SIP if needed:

1. Script detects SIP is enabled
2. Asks if you want to disable it
3. Provides step-by-step instructions for your Mac type (Intel or Apple Silicon)
4. Offers to restart into Recovery Mode automatically

After disabling SIP in Recovery Mode, restart and run the script again to delete the model files.

**Important:** Re-enable SIP when done: `sudo csrutil enable`

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

## Troubleshooting

**"Permission denied" errors**
```bash
sudo ./cleanup.sh
```

**Files not being removed**
- SIP may be enabled -- the script will guide you through disabling it
- Some files may be in use -- restart and try again

**Want to restore Apple Intelligence?**
1. System Settings > Apple Intelligence & Siri
2. Toggle Apple Intelligence back on
3. macOS re-downloads the models automatically

## Contributing

We welcome contributions from everyone! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE) -- use it, fork it, improve it. Just keep the license notice.

## Disclaimer

This script modifies system settings and deletes files. Use at your own risk. Always run with `--dry-run` first. We are not responsible for any data loss or system issues. Back up important data before running.
