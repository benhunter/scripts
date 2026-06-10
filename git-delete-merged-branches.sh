#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

branch_file="$(mktemp "${TMPDIR:-/tmp}/merged-branches.XXXXXX")"
trap 'rm -f -- "$branch_file"' EXIT

git branch --format='%(refname:short)' --merged |
  grep -Ev '^(main|master)$' > "$branch_file" || true

if [[ ! -s "$branch_file" ]]; then
  echo "No merged branches found."
  exit 0
fi

"${EDITOR:-nvim}" "$branch_file"
while IFS= read -r branch; do
  [[ -n "$branch" && "$branch" != -* ]] || continue
  git branch -d -- "$branch"
done < "$branch_file"
