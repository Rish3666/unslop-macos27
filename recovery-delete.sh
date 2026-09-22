#!/bin/bash
# Print Recovery-mode commands to delete stuck Apple Intelligence UAF assets.
# Run this in macOS Recovery Terminal after unlocking volumes if needed.
set -euo pipefail

echo "=== unslop-macos27: Recovery deletion helper ==="
echo "Run this script FROM Recovery Terminal, or paste the output there."
echo ""

# Try common Data volume mount points in Recovery
CANDIDATES=()
for v in /Volumes/*; do
  [[ -d "$v/System/Library/AssetsV2" ]] && CANDIDATES+=("$v/System/Library/AssetsV2")
done

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
  echo "No AssetsV2 found under /Volumes/*."
  echo "Unlock/mount Data first, e.g.:"
  echo "  diskutil apfs list"
  echo "  diskutil apfs unlockVolume disk3s5 -user <UUID>"
  echo "  ls /Volumes"
  exit 1
fi

for root in "${CANDIDATES[@]}"; do
  echo "# AssetsV2 root: $root"
  shopt -s nullglob
  for d in "$root"/com_apple_MobileAsset_UAF_*; do
    echo "sudo rm -rf \"$d\""
  done
  shopt -u nullglob
done

echo ""
echo "Also clear diagnostics leftovers if present:"
echo "  sudo rm -f /Volumes/*/System/Library/AssetsV2/.write_test*"
echo ""
echo "Then reboot and re-enable SIP:"
echo "  csrutil enable"
echo "  csrutil authenticated-root enable"
