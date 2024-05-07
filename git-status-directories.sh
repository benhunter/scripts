#!/bin/bash

#set -x

source "$(dirname "$0")/utils.sh"

# Recursive function to traverse directories
list_git_status_recursive() {
  for dir in "$1"/*; do
        if [ -d "$dir" ]; then # Check if it is a directory
            if is_git_repository "$dir"; then
              # Check the status of the directory using Git
              git_status=$(git -C "$dir" status --porcelain 2>/dev/null)
              git_status_branch=$(git -C "$dir" status --porcelain --short --branch 2>/dev/null)
              # If there are changes, output the directory path
              if [ -n "$git_status" ]; then
                REMOTE=$(git -C "$dir" remote -v | grep "fetch" | cut -w -f2) # List remotes
                REALPATH=$(realpath "$dir")
                echo "$REALPATH > $REMOTE has changes:"
                echo $git_status_branch
                git -C "$dir" status --porcelain --short --branch 2>/dev/null
                echo
              fi
            fi
            list_git_status_recursive "$dir" # Recursively search in subdirectories
        fi
    done
}

# Start the recursive search from the current directory
list_git_status_recursive $1
