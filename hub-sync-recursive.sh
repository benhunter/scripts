#!/bin/bash

# Usage: ./hub-sync-recursive.sh /path/to/directory

search_directory="$1"

if [[ -z "$search_directory" ]]; then
  echo "Please provide a directory path."
  exit 1
fi

if [[ ! -d "$search_directory" ]]; then
  echo "The provided path is not a directory."
  exit 1
fi

pull_git_repos() {
  local dir="$1"

  for item in "$dir"/*; do
    if [[ -d "$item" ]]; then
      if [[ -d "$item/.git" ]]; then
        echo -n "Syncing the Git repository in $item. "
        (cd "$item" && \
          hub sync)
        echo
      else
        pull_git_repos "$item"
      fi
    fi
  done
}

pull_git_repos "$search_directory"

