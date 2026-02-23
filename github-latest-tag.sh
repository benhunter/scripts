#!/usr/bin/env bash
# Usage:
#   ./latest-tag.sh <owner> <repo> [--prefix <prefix>] [--porcelain]
#
# Examples:
#   ./latest-tag.sh hashicorp/terraform
#   ./latest-tag.sh kubernetes/kubernetes --prefix v1.30.
#   ./latest-tag.sh torvalds/linux --porcelain
#
# Finds the latest tag (by semantic version) from a GitHub repository.
# Supports pagination, optional prefix filtering, and porcelain output.
#
# Requires:
#   - curl
#   - jq

set -euo pipefail

# --- Default flags ---
PREFIX=""
PORCELAIN=false
OWNER=""
REPO=""

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix)
      PREFIX="${2:-}"
      shift 2
      ;;
    --porcelain)
      PORCELAIN=true
      shift
      ;;
    -*)
      echo "Unknown option: $1"
      exit 1
      ;;
    *)
      if [[ -z "$OWNER" ]]; then
        OWNER="$1"
      elif [[ -z "$REPO" ]]; then
        REPO="$1"
      else
        echo "Unexpected argument: $1"
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$OWNER" || -z "$REPO" ]]; then
  echo "Usage: $0 <owner> <repo> [--prefix <prefix>] [--porcelain]"
  exit 1
fi

BASE_URL="https://api.github.com/repos/${OWNER}/${REPO}/tags"
PER_PAGE=100
PAGE=1
all_tags=""

# --- Authentication (optional) ---
AUTH_HEADER=()
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  AUTH_HEADER=(-H "Authorization: token ${GITHUB_TOKEN}")
fi

# --- Fetch all pages of tags ---
while :; do
  API_URL="${BASE_URL}?per_page=${PER_PAGE}&page=${PAGE}"
  response=$(curl -sSL "${AUTH_HEADER[@]}" "$API_URL")

  count=$(echo "$response" | jq 'length')
  if [[ "$count" -eq 0 ]]; then
    break
  fi

  page_tags=$(echo "$response" | jq -r '.[].name')
  all_tags+="$page_tags"$'\n'

  ((PAGE++))
done

# --- Clean and check ---
tags=$(echo "$all_tags" | grep -v '^$' | sort -u)

if [[ -z "$tags" ]]; then
  echo "❌ No tags found for ${OWNER}/${REPO}"
  exit 1
fi

# --- Apply prefix filter if provided ---
if [[ -n "$PREFIX" ]]; then
  tags=$(echo "$tags" | grep "^${PREFIX}" || true)
  if [[ -z "$tags" ]]; then
    echo "❌ No tags found for ${OWNER}/${REPO} with prefix '${PREFIX}'"
    exit 1
  fi
fi

# --- Sort semantically and pick latest ---
latest_tag=$(echo "$tags" | sort -V | tail -n 1)

# --- Output ---
if $PORCELAIN; then
  echo "✅ Latest tag for ${OWNER}/${REPO}: ${latest_tag}"
else
  echo "$latest_tag"
fi
