#!/bin/bash
# =============================================================================
# tests/run_tests.sh — unit + smoke tests for cleanup.sh
# =============================================================================
# Run:  ./tests/run_tests.sh
#
# Safe by construction: the cleanup.sh integration test runs in --dry-run mode
# with a stubbed `sudo` that always fails, so no system state can change.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CLEANUP="$REPO_DIR/cleanup.sh"

PASS=0
FAIL=0

t_pass() { PASS=$((PASS + 1)); echo "  ok  - $1"; }
t_fail() { FAIL=$((FAIL + 1)); echo "  FAIL- $1"; }

check() { # check <desc> <cmd...>
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then t_pass "$desc"; else t_fail "$desc"; fi
}

# ---------------------------------------------------------------------------
echo "== bash syntax =="
check "cleanup.sh parses (bash -n)" bash -n "$CLEANUP"
check "recovery-delete.sh parses (bash -n)" bash -n "$REPO_DIR/recovery-delete.sh"

# ---------------------------------------------------------------------------
echo "== unit: source cleanup.sh functions =="
# NOTE: sourcing imports `set -euo pipefail`; drop -e/-u/pipefail afterwards so
# a failing subshell reports a test failure instead of aborting the suite.
# shellcheck disable=SC1090
source "$CLEANUP"
set +e +u +o pipefail

TMPROOT="$(mktemp -d)"
trap 'rm -rf "$TMPROOT"' EXIT

# --- get_dir_size matches plain `du -sk | cut -f1` ground truth (no double-count)
mkdir -p "$TMPROOT/pkg/sub"
printf 'x%.0s' {1..2048} > "$TMPROOT/pkg/sub/file"   # ~2 KB of data
size=$(get_dir_size "$TMPROOT/pkg")
truth_kb=$(du -sk "$TMPROOT/pkg" 2>/dev/null | head -n 1 | cut -f1)
if [[ "$size" == "$truth_kb" ]]; then
    t_pass "get_dir_size matches du ground truth (${size}KB)"
else
    t_fail "get_dir_size=$size, du ground truth=$truth_kb"
fi
missing_size=$(get_dir_size "$TMPROOT/does-not-exist")
if [[ "$missing_size" == "0" ]]; then
    t_pass "get_dir_size returns 0 for missing path"
else
    t_fail "get_dir_size returned '$missing_size' for missing path"
fi

# --- log_error must not abort under set -e when ERRORS=0 (regression: ((ERRORS++)))
if ERRORS=0 bash -c 'set -e; source "'"$CLEANUP"'"; log_error "boom"' >/dev/null 2>&1; then
    t_pass "log_error survives set -e with ERRORS=0"
else
    t_fail "log_error aborts under set -e with ERRORS=0"
fi

# --- is_root_writable: parses macOS parenthesized mount lines correctly.
# Regression: the old awk '{print $4}' grabbed "(apfs," so the check never
# worked; feed synthetic mount tables for both directions.
RO_LINE='/dev/disk3s1s1 on / (apfs, sealed, local, read-only, journaled)'
RW_LINE='/dev/disk1s1 on / (apfs, local, journaled)'
if is_root_writable "$RO_LINE"; then
    t_fail "is_root_writable true for read-only mount line"
else
    t_pass "is_root_writable false for read-only mount line"
fi
if is_root_writable "$RW_LINE"; then
    t_pass "is_root_writable true for rw mount line"
else
    t_fail "is_root_writable false for rw mount line"
fi
if mount | awk '$3=="/"' | grep -q "read-only"; then
    if is_root_writable; then
        t_fail "live check: / is read-only but reported writable"
    else
        t_pass "live check: read-only / reported not writable"
    fi
else
    if is_root_writable; then
        t_pass "live check: rw / reported writable"
    else
        t_fail "live check: rw / reported not writable"
    fi
fi

# --- parse_args: unknown flag exits non-zero, known flags accepted
( parse_args --bogus ) >/dev/null 2>&1
rc=$?
if [[ $rc -ne 0 ]]; then t_pass "parse_args rejects unknown flag (exit $rc)"; else t_fail "parse_args accepts unknown flag"; fi
( parse_args --dry-run --force ) >/dev/null 2>&1
rc=$?
if [[ $rc -eq 0 ]]; then t_pass "parse_args accepts known flags"; else t_fail "parse_args rejects known flags (exit $rc)"; fi

# --- collect_ai_model_paths dedupes roots that resolve to the SAME directory
# (firmlink case): rootB is a symlink to rootA, so both path strings have
# identical device:inode identity and only one must be scanned.
mkdir -p "$TMPROOT/rootA/com_apple_MobileAsset_UAF_TestOne" \
         "$TMPROOT/rootC/com_apple_MobileAsset_UAF_TestTwo"
ln -s "$TMPROOT/rootA" "$TMPROOT/rootB"
assets_v2_roots() { printf '%s\n' "$TMPROOT/rootA" "$TMPROOT/rootB" "$TMPROOT/rootC"; }
count=$(collect_ai_model_paths | grep -c "UAF_TestOne")
count=${count:-0}
if [[ "$count" -eq 1 ]]; then
    t_pass "collect_ai_model_paths dedupes same-identity roots (got $count)"
else
    t_fail "collect_ai_model_paths emitted $count copies (expected 1)"
fi
count_two=$(collect_ai_model_paths | grep -c "UAF_TestTwo")
count_two=${count_two:-0}
if [[ "$count_two" -eq 1 ]]; then
    t_pass "distinct roots are still scanned (got $count_two)"
else
    t_fail "distinct root lost: UAF_TestTwo seen $count_two times (expected 1)"
fi
unset -f assets_v2_roots

# --- ui_menu_multiselect non-TTY behavior: rc 2 (fall back to confirm),
# or full selection under --force with UI_PICKS populated.
UI_PICKS=""
( ui_menu_multiselect "a" "x" "y" ) >/dev/null 2>&1
rc=$?
if [[ $rc -eq 2 ]]; then
    t_pass "ui_menu_multiselect signals rc 2 when UI inactive"
else
    t_fail "ui_menu_multiselect rc=$rc when UI inactive (expected 2)"
fi
FORCE=true UI_PICKS=""
ui_menu_multiselect "a" "x" "y" >/dev/null 2>&1
rc=$?
FORCE=false
if [[ $rc -eq 0 ]] && [[ "$UI_PICKS" == "1 2 "* ]]; then
    t_pass "ui_menu_multiselect --force selects all into UI_PICKS"
else
    t_fail "ui_menu_multiselect --force rc=$rc UI_PICKS='$UI_PICKS'"
fi

# --- ui_active: inactive for --no-ui even on a TTY-ish run
NO_UI=true
if ui_active; then t_fail "ui_active true with --no-ui"; else t_pass "ui_active false with --no-ui"; fi
NO_UI=false

# ---------------------------------------------------------------------------
echo "== integration: cleanup.sh --dry-run (sudo stubbed, read-only) =="
STUB="$(mktemp -d)"
printf '#!/bin/sh\nexit 1\n' > "$STUB/sudo"
chmod +x "$STUB/sudo"
DRY_OUT="$(PATH="$STUB:$PATH" "$CLEANUP" --dry-run < /dev/null 2>&1)"
DRY_RC=$?
if [[ $DRY_RC -eq 0 ]]; then t_pass "--dry-run exits 0 under set -e"; else t_fail "--dry-run exit code $DRY_RC"; fi
case "$DRY_OUT" in *"DRY RUN MODE"*) t_pass "dry-run banner shown";; *) t_fail "dry-run banner missing";; esac
case "$DRY_OUT" in *"[DRY-RUN]"*) t_pass "dry-run actions printed";; *) t_fail "no [DRY-RUN] actions printed";; esac
case "$DRY_OUT" in *"Usage:"*) t_fail "help text leaked into dry run";; *) t_pass "no help text leak";; esac
if printf '%s' "$DRY_OUT" | grep -q $'\033'; then
    t_fail "ANSI escapes present in piped output"
else
    t_pass "no ANSI escapes in piped (non-TTY) output"
fi
NO_COLOR_OUT="$(NO_COLOR=1 "$CLEANUP" --dry-run < /dev/null 2>&1)"
if printf '%s' "$NO_COLOR_OUT" | grep -q $'\033'; then
    t_fail "NO_COLOR=1 ignored"
else
    t_pass "NO_COLOR=1 disables colors"
fi
# --no-ui must behave like the plain flow: exit 0, no menus, no ANSI
NOUI_OUT="$(PATH="$STUB:$PATH" "$CLEANUP" --dry-run --no-ui < /dev/null 2>&1)"
NOUI_RC=$?
if [[ $NOUI_RC -eq 0 ]]; then t_pass "--no-ui --dry-run exits 0"; else t_fail "--no-ui --dry-run exit $NOUI_RC"; fi
case "$NOUI_OUT" in *"Enter numbers"*) t_fail "--no-ui still showed a menu";; *) t_pass "--no-ui shows no menus";; esac
if printf '%s' "$NOUI_OUT" | grep -q $'\033'; then
    t_fail "--no-ui output contains ANSI escapes"
else
    t_pass "--no-ui output is plain"
fi
# Unknown flag must still be rejected
( PATH="$STUB:$PATH" "$CLEANUP" --bogus < /dev/null ) >/dev/null 2>&1
rc=$?
if [[ $rc -eq 64 ]]; then t_pass "unknown flag exits 64"; else t_fail "unknown flag exit $rc (expected 64)"; fi
rm -rf "$STUB"

# ---------------------------------------------------------------------------
echo ""
echo "Results: $PASS passed, $FAIL failed"
if [[ $FAIL -eq 0 ]]; then
    echo "ALL TESTS PASSED"
    exit 0
fi
exit 1
