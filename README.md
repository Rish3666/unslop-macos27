# AI Cleanup macOS

A comprehensive script to remove Apple Intelligence, Siri, and local AI model files from macOS to free up disk space and reduce idle CPU usage.

## Features

- **Disable Apple Intelligence** - Turn off Apple's AI features at the system level
- **Disable Siri** - Completely disable Siri and its background processes
- **Remove Local AI Models** - Clean up models from:
  - Ollama
  - LM Studio
  - Hugging Face
  - llama.cpp
  - ComfyUI
  - Whisper
  - Cursor AI
  - And more...
- **Clean System Caches** - Remove AI-related caches
- **Disable Background Services** - Stop AI-related daemon processes
- **Safe Operation** - Dry-run mode, confirmation prompts, error handling

## Quick Start

```bash
# Clone the repository
git clone https://github.com/Rish3666/unslop-macos27.git
cd unslop-macos27

# Make the script executable
chmod +x cleanup.sh

# Run with dry-run first (recommended)
./cleanup.sh --dry-run

# Run the actual cleanup
./cleanup.sh
```

## Usage

### Basic Commands

```bash
# Interactive mode (recommended)
./cleanup.sh

# Preview changes without making them
./cleanup.sh --dry-run

# Skip all confirmation prompts (dangerous!)
./cleanup.sh --force

# Verbose output
./cleanup.sh --verbose
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `--dry-run`, `-n` | Preview what would be deleted without making changes |
| `--force`, `-f` | Skip confirmation prompts (use with caution!) |
| `--verbose`, `-v` | Show detailed output during cleanup |
| `--help`, `-h` | Show help message |

## What Gets Cleaned

### Phase 1: Disable Apple Intelligence & Siri
- Disables Apple Intelligence via system preferences
- Turns off Siri completely
- Disables Siri Suggestions in Spotlight
- Disables "Hey Siri" listening
- Disables Siri on lock screen

### Phase 2: Remove Apple Intelligence Models
- `/System/Library/AssetsV2/com_apple_MobileAsset_UAF_FM_GenerativeModels`
- `/System/Library/AssetsV2/com_apple_MobileAsset_UAF_FM_Visual`
- `~/Library/Caches/com.apple.intelligence`
- `~/Library/Caches/com.apple.siri`
- And more system-level AI files

### Phase 3: Remove Local AI Models
Cleans up downloaded models from:
- **Ollama** - `~/.ollama/`
- **LM Studio** - `~/.cache/lm-studio/`, `~/.lm-studio/`
- **Hugging Face** - `~/.cache/huggingface/`
- **llama.cpp** - `~/.llama/`
- **ComfyUI** - `~/.cache/comfyui/`
- **Whisper** - `~/.cache/whisper/`
- **Cursor AI** - `~/Library/Application Support/Cursor`
- **GitHub Copilot** - VS Code extension caches
- Large model files (`.gguf`, `.safetensors`, `.mlx`)

### Phase 4: Clean System Caches
- Siri caches
- Spotlight caches
- AI-related system caches

### Phase 5: Disable Background Services
- Kills running AI processes (siri, assistantd, etc.)
- Unloads Siri launch agents

## Safety Features

### Dry-Run Mode
Always use `--dry-run` first to preview what the script will do:

```bash
./cleanup.sh --dry-run
```

### Confirmation Prompts
By default, the script asks for confirmation before each major action.

### Error Handling
The script continues even if some operations fail (e.g., SIP-protected files).

### System Integrity Protection (SIP)
Some Apple system files are protected by SIP. To remove these:

1. Restart your Mac
2. Hold `Cmd+R` during boot to enter Recovery Mode
3. Open Terminal from Utilities menu
4. Run: `csrutil disable`
5. Restart and run the cleanup script again
6. Re-enable SIP when done: `csrutil enable`

## Expected Results

- **Disk Space**: Typically 5-50 GB freed depending on installed AI tools
- **CPU Usage**: Reduced idle CPU from disabled Siri/AI background processes
- **Memory**: Lower RAM usage from stopped AI services

## Important Notes

1. **Restart Required** - Some changes require a restart to take full effect
2. **Updates May Re-enable** - Apple Intelligence may re-enable after macOS updates
3. **Backup First** - Consider backing up important data before running
4. **Irreversible** - Deleted model files cannot be recovered without re-downloading

## Troubleshooting

### "Permission denied" errors
```bash
# Run with sudo for system-level files
sudo ./cleanup.sh
```

### Files not being removed
- Check if SIP is enabled (see Safety Features section)
- Some files may be in use by running processes

### Want to restore Apple Intelligence?
1. Go to System Settings > Apple Intelligence & Siri
2. Toggle Apple Intelligence back on
3. macOS will re-download the required models

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### How to Contribute

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Ideas for Contributions

- [ ] Add support for more AI tools (Stable Diffusion, ComfyUI, etc.)
- [ ] Create a GUI version
- [ ] Add uninstall/reinstall functionality
- [ ] Improve SIP handling
- [ ] Add logging/output to file option
- [ ] Create Homebrew formula
- [ ] Add CI/CD testing

## Related Projects

- [apple-intelligence-remover](https://github.com/minagishl/apple-intelligence-remover) - Similar tool for Apple Intelligence specifically
- [LLM Cleaner](https://getllmcleaner.com/) - Commercial GUI tool for cleaning AI models

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

This script modifies system settings and deletes files. Use at your own risk. Always run with `--dry-run` first. The authors are not responsible for any data loss or system issues.

## Support

- **Issues**: [GitHub Issues](https://github.com/Rish3666/unslop-macos27/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Rish3666/unslop-macos27/discussions)

---

**If this script helped you, please give it a star on GitHub!**
