#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  echo "Usage: $0 BASE_DIR [--dry-run] [--file PROJECTS_FILE] [--get-projects-file]"
}

[[ $# -gt 0 ]] || { usage >&2; exit 2; }
BASE_DIR="$(realpath -e -- "$1")"
shift
DRY_RUN=false
GET_PROJECTS_FILE=false
GITLAB_PROJECTS_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--dry-run) DRY_RUN=true; shift ;;
    -f|--file)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      GITLAB_PROJECTS_FILE="$2"
      shift 2
      ;;
    --get-projects-file) GET_PROJECTS_FILE=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

GITLAB_HOST="${GITLAB_HOST:-gitlab.com}"
if [[ -z "$GITLAB_PROJECTS_FILE" ]]; then
  safe_host="${GITLAB_HOST//[^A-Za-z0-9_.-]/_}"
  GITLAB_PROJECTS_FILE="GitLab-Projects-${safe_host}_$(date -u +%Y-%m-%dT%H%M).json"
  glab api projects --paginate |
    jq -s 'add | sort_by(.path_with_namespace) | .[]' -c > "$GITLAB_PROJECTS_FILE"
else
  GITLAB_PROJECTS_FILE="$(realpath -e -- "$GITLAB_PROJECTS_FILE")"
fi

$GET_PROJECTS_FILE && exit 0

while IFS= read -r project; do
  namespace="$(jq -er '.path_with_namespace | select(type == "string" and length > 0)' <<< "$project")"
  repo_url="$(jq -er '.web_url | select(type == "string" and startswith("https://"))' <<< "$project")"
  repo_path="$(realpath -m -- "$BASE_DIR/$namespace")"
  if [[ "$repo_path" != "$BASE_DIR/"* ]]; then
    echo "Refusing project path outside base directory: $namespace" >&2
    exit 1
  fi

  if $DRY_RUN; then
    printf 'Would clone %s to %s\n' "$repo_url" "$repo_path"
  else
    mkdir -p -- "$(dirname -- "$repo_path")"
    git clone --recurse-submodules -- "$repo_url" "$repo_path"
  fi
done < "$GITLAB_PROJECTS_FILE"
