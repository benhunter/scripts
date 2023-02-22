#!/bin/bash

#set -x

# Loop through each directory within the current directory
for directory in */; do
    cd "$directory"
    # Check the status of the directory using Git
    git_status=$(git status --porcelain 2>/dev/null)
    # If there are changes, output the directory path
    if [ -n "$git_status" ]; then
        echo "$directory has changes:"
	echo $git_status
	echo
    fi
    cd ..
done

