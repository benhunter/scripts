#! /bin/zsh

echo "TODO: this script is WIP"
exit 1

usage() {
  echo "Usage: $0 <GROUP_NAME>"
}

# set -x

if [ -z "$1" ]; then # if $1 is empty
  usage
  exit 1
fi

if [ ! -d "$1" ]; then # if $1 directory does not exist
  mkdir -p "$1"
fi

# glab api groups/$1/projects | jq -r '.[].web_url' | xargs -n1 -I {} echo "git clone {} $1"
# glab api groups/$1/projects | jq -r '.[].web_url' | xargs -n1 -I {} git clone --recurse-submodules {} $1


# jq explanation:
#   -c # compact output
#   .[] # for each item in array
PROJECTS=$(glab api groups/$1/projects | jq -c ".[]")
# echo $PROJECTS
# exit 0

# echo $PROJECTS | jq -r '.[].web_url' | xargs -n1 -I {} echo "git clone --recurse-submodules {} $1"

echo $PROJECTS | while IFS= read -r PROJECT; do
  # get the project.name from jq
  PROJECT_NAME=$(echo $PROJECT | jq -r '.name')
  echo "PROJECT_NAME: $PROJECT_NAME"
  URL=$(echo $PROJECT | jq -r '.web_url')
  DIRECTORY=$1/$PROJECT_NAME
  echo "  git clone $URL $DIRECTORY"
  # git clone --recurse-submodules $URL $DIRECTORY
done

SUBGROUPS=$(glab api groups/$1/subgroups | jq -c ".[]")

echo $SUBGROUPS | while IFS= read -r GROUP; do
  echo "TODO looks like this loop breaks when newline are in the string"
  echo "GROUP: $GROUP"
  # GROUP_NAME=$(echo $GROUP | jq -r '.name')
  # echo "GROUP_NAME: $GROUP_NAME"
  echo "clone subgroups"
  gitlab-clone-group.sh $GROUP
done

