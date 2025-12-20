#!/bin/zsh

# Script to wait until an HTTP server is reachable on port 80
# Usage: http-wait.sh hostname [timeout_seconds]

if [ $# -eq 0 ]; then
    echo "Usage: $0 hostname [timeout_seconds]"
    echo "Example: $0 example.com 5"
    exit 1
fi

TARGET=$1
TIMEOUT=${2:-5}
URL="http://$TARGET"

echo "Waiting for HTTP connection to $URL..."

until curl -s --connect-timeout $TIMEOUT --max-time $TIMEOUT "$URL" >/dev/null 2>&1; do
    print "$(date): Not reachable, retrying in $TIMEOUT seconds..."
    sleep $TIMEOUT
done

print "$(date): HTTP server is up! Connection to $URL successful."
