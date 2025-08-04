#!/bin/bash
# expand_root_volume.sh - Safely resize root partition and ext4 filesystem
# 2025-08-04

set -euo pipefail

echo "🔍 Checking required tools..."
if ! command -v growpart &>/dev/null; then
  echo "Installing growpart (cloud-guest-utils)..."
  sudo apt update
  sudo apt install -y cloud-guest-utils
fi

ROOT_MOUNT_DEVICE=$(findmnt -n -o SOURCE /)
ROOT_FS_TYPE=$(findmnt -n -o FSTYPE /)

if [[ "$ROOT_FS_TYPE" != "ext4" ]]; then
  echo "❌ Root filesystem is not ext4 (found: $ROOT_FS_TYPE). Aborting."
  exit 1
fi

if [[ "$ROOT_MOUNT_DEVICE" != /dev/vda2 ]]; then
  echo "⚠️ Warning: root is not mounted on /dev/vda2 (found: $ROOT_MOUNT_DEVICE)."
  read -rp "Do you want to proceed with $ROOT_MOUNT_DEVICE? (y/n): " confirm
  if [[ "$confirm" != "y" ]]; then
    echo "Aborting."
    exit 1
  fi
fi

ROOT_DEV="/dev/vda"
PART_NUM="2"
PART="${ROOT_DEV}${PART_NUM}"

echo "✅ Detected root on $PART with ext4 filesystem."

echo "🧱 Expanding partition $PART..."
sudo growpart "$ROOT_DEV" "$PART_NUM"

echo "📂 Resizing ext4 filesystem on $PART..."
sudo resize2fs "$PART"

echo "✅ Expansion complete. Final disk usage:"
df -h /
