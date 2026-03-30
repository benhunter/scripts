#!/usr/bin/env bash
set -Eeuo pipefail

# safe-cleanup.sh
#
# Interactive cleanup helper for Ubuntu/Linux developer systems.
# Targets:
# - apt
# - Homebrew/Linuxbrew
# - Cargo/Rust
# - pnpm/npm
# - pip
# - Go
# - Gradle/Maven
# - systemd journals
# - /tmp and /var/tmp
# - user cache
#
# Non-default behavior:
# - This script DOES delete files, but only after explicit prompts.
# - No action runs automatically without confirmation.
#
# Usage:
#   chmod +x safe-cleanup.sh
#   ./safe-cleanup.sh
#   sudo ./safe-cleanup.sh   # recommended for apt/journal/tmp cleanup visibility

PATH=/usr/sbin:/usr/bin:/sbin:/bin

DIVIDER="===================================================================="

say() {
  echo
  echo "$DIVIDER"
  echo "$1"
  echo "$DIVIDER"
}

info() {
  echo "[INFO] $*"
}

warn() {
  echo "[WARN] $*"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

confirm() {
  local prompt="$1"
  local reply
  read -r -p "$prompt [y/N]: " reply
  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

run_cmd() {
  echo
  echo "+ $*"
  "$@"
}

safe_du() {
  du -sh "$@" 2>/dev/null || true
}

show_path_size() {
  local p="$1"
  [[ -e "$p" ]] || return 0
  safe_du "$p"
}

maybe_run() {
  local description="$1"
  shift
  echo
  info "$description"
  echo "Command:"
  printf '  %q' "$@"
  echo
  if confirm "Run this command?"; then
    "$@"
    echo
    info "Completed."
  else
    info "Skipped."
  fi
}

cleanup_apt() {
  have apt || return 0

  say "APT cleanup"

  info "APT cache directories:"
  show_path_size /var/cache/apt
  show_path_size /var/lib/apt

  maybe_run \
    "Remove outdated cached .deb packages only (safe)." \
    sudo apt autoclean

  maybe_run \
    "Remove unused dependencies no longer required." \
    sudo apt autoremove

  if confirm "Also remove ALL cached .deb packages with 'apt clean'?"; then
    run_cmd sudo apt clean
  else
    info "Skipped apt clean."
  fi
}

cleanup_homebrew() {
  have brew || return 0

  say "Homebrew cleanup"

  local brew_cache
  brew_cache="$(brew --cache 2>/dev/null || true)"

  info "Dry run:"
  run_cmd brew cleanup -n || true

  [[ -n "$brew_cache" ]] && info "Homebrew cache path: $brew_cache"
  [[ -n "$brew_cache" ]] && show_path_size "$brew_cache"

  maybe_run \
    "Remove old Homebrew downloads and old versions." \
    brew cleanup

  if [[ -n "$brew_cache" ]]; then
    if confirm "Delete the full Homebrew download cache directory?"; then
      run_cmd rm -rf -- "$brew_cache"
    else
      info "Skipped deleting Homebrew cache directory."
    fi
  fi
}

cleanup_cargo_global() {
  say "Cargo / Rust cleanup"

  show_path_size "$HOME/.cargo"
  show_path_size "$HOME/.rustup"

  if have cargo-cache; then
    info "cargo-cache detected."
    maybe_run \
      "Clean Cargo global caches with cargo-cache." \
      cargo cache -a
  else
    warn "cargo-cache not installed. Manual cache cleanup options follow."
    show_path_size "$HOME/.cargo/registry/cache"
    show_path_size "$HOME/.cargo/git/checkouts"

    if confirm "Delete ~/.cargo/registry/cache ?"; then
      run_cmd rm -rf -- "$HOME/.cargo/registry/cache"
    else
      info "Skipped ~/.cargo/registry/cache"
    fi

    if confirm "Delete ~/.cargo/git/checkouts ?"; then
      run_cmd rm -rf -- "$HOME/.cargo/git/checkouts"
    else
      info "Skipped ~/.cargo/git/checkouts"
    fi
  fi
}

cleanup_cargo_targets() {
  say "Cargo target/ directory cleanup"

  info "Searching below current directory for Rust target directories."
  mapfile -t targets < <(find . -type d -name target -prune 2>/dev/null | sort)

  if [[ ${#targets[@]} -eq 0 ]]; then
    info "No target directories found under current directory."
    return 0
  fi

  echo
  info "Found target directories:"
  for t in "${targets[@]}"; do
    safe_du "$t"
  done

  echo
  warn "Deleting a target directory removes build artifacts only."
  warn "It does not remove source code, but rebuilds will take longer later."

  for t in "${targets[@]}"; do
    if confirm "Delete Rust build directory '$t'?"; then
      run_cmd rm -rf -- "$t"
    else
      info "Skipped $t"
    fi
  done
}

cleanup_pnpm() {
  have pnpm || return 0

  say "pnpm cleanup"

  info "pnpm store path:"
  local store_path
  store_path="$(pnpm store path 2>/dev/null || true)"
  [[ -n "$store_path" ]] && echo "  $store_path"
  [[ -n "$store_path" ]] && show_path_size "$store_path"

  maybe_run \
    "Prune unreferenced packages from pnpm store." \
    pnpm store prune
}

cleanup_node_modules() {
  say "node_modules cleanup"

  info "Searching below current directory for node_modules directories."
  mapfile -t modules < <(find . -type d -name node_modules -prune 2>/dev/null | sort)

  if [[ ${#modules[@]} -eq 0 ]]; then
    info "No node_modules directories found under current directory."
    return 0
  fi

  echo
  info "Found node_modules directories:"
  for m in "${modules[@]}"; do
    safe_du "$m"
  done

  warn "Deleting node_modules removes installed dependencies only."
  warn "Projects will need 'pnpm install' or equivalent later."

  for m in "${modules[@]}"; do
    if confirm "Delete '$m'?"; then
      run_cmd rm -rf -- "$m"
    else
      info "Skipped $m"
    fi
  done
}

cleanup_npm_cache() {
  have npm || return 0

  say "npm cache cleanup"

  maybe_run \
    "Clear npm cache." \
    npm cache clean --force
}

cleanup_pip() {
  have pip || have pip3 || return 0

  say "pip cache cleanup"

  if have pip; then
    run_cmd pip cache info || true
    maybe_run \
      "Purge pip cache." \
      pip cache purge
  elif have pip3; then
    run_cmd pip3 cache info || true
    maybe_run \
      "Purge pip3 cache." \
      pip3 cache purge
  fi
}

cleanup_go() {
  have go || return 0

  say "Go module cache cleanup"

  show_path_size "$HOME/go/pkg/mod"

  maybe_run \
    "Remove downloaded Go module cache." \
    go clean -modcache
}

cleanup_gradle() {
  [[ -d "$HOME/.gradle/caches" ]] || return 0

  say "Gradle cache cleanup"

  show_path_size "$HOME/.gradle/caches"

  if confirm "Delete ~/.gradle/caches ?"; then
    run_cmd rm -rf -- "$HOME/.gradle/caches"
  else
    info "Skipped Gradle caches."
  fi
}

cleanup_maven() {
  [[ -d "$HOME/.m2/repository" ]] || return 0

  say "Maven repository cleanup"

  show_path_size "$HOME/.m2/repository"

  warn "Deleting ~/.m2/repository removes downloaded Maven artifacts."
  warn "They will be re-downloaded on next build."

  if confirm "Delete ~/.m2/repository ?"; then
    run_cmd rm -rf -- "$HOME/.m2/repository"
  else
    info "Skipped Maven repository."
  fi
}

cleanup_journal() {
  have journalctl || return 0

  say "systemd journal cleanup"

  run_cmd journalctl --disk-usage || true

  if confirm "Vacuum journals older than 7 days?"; then
    run_cmd sudo journalctl --vacuum-time=7d
  else
    info "Skipped time-based journal vacuum."
  fi

  if confirm "Vacuum journals down to 200M?"; then
    run_cmd sudo journalctl --vacuum-size=200M
  else
    info "Skipped size-based journal vacuum."
  fi
}

cleanup_tmp() {
  say "/tmp and /var/tmp cleanup"

  show_path_size /tmp
  show_path_size /var/tmp

  info "Sample old files in /tmp:"
  find /tmp -xdev -type f -mtime +7 -printf '%TY-%Tm-%Td %TT %p\n' 2>/dev/null | head -n 20 || true

  info "Sample old files in /var/tmp:"
  find /var/tmp -xdev -type f -mtime +30 -printf '%TY-%Tm-%Td %TT %p\n' 2>/dev/null | head -n 20 || true

  if confirm "Delete files in /tmp older than 7 days?"; then
    run_cmd sudo find /tmp -xdev -type f -mtime +7 -delete
  else
    info "Skipped /tmp old-file cleanup."
  fi

  if confirm "Delete files in /var/tmp older than 30 days?"; then
    run_cmd sudo find /var/tmp -xdev -type f -mtime +30 -delete
  else
    info "Skipped /var/tmp old-file cleanup."
  fi
}

cleanup_user_cache() {
  [[ -d "$HOME/.cache" ]] || return 0

  say "User cache cleanup"

  show_path_size "$HOME/.cache"

  info "Largest entries in ~/.cache:"
  du -sh "$HOME/.cache"/* 2>/dev/null | sort -h | tail -n 30 || true

  if [[ -d "$HOME/.cache/thumbnails" ]]; then
    if confirm "Delete thumbnail cache (~/.cache/thumbnails/*)?"; then
      run_cmd rm -rf -- "$HOME/.cache/thumbnails/"*
    else
      info "Skipped thumbnail cache cleanup."
    fi
  fi

  warn "Deleting all of ~/.cache can sign you out of apps or remove local app caches."
  if confirm "Delete ALL contents of ~/.cache ?"; then
    run_cmd find "$HOME/.cache" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
  else
    info "Skipped full ~/.cache cleanup."
  fi
}

cleanup_trash() {
  local trash="$HOME/.local/share/Trash"
  [[ -d "$trash" ]] || return 0

  say "User trash cleanup"

  show_path_size "$trash"

  if confirm "Empty user trash at $trash ?"; then
    run_cmd find "$trash" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
  else
    info "Skipped trash cleanup."
  fi
}

summary_before() {
  say "Initial disk usage"
  run_cmd df -h
}

summary_after() {
  say "Final disk usage"
  run_cmd df -h
}

main_menu() {
  say "Safe cleanup helper"

  cat <<'EOF'
This script is interactive and asks before every cleanup action.

Recommended usage:
- Run from your home directory or a parent directory containing your repos.
- Use sudo if you want apt/journal/tmp cleanup to work cleanly.

Sections:
  1) apt
  2) Homebrew
  3) Cargo global cache
  4) Cargo target/ directories under current directory
  5) pnpm store
  6) node_modules under current directory
  7) npm cache
  8) pip cache
  9) Go module cache
 10) Gradle cache
 11) Maven repository
 12) systemd journals
 13) /tmp and /var/tmp old files
 14) ~/.cache
 15) Trash

EOF
}

main() {
  main_menu
  summary_before

  if confirm "Run apt cleanup section?"; then cleanup_apt; fi
  if confirm "Run Homebrew cleanup section?"; then cleanup_homebrew; fi
  if confirm "Run Cargo global cache cleanup section?"; then cleanup_cargo_global; fi
  if confirm "Run Cargo target directory cleanup section (searches under current directory)?"; then cleanup_cargo_targets; fi
  if confirm "Run pnpm cleanup section?"; then cleanup_pnpm; fi
  if confirm "Run node_modules cleanup section (searches under current directory)?"; then cleanup_node_modules; fi
  if confirm "Run npm cache cleanup section?"; then cleanup_npm_cache; fi
  if confirm "Run pip cache cleanup section?"; then cleanup_pip; fi
  if confirm "Run Go cleanup section?"; then cleanup_go; fi
  if confirm "Run Gradle cleanup section?"; then cleanup_gradle; fi
  if confirm "Run Maven cleanup section?"; then cleanup_maven; fi
  if confirm "Run systemd journal cleanup section?"; then cleanup_journal; fi
  if confirm "Run /tmp and /var/tmp cleanup section?"; then cleanup_tmp; fi
  if confirm "Run ~/.cache cleanup section?"; then cleanup_user_cache; fi
  if confirm "Run Trash cleanup section?"; then cleanup_trash; fi

  summary_after

  say "Done"
  info "Cleanup finished."
}

main "$@"

