#!/bin/bash

# Get the current directory name and remote URL
CURRENT_DIRECTORY_NAME=$(basename "$(pwd)")
CURRENT_DIRECTORY_NAME_URL_ENCODED=$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "$CURRENT_DIRECTORY_NAME")
REPO_REMOTE_URL=$(git config remote.origin.url)

# Remove trailing / from $REPO_REMOTE_URL
REPO_REMOTE_URL=${REPO_REMOTE_URL%/}

# Query GitLab API for projects matching the current directory name
PROJECTS_JSON=$(glab api "projects?search=$CURRENT_DIRECTORY_NAME_URL_ENCODED")

# Filter the JSON output to find the project with matching remote URL
PROJECT_ID=$(echo "$PROJECTS_JSON" | jq --arg REPO_REMOTE_URL "$REPO_REMOTE_URL" '.[] | select(.web_url == $REPO_REMOTE_URL or .ssh_url_to_repo == $REPO_REMOTE_URL) | .id')

# TODO remove
# PROJECT_ID=$(echo "$PROJECTS_JSON" | jq '.[] | .id')

# Check if a matching project was found
if [ -n "$PROJECT_ID" ]; then
    echo $PROJECT_ID
else
    # echo "No matching project found."
    exit 1
fi
