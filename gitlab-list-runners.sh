#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: gitlab-list-runners.sh [--table]

Enumerate all runners attached to a GitLab instance (admin API).

Requirements:
  - glab CLI authenticated to the target GitLab instance
  - jq for table output

Options:
  --table   Print a human-readable table instead of raw JSON
  -h, --help Show this help message

Examples:
  gitlab-list-runners.sh
  gitlab-list-runners.sh --table
EOF
}

if ! command -v glab >/dev/null 2>&1; then
  echo "Error: glab is required. Install it and run 'glab auth login'." >&2
  exit 1
fi

OUTPUT_TABLE=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --table)
      OUTPUT_TABLE=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

RUNNERS_JSON=$(glab api --paginate "runners/all")

if [ "$OUTPUT_TABLE" = true ]; then
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required for table output." >&2
    exit 1
  fi

  echo "$RUNNERS_JSON" | jq -r '.[] | [
      (.id | tostring),
      (.description // "-"),
      (.status // "-"),
      (.runner_type // "-"),
      (.active | tostring),
      (.is_shared | tostring),
      (.ip_address // "-"),
      (.contacted_at // "-")
    ] | @tsv' \
    | {
        printf "ID\tDescription\tStatus\tType\tActive\tShared\tIP\tLast Contact\n";
        cat;
      } \
    | column -t -s $'\t'
else
  echo "$RUNNERS_JSON"
fi
