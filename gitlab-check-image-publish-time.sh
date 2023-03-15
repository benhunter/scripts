#!/bin/sh

# Example usage:
# PROJECT_ID="1234"
# TARGET_TAG="tag-name"
# check-image-publish-time.sh "$PROJECT_ID" "$TARGET_TAG"

# set -x

PROJECT_ID="$1"
TARGET_TAG="$2"
TAG_FOUND="false"
GITLAB_REGISTRY_ID=$(glab api projects/$GITLAB_PROJECT_ID/registry/repositories | jq ".[].id")
TAG_JSON=$(glab api projects/$PROJECT_ID/registry/repositories/$GITLAB_REGISTRY_ID/tags/$TARGET_TAG)

# Check if the tag exists and get its creation timestamp
CREATED_AT=$(echo "$TAG_JSON" | jq -r ". | .created_at")

if [ -n "$CREATED_AT" ]; then
    TAG_FOUND="true"
fi

# Display the result
if [ "$TAG_FOUND" = "true" ]; then
    echo "The '${TARGET_TAG}' tag was found in the container registry."

    # Calculate the time difference between the current time and the image creation time
    CURRENT_TIME=$(date -u +%s)
    # CREATED_TIME=$(date -u -d "$CREATED_AT" +%s) # doesn't work on mac
    CREATED_TIME=$(date -u -jf "%Y-%m-%dT%H:%M:%S" "${CREATED_AT%Z}" +%s)
    TIME_DIFF=$((CURRENT_TIME - CREATED_TIME))

    # Convert the time difference to a human-readable format
    TIME_DIFF_HUMAN=$(printf '%dd %dh %dm %ds' $((TIME_DIFF/86400)) $((TIME_DIFF%86400/3600)) $((TIME_DIFF%3600/60)) $((TIME_DIFF%60)))

    echo "The '${TARGET_TAG}' image was published ${TIME_DIFF_HUMAN} ago."
else
    echo "The '${TARGET_TAG}' tag was not found in the container registry."
fi
