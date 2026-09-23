#!/bin/bash
# Print Recovery-mode commands to delete stuck Apple Intelligence UAF assets.
# Run this in macOS Recovery Terminal after unlocking volumes if needed.
#
# Why Recovery: .AssetData subtrees return EROFS (errno 30) even on a writable
# Data volume with SIP + Authenticated Root disabled (issues #2 and #7). The
# protection follows the directory inode, so moving the tree does NOT help.
# From Recovery, the Data volume's rm works.
set -euo pipefail

echo "=== unslop-macos27: Recovery deletion helper ==="
echo "Run this script FROM Recovery Terminal, or paste the output there."
echo ""

# Try common Data volume mount points in Recovery
CANDIDATES=()
for v in /Volumes/*; do
  # Guarded with if: a bare `[[ ]] && arr+=(...)` as the last loop iteration
  # returns 1 and kills the whole script under set -e.
  if [[ -d "$v/System/Library/AssetsV2" ]]; then
    CANDIDATES+=("$v/System/Library/AssetsV2")
  fi
done

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
  echo "No AssetsV2 found under /Volumes/*. Unlock/mount the Data volume first:"
  echo ""
  echo "  diskutil apfs list                 # find volume IDs (System, Data)"
  echo "  diskutil apfs listcryptousers disk3s1   # if FileVault: get owner UUID"
  echo "  diskutil apfs unlockVolume disk3s5 -user <UUID>"
  echo "  ls /Volumes"
  exit 1
fi

echo "# Paste the following into the Recovery Terminal:"
echo ""
for root in "${CANDIDATES[@]}"; do
  echo "# AssetsV2 root: $root"
  echo "# 0) Clear flags first - some assets carry the 'restricted' flag:"
  echo "#    (macOS chflags has no -R; walk the tree with find)"
  echo "sudo find -x \"$root\" -exec chflags norestricted,noschg,nouchg {} + 2>/dev/null"
  echo "# 1) Delete the model dirs:"
  shopt -s nullglob
  for d in "$root"/com_apple_MobileAsset_UAF_*; do
    echo "sudo rm -rf \"$d\""
  done
  shopt -u nullglob
  echo "# 2) Remove emptied .asset parents (optional):"
  echo "sudo find \"$root\" -depth -type d -name '.asset' -empty -exec rmdir {} + 2>/dev/null"
  echo ""
done

echo "Also clear diagnostics leftovers if present:"
echo "  sudo rm -f /Volumes/*/System/Library/AssetsV2/.write_test*"
echo ""
echo "Notes:"
echo "  - AssetsV2 has xattr com.apple.rootless=MobileAsset (issue #8); if rm"
echo "    still fails with EROFS/EPERM inside .AssetData, report in issue #2."
echo "  - EROFS follows the inode: mv to another volume does NOT unlock deletion."
echo ""
echo "When finished, reboot and re-enable protections from Recovery:"
echo "  csrutil enable"
echo "  csrutil authenticated-root enable"
echo "  # Then re-enable FileVault in System Settings if you decrypted it."
