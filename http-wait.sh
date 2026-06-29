#!/bin/zsh

# Wait until an HTTP or HTTPS URL is reachable.
# Usage: http-wait.sh URL [timeout_seconds]

if [ $# -eq 0 ]; then
    echo "Usage: $0 URL [timeout_seconds]"
    echo "Example: $0 https://example.com/health 5"
    exit 1
fi

URL=$1
TIMEOUT=${2:-5}

if [[ "$URL" != http://* && "$URL" != https://* ]]; then
    print -u2 "URL must start with http:// or https://"
    exit 1
fi
if [[ "$TIMEOUT" != <-> || "$TIMEOUT" -lt 1 ]]; then
    print -u2 "Timeout must be a positive integer"
    exit 1
fi
if [[ "$URL" == http://* ]]; then
    print -u2 "Warning: plain HTTP does not authenticate or encrypt the endpoint."
fi

echo "Waiting for HTTP connection to $URL..."

until curl --fail --silent --show-error --connect-timeout "$TIMEOUT" --max-time "$TIMEOUT" "$URL" >/dev/null 2>&1; do
    print "$(date): Not reachable, retrying in $TIMEOUT seconds..."
    sleep "$TIMEOUT"
done

print "$(date): HTTP server is up! Connection to $URL successful."
