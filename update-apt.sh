#!/usr/bin/env bash
set -Eeuo pipefail

ASSUME_YES=false
[[ "${1:-}" == "--yes" ]] && ASSUME_YES=true

if [[ $EUID -ne 0 ]]; then
  exec sudo -- "$0" "$@"
fi

if ! $ASSUME_YES; then
  echo "This will update package indexes, upgrade packages, run dist-upgrade,"
  echo "clean the package cache, and remove unused packages."
  read -r -p "Continue? [y/N]: " reply
  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]] || exit 0
fi

apt-get update
apt-get -y upgrade
apt-get -y dist-upgrade
apt-get clean
apt-get -y autoremove
