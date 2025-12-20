#!/bin/zsh

# Script to wait until an SSH server is reachable
# Usage: ssh-wait.sh user@hostname [timeout_seconds]

if [ $# -eq 0 ]; then
    echo "Usage: $0 user@hostname [timeout_seconds]"
    echo "Example: $0 user@example.com 5"
    exit 1
fi

TARGET=$1
TIMEOUT=${2:-5}

echo "Waiting for SSH connection to $TARGET..."

until ssh -o ConnectTimeout=$TIMEOUT "$TARGET" true 2>/dev/null; do
    print "$(date): Not reachable, retrying in $TIMEOUT seconds..."
    sleep $TIMEOUT
done

print "$(date): SSH is up! Connection to $TARGET successful."
