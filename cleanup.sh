#!/bin/bash
# =============================================================================
# macOS AI & Siri Cleanup Script
# =============================================================================
# Removes Apple Intelligence, Siri, and local AI model files to free up
# disk space and reduce idle CPU usage on macOS.
#
# Usage:
#   chmod +x cleanup.sh
#   ./cleanup.sh              # Interactive mode (recommended)
#   ./cleanup.sh --dry-run    # Preview what would be deleted
#   ./cleanup.sh --force      # Skip confirmations (dangerous!)
#
# IMPORTANT: This script modifies system settings and deletes files.
#            Always use --dry-run first to preview changes.
#
# GitHub: https://github.com/yourusername/ai-cleanup-macos
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Flags
DRY_RUN=false
FORCE=false
VERBOSE=false

# Counters
SPACE_FREED=0
ITEMS_REMOVED=0
ERRORS=0

# Parse arguments
for arg in "$@"; do
    case $arg in
        --dry-run|-n)
            DRY_RUN=true
            ;;
        --force|-f)
            FORCE=true
            ;;
        --verbose|-v)
            VERBOSE=true
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run, -n    Preview changes without making them"
            echo "  --force, -f      Skip confirmation prompts"
            echo "  --verbose, -v    Show detailed output"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
    esac
done

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║          macOS AI & Siri Cleanup Script                    ║${NC}"
    echo -e "${BOLD}${CYAN}║   Free space • Disable AI • Remove local models           ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_info() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    ((ERRORS++))
}

log_action() {
    if $DRY_RUN; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would: $1"
    else
        echo -e "${GREEN}[ACTION]${NC} $1"
    fi
}

get_dir_size() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        du -sk "$dir" 2>/dev/null | cut -f1 || echo "0"
    else
        echo "0"
    fi
}

format_size() {
    local kb=$1
    if [[ $kb -ge 1048576 ]]; then
        echo "$(echo "scale=2; $kb/1048576" | bc) GB"
    elif [[ $kb -ge 1024 ]]; then
        echo "$(echo "scale=2; $kb/1024" | bc) MB"
    else
        echo "${kb} KB"
    fi
}

confirm() {
    if $FORCE; then
        return 0
    fi
    local prompt="$1 [y/N]: "
    if $DRY_RUN; then
        prompt="$1 [DRY-RUN, would ask]: "
        echo -ne "${YELLOW}$prompt${NC}"
        read -r
        return 0
    fi
    echo -ne "${YELLOW}$prompt${NC}"
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# =============================================================================
# Pre-flight Checks & SIP Handler
# =============================================================================

SIP_DISABLED_BY_SCRIPT=false

handle_sip() {
    SIP_STATUS=$(csrutil status 2>/dev/null | grep -o "enabled\|disabled" || echo "unknown")

    if [[ "$SIP_STATUS" == "enabled" ]]; then
        log_warn "System Integrity Protection (SIP) is ENABLED"
        log_warn "Apple Intelligence system models (5-15 GB) CANNOT be removed."
        echo ""
        echo -e "${BOLD}${YELLOW}  ┌──────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${BOLD}${YELLOW}  │  SIP protects system files from modification.              │${NC}"
        echo -e "${BOLD}${YELLOW}  │  To fully remove Apple Intelligence, SIP must be disabled. │${NC}"
        echo -e "${BOLD}${YELLOW}  │  This requires restarting into Recovery Mode.              │${NC}"
        echo -e "${BOLD}${YELLOW}  └──────────────────────────────────────────────────────────────┘${NC}"
        echo ""

        if confirm "Disable SIP now? (will restart into Recovery Mode)"; then
            echo ""
            echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
            echo -e "${BOLD}${CYAN}║  INSTRUCTIONS - Follow these steps in Recovery Mode        ║${NC}"
            echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
            echo ""
            echo -e "${BOLD}Step 1: Boot into Recovery Mode${NC}"
            echo ""
            echo "  Apple Silicon Macs (M1, M2, M3, M4, etc.):"
            echo "    1. Shut down your Mac completely"
            echo "    2. Press and HOLD the power button"
            echo "    3. Keep holding until you see 'Loading startup options...'"
            echo "    4. Click 'Options' then 'Continue'"
            echo ""
            echo "  Intel Macs:"
            echo "    1. Restart your Mac"
            echo "    2. Immediately hold Cmd+R"
            echo "    3. Release when you see the Apple logo or spinning globe"
            echo ""
            echo -e "${BOLD}Step 2: Open Terminal in Recovery Mode${NC}"
            echo ""
            echo "    1. At the top menu bar, click 'Utilities'"
            echo "    2. Select 'Terminal'"
            echo ""
            echo -e "${BOLD}Step 3: Disable SIP in Terminal${NC}"
            echo ""
            echo "    Type this command and press Enter:"
            echo ""
            echo -e "      ${GREEN}csrutil disable${NC}"
            echo ""
            echo "    You should see: 'Successfully disabled System Integrity Protection'"
            echo ""
            echo -e "${BOLD}Step 4: Restart your Mac${NC}"
            echo ""
            echo "    Type this command and press Enter:"
            echo ""
            echo -e "      ${GREEN}reboot${NC}"
            echo ""
            echo -e "${BOLD}Step 5: Run this script again${NC}"
            echo ""
            echo "    After your Mac restarts, run:"
            echo ""
            echo -e "      ${GREEN}./cleanup.sh${NC}"
            echo ""
            echo -e "${BOLD}Step 6: Re-enable SIP when done (IMPORTANT!)${NC}"
            echo ""
            echo "    After cleanup completes, disable SIP again:"
            echo "    Boot into Recovery Mode (same as Step 1)"
            echo "    Open Terminal, then type:"
            echo ""
            echo -e "      ${GREEN}csrutil enable${NC}"
            echo ""
            echo "    Then restart your Mac."
            echo ""
            echo -e "${YELLOW}  TIP: Keep this terminal open. After you return from Recovery,${NC}"
            echo -e "${YELLOW}  run ./cleanup.sh again to finish removing the files.${NC}"
            echo ""

            if confirm "Ready to restart into Recovery Mode?"; then
                SIP_DISABLED_BY_SCRIPT=true
                log_info "Restarting into Recovery Mode in 5 seconds..."
                log_info "Hold Cmd+R (Intel) or power button (Apple Silicon) when it restarts"
                sleep 5
                # Attempt to restart into Recovery using nvram
                sudo nvram "recovery-boot-mode=upgrade" 2>/dev/null
                sudo reboot 2>/dev/null || shutdown -r now 2>/dev/null
                exit 0
            fi
        fi

        echo ""
        log_info "Continuing with SIP enabled. Some files will not be removed."
        log_info "You can re-run this script after disabling SIP manually."
    else
        log_info "SIP is disabled - full cleanup possible."
    fi
}

preflight_checks() {
    print_section "Pre-flight Checks"

    # Check macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script is designed for macOS only."
        exit 1
    fi
    log_info "Running on macOS $(sw_vers -productVersion)"

    # Handle SIP
    handle_sip

    # Get current disk usage
    echo ""
    echo -e "${BOLD}Current disk usage:${NC}"
    df -h / | tail -1 | awk '{print "  Used: "$3" / Free: "$4" / Total: "$2}'
    echo ""

    # Check for Apple Intelligence storage
    AI_STORAGE=$(find /System/Library/AssetsV2/ -maxdepth 1 -name "*com_apple*" -type d 2>/dev/null | while read dir; do
        du -sk "$dir" 2>/dev/null | cut -f1
    done | paste -sd+ - | bc 2>/dev/null || echo "0")

    if [[ "$AI_STORAGE" -gt 0 ]]; then
        log_info "Apple Intelligence models found: $(format_size $AI_STORAGE)"
    else
        log_warn "No Apple Intelligence models found (may already be removed or not downloaded)"
    fi
}

# =============================================================================
# Phase 1: Disable Apple Intelligence & Siri via System Settings
# =============================================================================

disable_apple_intelligence() {
    print_section "Phase 1: Disable Apple Intelligence & Siri"

    if $DRY_RUN; then
        log_action "Disable Apple Intelligence via defaults write"
        log_action "Disable Siri via defaults write"
        log_action "Disable Siri suggestions in Spotlight"
        return
    fi

    echo "This will disable Apple Intelligence and Siri through system preferences."
    echo "Note: Some settings may require a restart to take full effect."
    echo ""

    if confirm "Disable Apple Intelligence?"; then
        # Disable Apple Intelligence
        defaults write com.apple.Siri AppleIntelligenceEnabled -bool false
        defaults write com.apple.Siri StatusMenuVisible -bool false
        defaults write com.apple.assistant.support "Assistant Enabled" -bool false
        log_info "Apple Intelligence disabled"
    fi

    if confirm "Disable Siri?"; then
        # Disable Siri
        defaults write com.apple.Siri UserHasDeclinedEnable -bool true
        defaults write com.apple.Siri LockedOut -bool true
        defaults write com.apple.Siri SiriPrefStashedStatusEnabled -bool false
        log_info "Siri disabled"
    fi

    if confirm "Disable Siri Suggestions in Spotlight?"; then
        defaults write com.apple.Spotlight orderedItems -array-add \
            '{"enabled" = 0; "name" = "SIRI_SUGGESTIONS";}'
        log_info "Siri Suggestions in Spotlight disabled"
    fi

    # Disable Siri on lock screen
    defaults write com.apple.Siri AllowSiriWhenLocked -bool false
    log_info "Siri on lock screen disabled"

    # Disable "Hey Siri" listening
    defaults write com.apple.Siri VoiceTriggerUserEnabled -bool false
    log_info "Hey Siri listening disabled"

    log_info "Phase 1 complete. Restart recommended for full effect."
}

# =============================================================================
# Phase 2: Remove Apple Intelligence Model Files
# =============================================================================

remove_apple_intelligence_models() {
    print_section "Phase 2: Remove Apple Intelligence Model Files"

    # Known Apple Intelligence model and cache directories
    local AI_PATHS=(
        "/System/Library/AssetsV2/com_apple_MobileAsset_UAF_FM_GenerativeModels"
        "/System/Library/AssetsV2/com_apple_MobileAsset_UAF_FM_Visual"
        "/Library/Apple/System/Library/AssetsV2/com_apple_MobileAsset_UAF_FM_GenerativeModels"
        "/Library/Apple/System/Library/AssetsV2/com_apple_MobileAsset_UAF_FM_Visual"
        "$HOME/Library/Caches/com.apple.intelligence"
        "$HOME/Library/Caches/com.apple.siri"
        "$HOME/Library/Caches/com.apple.siri.analytics"
        "$HOME/Library/Caches/com.apple.assistant"
        "$HOME/Library/Assistant"
        "$HOME/Library/Saved Application State/com.apple.Siri.savedState"
    )

    local total_size=0

    for path in "${AI_PATHS[@]}"; do
        if [[ -e "$path" ]]; then
            local size
            size=$(get_dir_size "$path")
            total_size=$((total_size + size))
            echo -e "  ${CYAN}Found:${NC} $path"
            echo -e "        Size: $(format_size $size)"
        fi
    done

    if [[ $total_size -eq 0 ]]; then
        log_warn "No Apple Intelligence model files found."
        return
    fi

    echo ""
    echo -e "${BOLD}Total Apple Intelligence data: $(format_size $total_size)${NC}"

    if confirm "Remove these Apple Intelligence files?"; then
        for path in "${AI_PATHS[@]}"; do
            if [[ -e "$path" ]]; then
                if $DRY_RUN; then
                    log_action "Remove $path"
                else
                    if [[ "$path" == /System/* ]] || [[ "$path" == /Library/* ]]; then
                        sudo rm -rf "$path" 2>/dev/null && {
                            log_info "Removed $path"
                            SPACE_FREED=$((SPACE_FREED + $(get_dir_size "$path")))
                        } || log_error "Failed to remove $path (may require SIP disabled)"
                    else
                        rm -rf "$path" 2>/dev/null && {
                            log_info "Removed $path"
                            SPACE_FREED=$((SPACE_FREED + $(get_dir_size "$path")))
                        } || log_error "Failed to remove $path"
                    fi
                fi
                ((ITEMS_REMOVED++))
            fi
        done
    fi
}

# =============================================================================
# Phase 2: Clean Up System Caches
# =============================================================================

clean_system_caches() {
    print_section "Phase 4: Clean System Caches"

    local CACHE_PATHS=(
        "$HOME/Library/Caches/com.apple.Spotlight"
        "$HOME/Library/Caches/com.apple.siri"
        "$HOME/Library/Caches/com.apple.intelligence"
        "$HOME/Library/Caches/com.apple.assistant"
        "$HOME/Library/Caches/com.apple.TCC"
        "$HOME/Library/Caches/Metadata/Siri"
        "$HOME/Library/Caches/com.apple.parsecd"
        "$HOME/Library/Caches/com.apple.Siri.analytics"
        "$HOME/Library/Caches/CloudKit"
        "$HOME/Library/Caches/com.apple.icloud.searchpartyd"
    )

    local total_cache_size=0

    echo "Scanning AI-related caches..."
    for cache_path in "${CACHE_PATHS[@]}"; do
        if [[ -d "$cache_path" ]]; then
            local cache_size
            cache_size=$(get_dir_size "$cache_path")
            if [[ $cache_size -gt 0 ]]; then
                total_cache_size=$((total_cache_size + cache_size))
                echo -e "  ${CYAN}Cache:${NC} $cache_path ($(format_size $cache_size))"
            fi
        fi
    done

    if [[ $total_cache_size -gt 0 ]]; then
        echo ""
        echo -e "${BOLD}Total cache size: $(format_size $total_cache_size)${NC}"

        if confirm "Clean these caches?"; then
            for cache_path in "${CACHE_PATHS[@]}"; do
                if [[ -d "$cache_path" ]]; then
                    if $DRY_RUN; then
                        log_action "Clean cache: $cache_path"
                    else
                        rm -rf "$cache_path"/* 2>/dev/null && \
                            log_info "Cleaned: $cache_path" || \
                            log_error "Failed to clean: $cache_path"
                    fi
                fi
            done
        fi
    else
        log_info "No AI-related caches found."
    fi
}

# =============================================================================
# Phase 3: Disable Background AI Services/Daemons
# =============================================================================

disable_background_services() {
    print_section "Phase 3: Disable Background AI Services"

    echo "Checking for AI-related background services..."
    echo ""

    # Check for running AI-related processes
    local AI_PROCESSES=(
        "siri"
        "SiriNCService"
        "assistantd"
        "assistant_service"
        "neuralengineagent"
        "coreml"
        "SiriSearchIndexer"
        "SiriKnowledgeAgent"
    )

    local found_processes=()
    for proc in "${AI_PROCESSES[@]}"; do
        if pgrep -x "$proc" > /dev/null 2>&1; then
            found_processes+=("$proc")
            echo -e "  ${YELLOW}Running:${NC} $proc (PID: $(pgrep -x "$proc"))"
        fi
    done

    if [[ ${#found_processes[@]} -gt 0 ]]; then
        echo ""
        if confirm "Kill these AI processes?"; then
            for proc in "${found_processes[@]}"; do
                if ! $DRY_RUN; then
                    killall "$proc" 2>/dev/null && \
                        log_info "Killed: $proc" || \
                        log_warn "Could not kill: $proc"
                else
                    log_action "Kill process: $proc"
                fi
            done
        fi
    else
        log_info "No AI-related processes running."
    fi

    # Disable Siri launch agents
    echo ""
    echo "Disabling Siri launch agents..."
    local LAUNCH_AGENTS=(
        "$HOME/Library/LaunchAgents/com.apple.Siri.agent.plist"
        "/System/Library/LaunchAgents/com.apple.Siri.agent.plist"
        "/System/Library/LaunchAgents/com.apple.siriknowledged.plist"
        "/System/Library/LaunchAgents/com.apple.assistantd.plist"
    )

    for agent in "${LAUNCH_AGENTS[@]}"; do
        if [[ -f "$agent" ]]; then
            if ! $DRY_RUN; then
                launchctl unload "$agent" 2>/dev/null && \
                    log_info "Unloaded: $agent" || \
                    log_warn "Could not unload: $agent (may require SIP disabled)"
            else
                log_action "Unload launch agent: $agent"
            fi
        fi
    done
}

# =============================================================================
# Phase 4: Final Cleanup & Summary
# =============================================================================

final_cleanup() {
    print_section "Phase 6: Final Cleanup"

    if $DRY_RUN; then
        log_info "Dry-run mode - no actual changes made"
        return
    fi

    # Rebuild Spotlight index (optional)
    if confirm "Rebuild Spotlight index? (Recommended after cleanup)"; then
        sudo mdutil -E / > /dev/null 2>&1 && \
            log_info "Spotlight reindexing started" || \
            log_warn "Could not start Spotlight reindexing"
    fi

    # Flush DNS cache
    if confirm "Flush DNS cache?"; then
        sudo dscacheutil -flushcache > /dev/null 2>&1
        sudo killall -HUP mDNSResponder > /dev/null 2>&1
        log_info "DNS cache flushed"
    fi
}

print_summary() {
    print_section "Summary"

    echo -e "${BOLD}Cleanup complete!${NC}"
    echo ""

    if $DRY_RUN; then
        echo -e "${YELLOW}This was a DRY RUN - no changes were made.${NC}"
        echo "Run without --dry-run to apply changes."
    else
        echo -e "  Items processed: ${GREEN}${ITEMS_REMOVED}${NC}"
        if [[ $ERRORS -gt 0 ]]; then
            echo -e "  Errors: ${RED}${ERRORS}${NC}"
        fi
    fi

    # Check if SIP was the issue
    SIP_STATUS=$(csrutil status 2>/dev/null | grep -o "enabled\|disabled" || echo "unknown")
    if [[ "$SIP_STATUS" == "enabled" ]] && [[ $ERRORS -gt 0 ]]; then
        echo ""
        echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}${BOLD}║  SOME FILES COULD NOT BE REMOVED - SIP IS THE REASON     ║${NC}"
        echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${BOLD}Re-run this script to get the SIP disable prompt:${NC}"
        echo ""
        echo "    ./cleanup.sh"
        echo ""
        echo -e "${BOLD}Or disable SIP manually:${NC}"
        echo ""
        echo "  1. Restart your Mac"
        echo "  2. Hold Cmd+R (Intel) or power button (Apple Silicon)"
        echo "  3. Open Terminal from Utilities menu"
        echo "  4. Run: csrutil disable"
        echo "  5. Restart your Mac"
        echo "  6. Run: ./cleanup.sh"
        echo "  7. Re-enable SIP when done: sudo csrutil enable"
        echo ""
        echo -e "${YELLOW}NOTE: Disabling SIP reduces your Mac's security.${NC}"
        echo -e "${YELLOW}Re-enable it as soon as you finish the cleanup.${NC}"
    else
        echo ""
        echo -e "${BOLD}Important notes:${NC}"
        echo "  1. Restart your Mac for all changes to take effect."
        echo "  2. Apple Intelligence may re-enable after system updates."
    fi

    echo ""

    # Show disk usage after
    echo -e "${BOLD}Disk usage after cleanup:${NC}"
    df -h / | tail -1 | awk '{print "  Used: "$3" / Free: "$4" / Total: "$2}'
    echo ""

    echo -e "${CYAN}GitHub: https://github.com/Rish3666/unslop-macos27${NC}"
    echo -e "${CYAN}Report issues: https://github.com/Rish3666/unslop-macos27/issues${NC}"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    print_header

    if $DRY_RUN; then
        echo -e "${YELLOW}${BOLD}  DRY RUN MODE - No changes will be made${NC}"
        echo ""
    fi

    # Safety warning
    if ! $DRY_RUN; then
        echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}${BOLD}║  WARNING: This script modifies system settings and        ║${NC}"
        echo -e "${RED}${BOLD}║  deletes files. Always use --dry-run first!               ║${NC}"
        echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
    fi

    if ! $FORCE && ! $DRY_RUN; then
        echo "Recommended: Run with --dry-run first to preview changes."
        echo ""
        if ! confirm "Continue with actual cleanup?"; then
            echo "Cancelled. Run with --dry-run to preview changes."
            exit 0
        fi
    fi

    # Run all phases
    preflight_checks
    disable_apple_intelligence
    remove_apple_intelligence_models
    clean_system_caches
    disable_background_services
    final_cleanup
    print_summary
}

# Trap for cleanup on exit
trap 'echo -e "\n${YELLOW}Script interrupted.${NC}"; exit 1' INT TERM

main
