#!/usr/bin/env bash
set -Eeuo pipefail
[[ $# -gt 0 ]] || { echo "Usage: $0 IMAGE [docker-run-args...]" >&2; exit 2; }
docker run -it --entrypoint /bin/sh --rm "$@"
