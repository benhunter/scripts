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
        echo -n "[sync] `date +"%Y-%m-%d-%H:%M:%S"` Syncing the Git repository in $item. "
        (cd "$item" && \
          git fetch --all && \
          git branch -r | grep -v '\->' | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g" | while read remote; do git branch --track "${remote#origin/}" "$remote" 2>/dev/null; done && \
          hub sync)
        # echo
      else
        pull_git_repos "$item"
      fi
    fi
  done
}

pull_git_repos "$search_directory"

