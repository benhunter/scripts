#!/usr/bin/env bash
set -Eeuo pipefail

# Ubuntu disk usage diagnostic script
# Non-destructive: this script only reads information and prints recommendations.
#
# Usage:
#   chmod +x disk-space-diagnose.sh
#   ./disk-space-diagnose.sh
#
# Optional:
#   sudo ./disk-space-diagnose.sh
#
# Notes:
# - Running with sudo gives much better visibility into /var, /root, snap, docker, journals, etc.
# - No files are modified or removed.

PATH=/usr/sbin:/usr/bin:/sbin:/bin

HR="================================================================================"

section() {
  echo
  echo "$HR"
  echo "$1"
  echo "$HR"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

human_sort_du() {
  sort -h 2>/dev/null || sort -n
}

run_cmd() {
  local desc="$1"
  shift
  echo
  echo ">>> $desc"
  echo "+ $*"
  "$@" 2>/dev/null || true
}

safe_du_top() {
  local target="$1"
  local depth="${2:-1}"
  if [[ -e "$target" ]]; then
    echo
    echo "Top entries under $target (depth=$depth):"
    du -xhd "$depth" "$target" 2>/dev/null | human_sort_du | tail -n 25 || true
  fi
}

show_largest_files() {
  local target="$1"
  local label="$2"
  if [[ -d "$target" ]]; then
    echo
    echo "Largest files under $label ($target):"
    find "$target" -xdev -type f -printf '%s\t%p\n' 2>/dev/null \
      | sort -nr \
      | head -n 20 \
      | awk '
          function human(x) {
            s="B KB MB GB TB PB"
            split(s, arr, " ")
            i=1
            while (x >= 1024 && i < 6) { x/=1024; i++ }
            return sprintf("%.1f %s", x, arr[i])
          }
          { printf "%10s  %s\n", human($1), $2 }
        '
  fi
}

recommend() {
  echo
  echo "$HR"
  echo "CANDIDATE CLEANUP COMMANDS (NOT RUN)"
  echo "$HR"

  cat <<'EOF'
Review these manually before running them.

APT package cache / old packages
  sudo apt clean
  sudo apt autoclean
  sudo apt autoremove --purge

Systemd journal logs
  journalctl --disk-usage
  sudo journalctl --vacuum-time=7d
  sudo journalctl --vacuum-size=200M

Old kernels
  dpkg -l 'linux-image*' | awk '/^ii/{print $2}'
  sudo apt autoremove --purge

Crash dumps / reports
  ls -lh /var/crash
  sudo rm -rf /var/crash/*

Temporary files
  ls -lah /tmp
  ls -lah /var/tmp
  sudo find /tmp -xdev -type f -mtime +7
  sudo find /var/tmp -xdev -type f -mtime +30

User caches
  du -sh ~/.cache
  rm -rf ~/.cache/thumbnails/*
  # Review before removing general cache content:
  # rm -rf ~/.cache/*

Snap old revisions
  snap list --all
  sudo snap set system refresh.retain=2
  # Remove disabled old revisions after review:
  # sudo snap remove <package> --revision <rev>

Docker / container storage
  docker system df
  docker image ls
  docker container ls -a
  docker volume ls
  sudo docker system prune
  sudo docker system prune -a --volumes

Flatpak
  flatpak list
  flatpak uninstall --unused

Logs in /var/log
  sudo find /var/log -type f -size +100M -ls
  sudo truncate -s 0 /var/log/<large-log-file>

Old files in Downloads or home directory
  find ~/Downloads -type f -printf '%TY-%Tm-%Td %TT %10s %p\n' | sort
  find ~ -type f -size +500M -printf '%10s %p\n' | sort -nr | head

If using package managers / dev tooling:
  npm cache verify
  npm cache clean --force
  pip cache info
  pip cache purge
  cargo cache -a         # if cargo-cache is installed
  go clean -modcache
  pnpm store prune

If using Kubernetes tooling locally:
  du -sh ~/.kube ~/.minikube ~/.local/share/containers ~/.config/containers 2>/dev/null

EOF
}

section "SYSTEM OVERVIEW"

echo "Hostname: $(hostname 2>/dev/null || echo unknown)"
echo "Date: $(date)"
echo "User: $(id -un)"
echo "Running as root: $(if [[ $EUID -eq 0 ]]; then echo yes; else echo no; fi)"
echo "Kernel: $(uname -r)"
echo "OS:"
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  echo "  $PRETTY_NAME"
fi

section "FILESYSTEM USAGE"

run_cmd "Mounted filesystems" df -hT -x tmpfs -x devtmpfs
run_cmd "Inode usage" df -ihT -x tmpfs -x devtmpfs

ROOT_USAGE="$(df --output=pcent / | tail -n1 | tr -dc '0-9' || echo 0)"
echo
echo "Root filesystem usage: ${ROOT_USAGE}%"

section "TOP-LEVEL DISK USAGE"

safe_du_top / 1
safe_du_top /var 1
safe_du_top /usr 1
safe_du_top /home 1
safe_du_top /opt 1
safe_du_top /srv 1
safe_du_top /root 1

section "LARGEST FILES ON ROOT FILESYSTEM"

echo
echo "Scanning for largest files on / (same filesystem only)..."
find / -xdev -type f -printf '%s\t%p\n' 2>/dev/null \
  | sort -nr \
  | head -n 40 \
  | awk '
      function human(x) {
        s="B KB MB GB TB PB"
        split(s, arr, " ")
        i=1
        while (x >= 1024 && i < 6) { x/=1024; i++ }
        return sprintf("%.1f %s", x, arr[i])
      }
      { printf "%10s  %s\n", human($1), $2 }
    '

show_largest_files /var "/var"
show_largest_files /home "/home"
show_largest_files /usr "/usr"

section "APT / DPKG"

if [[ -d /var/cache/apt ]]; then
  safe_du_top /var/cache/apt 2
fi

if have apt; then
  echo
  echo "APT package cache size:"
  du -sh /var/cache/apt 2>/dev/null || true
fi

if have dpkg; then
  echo
  echo "Installed kernel packages:"
  dpkg -l 'linux-image*' 2>/dev/null | awk '/^ii/{print $2, $3}' || true
fi

section "SYSTEM LOGS"

if have journalctl; then
  run_cmd "Journal disk usage" journalctl --disk-usage
fi

if [[ -d /var/log ]]; then
  safe_du_top /var/log 2
  echo
  echo "Largest files in /var/log:"
  find /var/log -type f -printf '%s\t%p\n' 2>/dev/null \
    | sort -nr | head -n 20 \
    | awk '
        function human(x) {
          s="B KB MB GB TB PB"
          split(s, arr, " ")
          i=1
          while (x >= 1024 && i < 6) { x/=1024; i++ }
          return sprintf("%.1f %s", x, arr[i])
        }
        { printf "%10s  %s\n", human($1), $2 }
      '
fi

if [[ -d /var/crash ]]; then
  echo
  echo "/var/crash usage:"
  du -sh /var/crash 2>/dev/null || true
  find /var/crash -maxdepth 1 -type f -ls 2>/dev/null || true
fi

section "SNAP"

if have snap; then
  run_cmd "Snap list --all" snap list --all
  if [[ -d /var/lib/snapd ]]; then
    safe_du_top /var/lib/snapd 2
  fi
  if [[ -d /snap ]]; then
    safe_du_top /snap 1
  fi
fi

section "DOCKER / CONTAINERS"

if have docker; then
  run_cmd "Docker disk usage" docker system df
  run_cmd "Docker images" docker image ls
  run_cmd "Docker containers" docker container ls -a
  run_cmd "Docker volumes" docker volume ls
  if [[ -d /var/lib/docker ]]; then
    safe_du_top /var/lib/docker 2
  fi
fi

if [[ -d /var/lib/containers ]]; then
  safe_du_top /var/lib/containers 2
fi

section "FLATPAK"

if have flatpak; then
  run_cmd "Flatpak list" flatpak list
  if [[ -d /var/lib/flatpak ]]; then
    safe_du_top /var/lib/flatpak 2
  fi
fi

section "USER CACHE / DOWNLOADS"

for home_dir in /home/*; do
  [[ -d "$home_dir" ]] || continue
  echo
  echo "--- User: $(basename "$home_dir") ---"
  [[ -d "$home_dir/.cache" ]] && du -sh "$home_dir/.cache" 2>/dev/null || true
  [[ -d "$home_dir/Downloads" ]] && du -sh "$home_dir/Downloads" 2>/dev/null || true
  [[ -d "$home_dir/.local/share/Trash" ]] && du -sh "$home_dir/.local/share/Trash" 2>/dev/null || true

  show_largest_files "$home_dir/.cache" "$home_dir/.cache"
  show_largest_files "$home_dir/Downloads" "$home_dir/Downloads"
done

if [[ -d "$HOME/.cache" ]]; then
  echo
  echo "Current user's top cache folders:"
  du -xhd 2 "$HOME/.cache" 2>/dev/null | human_sort_du | tail -n 25 || true
fi

section "LANGUAGE / BUILD TOOL CACHES"

for d in \
  "$HOME/.npm" \
  "$HOME/.cache/pip" \
  "$HOME/.cache/pypoetry" \
  "$HOME/.cargo" \
  "$HOME/.rustup" \
  "$HOME/go/pkg/mod" \
  "$HOME/.gradle" \
  "$HOME/.m2" \
  "$HOME/.ivy2" \
  "$HOME/.cache/yarn" \
  "$HOME/.pnpm-store" \
  "$HOME/.local/share/pnpm" \
  "$HOME/.nuget/packages"
do
  if [[ -e "$d" ]]; then
    du -sh "$d" 2>/dev/null || true
  fi
done

section "TEMPORARY DIRECTORIES"

for d in /tmp /var/tmp; do
  if [[ -d "$d" ]]; then
    du -sh "$d" 2>/dev/null || true
    echo "Old files in $d:"
    find "$d" -xdev -type f -mtime +7 -printf '%TY-%Tm-%Td %TT %10s %p\n' 2>/dev/null | head -n 25 || true
  fi
done

section "POTENTIAL SPACE HOTSPOTS SUMMARY"

cat <<'EOF'
Common Ubuntu space consumers:
- /var/log                    large or runaway logs
- /var/lib/docker             images, layers, stopped containers, volumes
- /var/lib/snapd and /snap    old snap revisions
- /var/cache/apt              cached .deb files
- /var/crash                  crash dumps
- ~/.cache                    browser, thumbnail, app caches
- ~/Downloads                 old ISOs, archives, installers
- language/build caches       npm, pip, cargo, gradle, maven, go, pnpm
- old kernels                 leftover linux-image packages
- /tmp and /var/tmp           stale temp files
EOF

recommend

section "DONE"

echo "This script made no changes."
echo "Review the output, then choose cleanup actions intentionally."
