#!/usr/bin/env bash
# Safely resize a directly mounted ext4 root partition and filesystem.
set -Eeuo pipefail

ROOT_PART="$(findmnt -n -o SOURCE /)"
ROOT_FS_TYPE="$(findmnt -n -o FSTYPE /)"

if [[ "$ROOT_FS_TYPE" != "ext4" ]]; then
  echo "Root filesystem is not ext4 (found: $ROOT_FS_TYPE)." >&2
  exit 1
fi
if [[ "$ROOT_PART" != /dev/* || "$(lsblk -ndo TYPE "$ROOT_PART")" != "part" ]]; then
  echo "Root must be mounted directly from a disk partition; found: $ROOT_PART" >&2
  exit 1
fi

PARENT_NAME="$(lsblk -ndo PKNAME "$ROOT_PART")"
PART_NUM="$(lsblk -ndo PARTN "$ROOT_PART")"
if [[ -z "$PARENT_NAME" || ! "$PART_NUM" =~ ^[0-9]+$ ]]; then
  echo "Unable to identify the parent disk and partition number for $ROOT_PART." >&2
  exit 1
fi
ROOT_DEV="/dev/$PARENT_NAME"

echo "Root partition: $ROOT_PART"
echo "Parent disk:    $ROOT_DEV"
echo "Partition:      $PART_NUM"
lsblk -f "$ROOT_DEV"
read -r -p "Grow $ROOT_PART to available disk space? [y/N]: " reply
[[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]] || exit 0

if ! command -v growpart >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y cloud-guest-utils
fi

sudo growpart "$ROOT_DEV" "$PART_NUM"
sudo resize2fs "$ROOT_PART"
df -h /
