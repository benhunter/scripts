#!/bin/bash
# storage_diagnose.sh - Collects comprehensive storage diagnostics on Ubuntu

OUTPUT="/tmp/storage_report_$(hostname)_$(date +%Y%m%d_%H%M%S).log"

echo "Saving storage diagnostics to: $OUTPUT"
exec > >(tee -a "$OUTPUT") 2>&1

echo "============================"
echo "📅 Date and Hostname"
echo "============================"
date
hostname

echo -e "\n============================"
echo "💽 Disk Usage (df -h)"
echo "============================"
df -hT

echo -e "\n============================"
echo "📁 Mount Points"
echo "============================"
mount | column -t

echo -e "\n============================"
echo "🔍 Largest Directories (Top 10 under /)"
echo "============================"
du -xh / --max-depth=1 2>/dev/null | sort -hr | head -n 10

echo -e "\n============================"
echo "📂 Largest Directories in /var"
echo "============================"
du -xh /var --max-depth=1 2>/dev/null | sort -hr | head -n 10

echo -e "\n============================"
echo "🧾 Filesystem Summary (lsblk)"
echo "============================"
lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT,LABEL,UUID

echo -e "\n============================"
echo "🧮 Disk Partitions (fdisk -l)"
echo "============================"
sudo fdisk -l

echo -e "\n============================"
echo "🔐 LVM Volumes (if used)"
echo "============================"
sudo vgdisplay
sudo lvdisplay

echo -e "\n============================"
echo "📊 Inode Usage"
echo "============================"
df -ih

echo -e "\n============================"
echo "⚠️  Files Taking >100MB (Top 10)"
echo "============================"
find / -type f -size +100M -exec du -h {} + 2>/dev/null | sort -hr | head -n 10

echo -e "\n============================"
echo "🧪 ZFS Pools and Datasets (if available)"
echo "============================"
if command -v zpool &> /dev/null; then
    zpool list
    zfs list
else
    echo "ZFS not installed"
fi

echo -e "\n============================"
echo "📦 Snapshots (if any)"
echo "============================"
if command -v btrfs &> /dev/null; then
    sudo btrfs subvolume list /
elif command -v zfs &> /dev/null; then
    zfs list -t snapshot
else
    echo "No snapshot subsystem detected (btrfs/zfs)"
fi

echo -e "\n✅ Done. Full report saved to $OUTPUT"

