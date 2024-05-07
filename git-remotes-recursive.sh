#!/bin/bash

source "$(dirname "$0")/utils.sh"

# Recursive function to traverse directories
git_remotes_recursive() {
    for dir in "$1"/*; do
        if [ -d "$dir" ]; then # Check if it is a directory
            if is_git_repository "$dir"; then
                REMOTE=$(git -C "$dir" remote -v | grep "fetch" | cut -w -f2) # List remotes
                REALPATH=$(realpath "$dir")
                echo "$REALPATH > $REMOTE"
            fi
            git_remotes_recursive "$dir" # Recursively search in subdirectories
        fi
    done
}

# Start the recursive search from the current directory
git_remotes_recursive .
