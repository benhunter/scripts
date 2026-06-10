#!/usr/bin/env zsh
set -eu

if (( $# == 0 )); then
  print -u2 "Usage: $0 user@hostname [timeout_seconds]"
  exit 1
fi

TARGET=$1
TIMEOUT=${2:-5}
if [[ "$TARGET" == -* || "$TARGET" == *[[:space:]]* ]]; then
  print -u2 "Invalid SSH target."
  exit 1
fi
if [[ "$TIMEOUT" != <-> || "$TIMEOUT" -lt 1 ]]; then
  print -u2 "Timeout must be a positive integer."
  exit 1
fi

print "Waiting for SSH connection to $TARGET..."
until ssh -o BatchMode=yes -o NumberOfPasswordPrompts=0 -o ConnectTimeout="$TIMEOUT" -- "$TARGET" true 2>/dev/null; do
  print "$(date): Not reachable, retrying in $TIMEOUT seconds..."
  sleep "$TIMEOUT"
done
print "$(date): SSH is up! Connection to $TARGET successful."
