#!/usr/bin/env bash
# Usage: ./github-latest-release.sh <owner> <repo>
# Example: ./github-latest-release.sh kubernetes kubernetes
#
# Requires: 
#   - curl
#   - jq

set -euo pipefail

OWNER="${1:-}"
REPO="${2:-}"

if [[ -z "$OWNER" || -z "$REPO" ]]; then
  echo "Usage: $0 <owner> <repo>"
  exit 1
fi

API_URL="https://api.github.com/repos/${OWNER}/${REPO}/releases/latest"

# Fetch the latest release data (silently)
response=$(curl -sSL "$API_URL")

# Extract the release tag name (e.g., v1.30.1)
tag_name=$(echo "$response" | jq -r '.tag_name // empty')

if [[ -z "$tag_name" ]]; then
  echo "❌ No release found for ${OWNER}/${REPO}"
  exit 1
fi

echo "✅ Latest release for ${OWNER}/${REPO}: ${tag_name}"
