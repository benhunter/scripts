#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_NAME="postgres-data"
ASSUME_YES=false
ROOT="."

usage() {
  echo "Usage: $0 [--yes] [root]"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) ASSUME_YES=true ;;
    -h|--help) usage; exit 0 ;;
    -*) usage >&2; exit 2 ;;
    *) ROOT="$1" ;;
  esac
  shift
done

ROOT="$(realpath -e -- "$ROOT")"
if [[ "$ROOT" == "/" ]]; then
  echo "Refusing to search from the filesystem root." >&2
  exit 1
fi

mapfile -d '' MATCHES < <(find -P "$ROOT" -type d -name "$TARGET_NAME" -prune -print0)
if [[ ${#MATCHES[@]} -eq 0 ]]; then
  echo "No $TARGET_NAME directories found under $ROOT."
  exit 0
fi

printf 'Directories to delete:\n'
printf '  %s\n' "${MATCHES[@]}"
if ! $ASSUME_YES; then
  read -r -p "Delete these directories? [y/N]: " reply
  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]] || exit 0
fi

for path in "${MATCHES[@]}"; do
  [[ "$path" == "$ROOT/"* && ! -L "$path" ]] || {
    echo "Refusing unsafe path: $path" >&2
    exit 1
  }
  rm -rf -- "$path"
done
