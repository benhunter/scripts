#! /bin/zsh

usage() {
  echo "Usage: ./gitlab-clone-projects-recursive.sh <BASE_DIR> [-d|--dry-run] [-f|--file GITLAB_PROJECTS_FILE] --get-projects-file"
}

should_skip() {
  local REPO=$1
  local -n SKIP_STRINGS=$2

  for SKIP_STRING in "${SKIP_STRINGS[@]}"; do
    if [[ $REPO == *"$SKIP_STRING"* ]]; then
      echo "Skipping $REPO because it contains: $SKIP_STRING"
      return 0  # Skip
    fi
  done
  return 1  # Do not skip
}

# set -x

if [ -z "$1" ]; then # if $1 is empty
  usage
  exit 1
fi

if [ ! -d "$1" ]; then # if $1 directory does not exist
  echo "Directory $1 does not exist."
  exit 1
fi

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
    --get-projects-file)
      GET_PROJECTS_FILE=true
      shift # past argument
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

SKIP_STRINGS=("substring1"
              "substring2")

if [ -z "$GITLAB_PROJECTS_FILE" ]; then
  GITLAB_PROJECTS_FILE="GitLab-Projects-$GITLAB_HOST_$(date -u +%Y-%m-%dT%H%M).json"
  echo "Getting projects from GitLab API..."
  glab api projects --paginate | jq -s "add" | jq -c "sort_by(.path_with_namespace) | .[]" > $GITLAB_PROJECTS_FILE
else
  echo "GITLAB_PROJECTS_FILE set to $GITLAB_PROJECTS_FILE"
fi

if [ "$GET_PROJECTS_FILE" = true ]; then
  echo "Exiting after getting projects file."
  exit 0
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

  # Check if REPO_PATH includes any of the skip strings and skip it if so
  if should_skip "$REPO_PATH" SKIP_STRINGS; then
    continue
  fi

  echo $REPO_PATH $REPO_URL
  git clone --recurse-submodules $REPO_URL $REPO_PATH
  echo
done
