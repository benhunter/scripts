#! /bin/zsh

usage() {
  echo "Usage: ./clone-all-gitlab-projects.sh <BASE_DIR> [-d|--dry-run] [-f|--file GITLAB_PROJECTS_FILE]"
}

# set -x

# BASE_DIR="./tmp"
BASE_DIR=$1
DRY_RUN=false

POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--dry-run)
      DRY_RUN=true
      shift # past value
      ;;
    -f|--file)
      GITLAB_PROJECTS_FILE="$2"
      shift # past argument
      shift # past value
      ;;
    -*|--*)
      usage
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done
set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

if [ "$DRY_RUN" = true ]; then
  echo "Dry run enabled"
fi

echo "BASE_DIR: $BASE_DIR"
echo "GITLAB_HOST: $GITLAB_HOST"

if [ -z "$GITLAB_PROJECTS_FILE" ]; then
  GITLAB_PROJECTS_FILE="GitLab-Projects-$GITLAB_HOST_$(date -u +%Y-%m-%dT%H%M).json"
  echo "Getting projects from GitLab API..."
  glab api projects --paginate | jq -s "add" | jq -c "sort_by(.path_with_namespace) | .[]" > $GITLAB_PROJECTS_FILE
else
  echo "GITLAB_PROJECTS_FILE set to $GITLAB_PROJECTS_FILE"
fi

echo "Found $(cat $GITLAB_PROJECTS_FILE| wc -l | awk '{print $1}') projects from GitLab."


cat $GITLAB_PROJECTS_FILE | while IFS= read -r LINE; do
  CLEAN_LINE=$(echo $LINE | tr -d '\r\n')
  # CLEAN_LINE=$(echo $LINE | sed 's/\n//g' | sed 's/\r//g')
  
  REPO_PATH=$BASE_DIR/$(echo $CLEAN_LINE | jq -r .path_with_namespace)
  REPO_URL=$(echo $CLEAN_LINE | jq -r .web_url)

  if [ "$DRY_RUN" = true ]; then
    echo "Would have cloned: $REPO_URL to: $REPO_PATH"
    continue
  fi
  echo $REPO_PATH $REPO_URL

  git clone --recurse-submodules $REPO_URL $REPO_PATH
  echo
done
