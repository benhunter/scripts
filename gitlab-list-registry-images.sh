

PROJECT_ID=$(gitlab-get-project-id-from-current-repo.sh)
REGISTRY_ID=$(glab api "projects/$PROJECT_ID/registry/repositories" | jq '.[] | .id')
TAGS=$(glab api "projects/$PROJECT_ID/registry/repositories/$REGISTRY_ID/tags" | jq -r '.[] | .name')

echo "Found tags:"
echo $TAGS

for tag in $TAGS; do
  # Remove quotes using parameter expansion
  tag="${tag%\"}"
  tag="${tag#\"}"

  gitlab-check-image-publish-time.sh $PROJECT_ID $tag
done
