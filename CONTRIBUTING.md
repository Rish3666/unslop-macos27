# Contributing to unslop-macos27

Thanks for your interest in contributing! This project is open source and welcomes contributions from everyone.

## How to Contribute

### Reporting Bugs

1. Check [existing issues](https://github.com/Rish3666/unslop-macos27/issues) first
2. If none exist, open a new issue with:
   - macOS version (`sw_vers`)
   - Script output (use `--verbose` flag)
   - Steps to reproduce
   - Expected vs actual behavior

### Suggesting Features

Open an issue with the `enhancement` label and describe:
- What the feature does
- Why it's useful
- How it should work

### Submitting Code

1. **Fork** the repository
2. **Clone** your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/unslop-macos27.git
   ```
3. **Create a branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```
4. **Make your changes**
5. **Test thoroughly** (see Testing section)
6. **Commit** with a clear message:
   ```bash
   git commit -m "Add: description of what you added"
   ```
7. **Push** and open a Pull Request

### Commit Messages

Use these prefixes:
- `Add:` for new features
- `Fix:` for bug fixes
- `Update:` for improvements to existing features
- `Remove:` for removing code/features
- `Docs:` for documentation changes

Examples:
```
Add: support for Jan AI models
Fix: Ollama model detection on Apple Silicon
Update: improve error handling for SIP-protected files
Docs: add troubleshooting section
```

## Development Setup

### Prerequisites
- macOS 27 or later
- Bash 3.2+ (comes with macOS)
- Git

### Testing

**Always test with --dry-run first:**
```bash
./cleanup.sh --dry-run
```

**Test on a clean system or VM if possible.**

**Manual testing checklist:**
- [ ] Script runs without errors
- [ ] --dry-run shows correct output
- [ ] Confirmation prompts work
- [ ] All phases execute correctly
- [ ] Error handling works for permission-denied cases
- [ ] Output is clear and readable

### Code Style

- Use 4 spaces for indentation (not tabs)
- Keep lines under 80 characters where possible
- Use meaningful variable names
- Comment complex logic
- Follow existing code patterns

## Ideas for Contributions

### High Priority
- [ ] Add support for Jan AI
- [ ] Add support for GPT4All
- [ ] Add support for text-generation-webui
- [ ] Add logging to file (`--log` flag)
- [ ] Add backup/restore functionality

### Medium Priority
- [ ] Create a GUI version (SwiftUI preferred)
- [ ] Add Homebrew formula
- [ ] Add uninstall/reinstall for specific tools
- [ ] Improve SIP detection and handling
- [ ] Add CI/CD testing with GitHub Actions

### Low Priority
- [ ] Add completion script for bash/zsh
- [ ] Add man page
- [ ] Translate to other languages
- [ ] Add colorblind-friendly output mode

## Code of Conduct

Be respectful and constructive. We're here to help each other build better tools.

## Questions?

Open an issue or start a discussion on GitHub.
