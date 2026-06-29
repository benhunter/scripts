#!/usr/bin/env bash
set -Eeuo pipefail

ASSUME_YES=false
[[ "${1:-}" == "--yes" ]] && ASSUME_YES=true

PROJECT="$(gcloud config get-value project 2>/dev/null)"
if [[ -z "$PROJECT" || "$PROJECT" == "(unset)" ]]; then
  echo "No active Google Cloud project is configured." >&2
  exit 1
fi

mapfile -t SUBNETS < <(gcloud compute networks subnets list --format="csv[no-heading](name,region)")
if [[ ${#SUBNETS[@]} -eq 0 ]]; then
  echo "No subnets found in project $PROJECT."
  exit 0
fi

echo "Project: $PROJECT"
printf 'Subnets to update:\n'
printf '  %s\n' "${SUBNETS[@]}"
if ! $ASSUME_YES; then
  read -r -p "Enable VPC Flow Logs on every listed subnet? [y/N]: " reply
  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]] || exit 0
fi

for subnet in "${SUBNETS[@]}"; do
  IFS=, read -r name region <<< "$subnet"
  [[ -n "$name" && -n "$region" ]] || {
    echo "Malformed subnet record: $subnet" >&2
    exit 1
  }
  gcloud compute networks subnets update "$name" --region="$region" --enable-flow-logs
done
