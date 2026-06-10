#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ID="$("$SCRIPT_DIR/gitlab-get-project-id-from-current-repo.sh")"
[[ "$PROJECT_ID" =~ ^[0-9]+$ ]] || { echo "Invalid project ID." >&2; exit 1; }

mapfile -t REGISTRY_IDS < <(glab api "projects/$PROJECT_ID/registry/repositories" | jq -er '.[].id')
if [[ ${#REGISTRY_IDS[@]} -ne 1 || ! "${REGISTRY_IDS[0]}" =~ ^[0-9]+$ ]]; then
  echo "Expected exactly one container registry repository." >&2
  exit 1
fi

mapfile -t TAGS < <(
  glab api "projects/$PROJECT_ID/registry/repositories/${REGISTRY_IDS[0]}/tags" |
    jq -er '.[].name'
)
printf 'Found tags:\n'
printf '  %s\n' "${TAGS[@]}"
for tag in "${TAGS[@]}"; do
  "$SCRIPT_DIR/gitlab-check-image-publish-time.sh" "$PROJECT_ID" "$tag"
done
