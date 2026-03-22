#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: gitlab-wiki-url.sh <gitlab_project_or_group_url>

Returns the GitLab wiki clone URL for a project or group.

Environment:
  GITLAB_TOKEN  Personal access token used when glab is not available.

Examples:
  gitlab-wiki-url.sh https://gitlab.example.com/my-group/my-project
  gitlab-wiki-url.sh https://gitlab.example.com/my-group
USAGE
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ -z "${1:-}" ]; then
  usage
  exit 1
fi

input_url="$1"

parse_output=$(python3 - <<'PY' "$input_url"
import sys
from urllib.parse import urlparse

raw = sys.argv[1]
parsed = urlparse(raw)
if not parsed.scheme or not parsed.netloc:
    print("Invalid URL: missing scheme or host", file=sys.stderr)
    sys.exit(1)

path = parsed.path.strip("/")
if path.endswith(".git"):
    path = path[:-4]
path = path.strip("/")
if not path:
    print("Invalid URL: missing project or group path", file=sys.stderr)
    sys.exit(1)

print(parsed.netloc)
print(path)
PY
) || {
  usage
  exit 1
}

host=$(printf '%s' "$parse_output" | head -n 1)
path=$(printf '%s' "$parse_output" | tail -n 1)

encoded_path=$(python3 - <<'PY' "$path"
import sys
from urllib.parse import quote

print(quote(sys.argv[1], safe=""))
PY
)

base_api="https://${host}/api/v4"
use_glab=false
if command -v glab >/dev/null 2>&1; then
  use_glab=true
fi

API_STATUS=""
API_BODY_FILE=""

cleanup() {
  if [ -n "${API_BODY_FILE:-}" ] && [ -f "$API_BODY_FILE" ]; then
    rm -f "$API_BODY_FILE"
  fi
}
trap cleanup EXIT

api_get() {
  local endpoint="$1"
  API_BODY_FILE=$(mktemp)
  if $use_glab; then
    local output
    output=$(glab api --hostname "$host" -i "$endpoint" 2>&1 || true)
    API_STATUS=$(printf '%s\n' "$output" | awk 'NR==1 {print $2}')
    if [ -z "$API_STATUS" ]; then
      printf '%s\n' "$output" >&2
      return 1
    fi
    printf '%s\n' "$output" | awk 'BEGIN{header=1} header==1 && $0=="" {header=0; next} header==0 {print}' >"$API_BODY_FILE"
    return 0
  fi

  if [ -z "${GITLAB_TOKEN:-}" ]; then
    echo "GITLAB_TOKEN is required when glab is not available." >&2
    return 1
  fi

  local response
  response=$(curl -sS -D - -H "PRIVATE-TOKEN: ${GITLAB_TOKEN}" "${base_api}/${endpoint}" || true)
  API_STATUS=$(printf '%s\n' "$response" | awk 'NR==1 {print $2}')
  if [ -z "$API_STATUS" ]; then
    printf '%s\n' "$response" >&2
    return 1
  fi
  printf '%s\n' "$response" | awk 'BEGIN{header=1} header==1 && $0=="" {header=0; next} header==0 {print}' >"$API_BODY_FILE"
  return 0
}

project_wiki_url() {
  local repo_url="$1"
  if [[ "$repo_url" == *.git ]]; then
    printf '%s' "${repo_url%.git}.wiki.git"
    return 0
  fi
  printf '%s.wiki.git' "$repo_url"
}

if ! api_get "projects/${encoded_path}"; then
  echo "Failed to query GitLab API for project." >&2
  exit 1
fi

if [ "$API_STATUS" = "200" ]; then
  project_info=$(python3 - <<'PY' "$API_BODY_FILE"
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)

print("true" if data.get("wiki_enabled") else "false")
print(data.get("http_url_to_repo", ""))
print(data.get("ssh_url_to_repo", ""))
PY
)
  wiki_enabled=$(printf '%s' "$project_info" | head -n 1)
  http_repo=$(printf '%s' "$project_info" | sed -n '2p')
  ssh_repo=$(printf '%s' "$project_info" | sed -n '3p')

  if [ "$wiki_enabled" != "true" ]; then
    echo "Project wiki is disabled." >&2
    exit 2
  fi

  repo_url="$http_repo"
  if [ -z "$repo_url" ]; then
    repo_url="$ssh_repo"
  fi

  if [ -z "$repo_url" ]; then
    echo "Project repository URL not available from API." >&2
    exit 1
  fi

  project_wiki_url "$repo_url"
  echo
  exit 0
fi

if [ "$API_STATUS" != "404" ]; then
  echo "Unexpected response when looking up project (status $API_STATUS)." >&2
  exit 1
fi

if ! api_get "groups/${encoded_path}"; then
  echo "Failed to query GitLab API for group." >&2
  exit 1
fi

if [ "$API_STATUS" = "404" ]; then
  echo "No project or group found for path: $path" >&2
  exit 1
fi

if [ "$API_STATUS" != "200" ]; then
  echo "Unexpected response when looking up group (status $API_STATUS)." >&2
  exit 1
fi

group_info=$(python3 - <<'PY' "$API_BODY_FILE"
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)

print(data.get("id", ""))
print(data.get("web_url", ""))
PY
)

group_id=$(printf '%s' "$group_info" | head -n 1)
group_web_url=$(printf '%s' "$group_info" | tail -n 1)

if [ -z "$group_id" ] || [ -z "$group_web_url" ]; then
  echo "Group information missing from API response." >&2
  exit 1
fi

if ! api_get "groups/${group_id}/wikis"; then
  echo "Failed to query GitLab API for group wiki." >&2
  exit 1
fi

if [ "$API_STATUS" = "404" ]; then
  echo "Group wiki does not exist." >&2
  exit 2
fi

if [ "$API_STATUS" != "200" ]; then
  echo "Unexpected response when looking up group wiki (status $API_STATUS)." >&2
  exit 1
fi

group_web_url=${group_web_url%/}
printf '%s.wiki.git\n' "$group_web_url"
