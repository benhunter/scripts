#!/bin/sh

# Currently working in project:
PROJECT=$(gcloud config get-value project)
echo "Working in project: $PROJECT"

# List all the subnets in the project
# gcloud compute networks subnets list --format="table(name,region)"

# List all subnets and their respective regions, then enable flow logs
gcloud compute networks subnets list --format="csv[no-heading](name,region)" | while IFS=, read -r name region; do
  echo "Enabling Flow Logs for subnet $name in $region..."
  gcloud compute networks subnets update $name --region=$region --enable-flow-logs
done
