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
# GitHub: https://github.com/Rish3666/unslop-macos27
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
ROOT_WRITABLE=false

get_sip_status() {
    csrutil status 2>/dev/null | grep -o "enabled\|disabled" || echo "unknown"
}

get_auth_root_status() {
    csrutil authenticated-root status 2>/dev/null | grep -o "enabled\|disabled" || echo "unknown"
}

is_root_writable() {
    local opts
    opts=$(mount | awk '$3=="/" {print $4}')
    if [[ "$opts" == *"rw"* ]]; then
        return 0
    else
        return 1
    fi
}

try_mount_writable() {
    if is_root_writable; then
        ROOT_WRITABLE=true
        return 0
    fi
    log_info "Remounting system volume as writable..."
    if sudo mount -uw / 2>/dev/null || sudo mount -t apfs -o update,rw / 2>/dev/null; then
        if is_root_writable; then
            ROOT_WRITABLE=true
            log_info "System volume is now writable."
            return 0
        fi
    fi
    ROOT_WRITABLE=false
    log_warn "Could not remount system volume as writable."
    return 1
}

print_recovery_instructions() {
    local need_sip="$1"
    local need_auth="$2"

    # Check if FileVault is likely enabled (affects authenticated-root disable)
    local filevault_on=false
    if command -v fdesetup >/dev/null 2>&1 && fdesetup status 2>/dev/null | grep -qi "on"; then
        filevault_on=true
    fi

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
    echo -e "${BOLD}Step 3: Run these commands in Recovery Terminal${NC}"
    echo ""
    if [[ "$need_sip" == "true" ]]; then
        echo "    a) Disable SIP:"
        echo ""
        echo -e "      ${GREEN}csrutil disable${NC}"
        echo ""
        echo "      You should see: 'Successfully disabled System Integrity Protection'"
        echo ""
    fi
    if [[ "$need_auth" == "true" ]]; then
        echo "    b) Disable Authenticated Root (required to modify system volume):"
        echo ""
        echo -e "      ${GREEN}csrutil authenticated-root disable${NC}"
        echo ""
        if $filevault_on; then
            echo "      If this fails with 'FileVault must be disabled',"
            echo "      follow the FileVault steps below first, then re-run it."
            echo ""
            echo -e "${BOLD}${YELLOW}      --- FileVault steps (only if that error appears) ---${NC}"
            echo ""
            echo "      fdesetup is NOT available in Recovery. Use diskutil:"
            echo ""
            echo "      1. List APFS volumes and note the volume IDs"
            echo "         (e.g. disk3s1 = System, disk3s5 = Data):"
            echo ""
            echo -e "        ${GREEN}diskutil apfs list${NC}"
            echo ""
            echo "      2. Find your local volume owner UUID:"
            echo ""
            echo -e "        ${GREEN}diskutil apfs listcryptousers disk3s1${NC}"
            echo ""
            echo "         Copy the UUID like:"
            echo "         80A22EE9-2149-42C4-B86E-A5D78A40E109"
            echo ""
            echo "      3. Unlock the System volume:"
            echo ""
            echo -e "        ${GREEN}diskutil apfs unlockVolume disk3s1 -user <YOUR_UUID>${NC}"
            echo ""
            echo "      4. Unlock the Data volume:"
            echo ""
            echo -e "        ${GREEN}diskutil apfs unlockVolume disk3s5 -user <YOUR_UUID>${NC}"
            echo ""
            echo "      5. Decrypt the Data volume:"
            echo ""
            echo -e "        ${GREEN}diskutil apfs decryptVolume disk3s5 -user <YOUR_UUID>${NC}"
            echo ""
            echo "         (May report: Decryption has likely completed due to AES hardware)"
            echo ""
            echo "      6. Verify FileVault is off:"
            echo ""
            echo -e "        ${GREEN}diskutil apfs list${NC}"
            echo ""
            echo "         Data volume should show: FileVault: No"
            echo ""
            echo "      7. Then re-run:"
            echo ""
            echo -e "        ${GREEN}csrutil authenticated-root disable${NC}"
            echo ""
        else
            echo "      You should see: 'Successfully disabled Authenticated Root'"
            echo ""
            echo "      If this fails with 'FileVault must be disabled',"
            echo "      you must temporarily decrypt your volume first:"
            echo ""
            echo "        1. diskutil apfs list          # find volume IDs"
            echo "        2. diskutil apfs listcryptousers disk3s1   # get owner UUID"
            echo "        3. diskutil apfs unlockVolume disk3s1 -user <UUID>"
            echo "        4. diskutil apfs unlockVolume disk3s5 -user <UUID>"
            echo "        5. diskutil apfs decryptVolume disk3s5 -user <UUID>"
            echo "        6. csrutil authenticated-root disable"
            echo ""
        fi
        echo "      Otherwise you should see: 'Successfully disabled Authenticated Root'"
        echo ""
    fi
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
    echo "    The script will remount the system volume as writable and"
    echo "    remove the Apple Intelligence model files."
    echo ""
    echo -e "${BOLD}Step 6: Re-enable SIP when done (IMPORTANT!)${NC}"
    echo ""
    echo "    After cleanup completes, boot into Recovery Mode again"
    echo "    and run:"
    echo ""
    echo -e "      ${GREEN}csrutil enable${NC}"
    if [[ "$need_auth" == "true" ]]; then
        echo -e "      ${GREEN}csrutil authenticated-root enable${NC}"
    fi
    if $filevault_on; then
        echo ""
        echo "    Also re-enable FileVault (if you decrypted it):"
        echo ""
        echo "      Open System Settings > Privacy & Security > FileVault"
        echo "      Turn FileVault back on after rebooting normally."
    fi
    echo ""
    echo "    Then restart your Mac."
    echo ""
}

handle_sip() {
    SIP_STATUS=$(get_sip_status)
    AUTH_STATUS=$(get_auth_root_status)

    if [[ "$SIP_STATUS" == "enabled" ]]; then
        log_warn "System Integrity Protection (SIP) is ENABLED"
        log_warn "Apple Intelligence system models (5-15 GB) CANNOT be removed."
        echo ""

        if confirm "Disable SIP and Authenticated Root? (shows Recovery Mode instructions)"; then
            print_recovery_instructions "true" "true"
            echo -e "${BOLD}${CYAN}Press Enter when you are ready to restart your Mac manually.${NC}"
            echo -e "${CYAN}Remember: Hold Cmd+R (Intel) or power button (Apple Silicon).${NC}"
            read -r
            exit 0
        fi

        echo ""
        log_info "Continuing with SIP enabled. Some files will not be removed."
        log_info "You can re-run this script after disabling SIP manually."
    elif [[ "$AUTH_STATUS" == "enabled" ]]; then
        log_warn "SIP is disabled, but Authenticated Root is ENABLED"
        log_warn "The system volume is sealed/read-only. Files cannot be removed yet."
        echo ""

        if confirm "Disable Authenticated Root? (shows Recovery Mode instructions)"; then
            print_recovery_instructions "false" "true"
            echo -e "${BOLD}${CYAN}Press Enter when you are ready to restart your Mac manually.${NC}"
            echo -e "${CYAN}Remember: Hold Cmd+R (Intel) or power button (Apple Silicon).${NC}"
            read -r
            exit 0
        fi

        echo ""
        log_info "Continuing. Files on the system volume may not be removable."
    else
        log_info "SIP is disabled."
        log_info "Authenticated Root is disabled."
    fi

    # Try to remount system volume as writable
    try_mount_writable || true
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

    # Check for Apple Intelligence storage (dynamic UAF_* scan on all AssetsV2 roots)
    AI_STORAGE=0
    while IFS= read -r assets_root; do
        [[ -z "$assets_root" ]] && continue
        for dir in "$assets_root"/com_apple_MobileAsset_UAF_*; do
            if [[ -d "$dir" ]]; then
                local kb
                kb=$(get_dir_size "$dir")
                AI_STORAGE=$((AI_STORAGE + kb))
            fi
        done
    done < <(assets_v2_roots)

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

# AssetsV2 is firmlinked to the Data volume on macOS 27. Prefer the Data
# path when the sealed root snapshot is read-only (see AGENTS.md / issues #1, #5).
assets_v2_roots() {
    local roots=()
    local r
    for r in \
        "/System/Volumes/Data/System/Library/AssetsV2" \
        "/System/Library/AssetsV2" \
        "/Library/Apple/System/Library/AssetsV2"; do
        if [[ -d "$r" ]]; then
            roots+=("$r")
        fi
    done
    printf '%s\n' "${roots[@]}"
}

# Collect Apple Intelligence / Siri UAF model dirs (dynamic glob, not hardcoded).
collect_ai_model_paths() {
    local roots root d
    local -a found=()

    while IFS= read -r root; do
        [[ -z "$root" ]] && continue
        # Shellcheck: glob intentionally unquoted for *
        for d in "$root"/com_apple_MobileAsset_UAF_*; do
            [[ -d "$d" ]] && found+=("$d")
        done
        # Legacy / narrower names if present without UAF_ prefix
        for d in \
            "$root/com_apple_MobileAsset_UAF_FM_GenerativeModels" \
            "$root/com_apple_MobileAsset_UAF_FM_Visual"; do
            [[ -d "$d" ]] && found+=("$d")
        done
    done < <(assets_v2_roots)

    # Dedupe (same path via firmlink roots)
    if [[ ${#found[@]} -gt 0 ]]; then
        printf '%s\n' "${found[@]}" | awk '!seen[$0]++'
    fi
}

# Clear flags that block deletion on some system assets.
clear_asset_flags() {
    local path="$1"
    if [[ ! -e "$path" ]]; then
        return 0
    fi
    sudo chflags -R norestricted,noschg,nouchg,uchg,hidden "$path" 2>/dev/null || true
}

explain_system_delete_failure() {
    local path="$1"
    if [[ "${SIP_STATUS:-}" == "enabled" ]]; then
        echo "         SIP is enabled - disable it in Recovery Mode first."
    elif [[ "${AUTH_STATUS:-}" == "enabled" ]]; then
        echo "         Authenticated Root is enabled - disable it in Recovery Mode:"
        echo "           csrutil authenticated-root disable"
    elif ! is_root_writable; then
        echo "         Sealed root snapshot is read-only (mount -uw / may fail; see issue #1)."
        echo "         Data-volume path may still work: /System/Volumes/Data/System/Library/AssetsV2"
    else
        echo "         Possible causes: EROFS inside .AssetData (issue #2),"
        echo "         open handles / Resource busy (issue #3), or missing chflags clear."
        echo "         Try: sudo chflags -R norestricted,noschg,nouchg \"$path\" && sudo rm -rf \"$path\""
    fi
}

remove_apple_intelligence_models() {
    print_section "Phase 2: Remove Apple Intelligence Model Files"

    local -a AI_PATHS=()
    local path size total_size=0

    # Dynamic UAF model directories (Data volume first)
    while IFS= read -r path; do
        [[ -n "$path" ]] && AI_PATHS+=("$path")
    done < <(collect_ai_model_paths)

    # User-level caches / state
    local user_paths=(
        "$HOME/Library/Caches/com.apple.intelligence"
        "$HOME/Library/Caches/com.apple.siri"
        "$HOME/Library/Caches/com.apple.siri.analytics"
        "$HOME/Library/Caches/com.apple.assistant"
        "$HOME/Library/Assistant"
        "$HOME/Library/Saved Application State/com.apple.Siri.savedState"
    )
    AI_PATHS+=("${user_paths[@]}")

    # Diagnostics leftovers from prior runs (issue #6)
    local leftovers=(
        "/System/Volumes/Data/System/Library/AssetsV2/.write_test"
        "/System/Volumes/Data/System/Library/AssetsV2/.write_test2"
        "/System/Library/AssetsV2/.write_test"
        "/System/Library/AssetsV2/.write_test2"
    )
    if ! $DRY_RUN; then
        for path in "${leftovers[@]}"; do
            if [[ -e "$path" ]]; then
                sudo rm -f "$path" 2>/dev/null || true
            fi
        done
    fi

    if [[ ${#AI_PATHS[@]} -eq 0 ]]; then
        log_warn "No Apple Intelligence model files found."
        return
    fi

    echo "Apple Intelligence model directories:"
    for path in "${AI_PATHS[@]}"; do
        if [[ -e "$path" ]]; then
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

    if ! confirm "Remove these Apple Intelligence files?"; then
        return
    fi

    local has_system_paths=false
    for path in "${AI_PATHS[@]}"; do
        if [[ "$path" == /System/* ]] || [[ "$path" == /Library/* ]]; then
            has_system_paths=true
            break
        fi
    done

    if $has_system_paths && ! $DRY_RUN; then
        try_mount_writable || true
        # Stop daemons that pin MobileAsset files before rm (issue #3)
        if command -v pkill >/dev/null 2>&1; then
            local procs=(assistantd mobileassetd mds mds_stores suggestd)
            for p in "${procs[@]}"; do
                sudo pkill -9 "$p" 2>/dev/null || true
            done
            sleep 1
        fi
    fi

    local failed=0
    for path in "${AI_PATHS[@]}"; do
        [[ -e "$path" ]] || continue

        if $DRY_RUN; then
            log_action "Remove $path"
            ((ITEMS_REMOVED++))
            continue
        fi

        local needs_sudo=false
        if [[ "$path" == /System/* ]] || [[ "$path" == /Library/* ]]; then
            needs_sudo=true
        fi

        clear_asset_flags "$path"

        local err=""
        if $needs_sudo; then
            err=$(sudo rm -rf "$path" 2>&1) || true
        else
            err=$(rm -rf "$path" 2>&1) || true
        fi

        if [[ ! -e "$path" ]]; then
            log_info "Removed $path"
            ((ITEMS_REMOVED++))
        else
            # Partial delete: tree may be smaller even if not empty
            local after
            after=$(get_dir_size "$path")
            if [[ "$after" -lt "$size" ]] 2>/dev/null; then
                log_warn "Partially removed $path ($(format_size $after) left)"
            fi
            log_error "Failed to fully remove $path"
            [[ -n "$err" ]] && echo "$err" | head -3 | sed 's/^/         /'
            explain_system_delete_failure "$path"
            failed=$((failed + 1))
        fi
    done

    if [[ $failed -gt 0 ]]; then
        log_warn "$failed path(s) incomplete — often .AssetData EROFS (issues #2/#3)."
        log_warn "Re-run after killing MobileAsset daemons, or delete from Recovery."
    fi
}

# =============================================================================
# Phase 3: Clean Up System Caches
# =============================================================================

clean_system_caches() {
    print_section "Phase 3: Clean System Caches"

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
# Phase 4: Disable Background AI Services/Daemons
# =============================================================================

disable_background_services() {
    print_section "Phase 4: Disable Background AI Services"

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
# Phase 5: Final Cleanup & Summary
# =============================================================================

final_cleanup() {
    print_section "Phase 5: Final Cleanup"

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

    # Check if SIP/Auth Root/read-only volume was the issue
    SIP_STATUS=$(get_sip_status)
    AUTH_STATUS=$(get_auth_root_status)
    if [[ $ERRORS -gt 0 ]]; then
        echo ""
        echo -e "${RED}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}${BOLD}║  SOME FILES COULD NOT BE REMOVED                           ║${NC}"
        echo -e "${RED}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        if [[ "$SIP_STATUS" == "enabled" ]]; then
            echo -e "${BOLD}Cause: SIP is still enabled.${NC}"
        elif [[ "$AUTH_STATUS" == "enabled" ]]; then
            echo -e "${BOLD}Cause: Authenticated Root is still enabled (system volume is sealed).${NC}"
        elif ! is_root_writable; then
            echo -e "${BOLD}Cause: System volume is mounted read-only.${NC}"
            echo "  Fix: sudo mount -uw /"
        else
            echo -e "${BOLD}Cause: Permission or file system error (see messages above).${NC}"
        fi
        echo ""
        echo -e "${BOLD}Re-run this script to get guided instructions:${NC}"
        echo ""
        echo "    ./cleanup.sh"
        echo ""
        echo -e "${YELLOW}NOTE: Disabling SIP reduces your Mac's security.${NC}"
        echo -e "${YELLOW}Re-enable it as soon as you finish the cleanup.${NC}"
    else
        echo ""
        echo -e "${BOLD}Important notes:${NC}"
        echo "  1. Restart your Mac for all changes to take effect."
        echo "  2. Apple Intelligence may re-enable after system updates."
        echo "  3. Re-enable SIP if you disabled it: boot to Recovery and run csrutil enable"
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
