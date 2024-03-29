#!/bin/bash

# Define a function to delete node_modules directories
function delete_node_modules {
    for file in "$1"/*; do
        if [ -d "$file" ]; then
            if [ "$(basename "$file")" = "build" ]; then
                echo "Deleting $file"
                rm -rf "$file"
            else
                delete_node_modules "$file"
            fi
        fi
    done
}


# Call the delete_node_modules function with the current directory as the argument
delete_node_modules "."

