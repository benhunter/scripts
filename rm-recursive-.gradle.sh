#!/bin/bash

# Define a function to delete node_modules directories
function delete_node_modules {
    shopt -s dotglob
    for file in "$1"/*; do
        if [ -d "$file" ]; then
            if [ "$(basename "$file")" = ".gradle" ]; then
                echo "Deleting $file"
                rm -rf "$file"
            else
                delete_node_modules "$file"
            fi
        fi
    done
    shopt -u dotglob
}


# Call the delete_node_modules function with the current directory as the argument
delete_node_modules "."

