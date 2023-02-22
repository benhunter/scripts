#!/bin/bash

#set -x

# Loop through each directory within the current directory
for directory in */; do
    cd "$directory"
    # Check the status of the directory using Git
    git_status=$(git status --porcelain)
    # If there are changes, output the directory path
    if [ -n "$git_status" ]; then
        echo "$directory has changes: $git_status"
    fi
    cd ..
done

