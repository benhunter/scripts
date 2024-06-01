#!/bin/sh

# Check if a command exists in $PATH.

COMMAND='cargo'
if ! type "$COMMAND" &> /dev/null
then
  echo "$COMMAND" not found in path
else
  echo "$COMMAND" found
fi
