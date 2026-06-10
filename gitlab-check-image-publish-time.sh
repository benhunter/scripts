#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_ID="${1:-}"
TARGET_TAG="${2:-}"
[[ "$PROJECT_ID" =~ ^[0-9]+$ && -n "$TARGET_TAG" && "$TARGET_TAG" != -* ]] || {
  echo "Usage: $0 PROJECT_ID TAG" >&2
  exit 2
}

mapfile -t REGISTRY_IDS < <(glab api "projects/$PROJECT_ID/registry/repositories" | jq -er '.[].id')
if [[ ${#REGISTRY_IDS[@]} -ne 1 || ! "${REGISTRY_IDS[0]}" =~ ^[0-9]+$ ]]; then
  echo "Expected exactly one container registry repository." >&2
  exit 1
fi

ENCODED_TAG="$(jq -rn --arg value "$TARGET_TAG" '$value|@uri')"
TAG_JSON="$(glab api "projects/$PROJECT_ID/registry/repositories/${REGISTRY_IDS[0]}/tags/$ENCODED_TAG")"
CREATED_AT="$(jq -er '.created_at' <<< "$TAG_JSON")"

if date --version >/dev/null 2>&1; then
  CREATED_TIME="$(date -u -d "$CREATED_AT" +%s)"
else
  CREATED_TIME="$(date -u -jf "%Y-%m-%dT%H:%M:%S" "${CREATED_AT%Z}" +%s)"
fi
CURRENT_TIME="$(date -u +%s)"
TIME_DIFF=$((CURRENT_TIME - CREATED_TIME))
printf 'Tag %s published %dd %dh %dm %ds ago.\n' "$TARGET_TAG" \
  $((TIME_DIFF / 86400)) $((TIME_DIFF % 86400 / 3600)) \
  $((TIME_DIFF % 3600 / 60)) $((TIME_DIFF % 60))
