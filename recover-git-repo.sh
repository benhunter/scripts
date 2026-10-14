#!/usr/bin/env bash
# Recover zero-byte loose Git objects without changing the worktree or refs.
#
# Usage: recover-git-repo.sh [--yes] REPOSITORY [REMOTE]
# Example (Oh My Zsh, using origin):
#   ./recover-git-repo.sh ~/.oh-my-zsh
#
# Requires Bash and Git. REMOTE defaults to origin and can be a configured
# remote name or a clone URL/path. --yes skips the confirmation prompt.
# Stop other Git operations and file writes before running. Allow enough disk
# space for a full backup plus a mirror clone of the remote.
#
# Recovery process:
#   1. Create git-recovery.XXXXXXXX beside the repository and back up the entire
#      repository, including working files and Git metadata.
#   2. Run git fsck --full; exit without repairs if the integrity check passes.
#   3. Clone the remote and verify every empty object's replacement is available
#      before modifying the original repository's object database.
#   4. Install healthy pack files and move empty loose objects into quarantine.
#   5. Rerun the integrity check and report local changes.
# Working files, the index, and branch references are preserved. The script
# does not reset files, change branches, or automatically pull/update.
#
# Limitations and follow-up:
# Only ordinary, non-bare repository roots with their own .git directory are
# supported; linked worktrees and alternate object stores are rejected.
# This is not a general corruption repair tool: nonempty corrupt objects or
# objects absent from the remote may require separate recovery.
# If verification fails, inspect the logs in the recovery directory before
# attempting an update. Keep that directory, including its backup and
# quarantined objects, until normal operation is confirmed.
set -Eeuo pipefail

usage() {
  printf '%s\n' \
    'Usage: recover-git-repo.sh [--yes] REPOSITORY [REMOTE]' \
    '' \
    'REMOTE is a configured remote name (default: origin) or a clone URL/path.' \
    'Supports ordinary, non-bare repositories with their own .git directory.' \
    'Creates a full backup beside the repository before attempting repairs.' \
    'Does not repair nonempty corrupt objects, reset files, or update branches.' \
    'Stop other Git operations and editors that write files before running.'
}
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

auto_yes=false
if [[ ${1:-} == --help || ${1:-} == -h ]]; then usage; exit 0; fi
if [[ ${1:-} == --yes ]]; then auto_yes=true; shift; fi
[[ $# -ge 1 && $# -le 2 ]] || { usage >&2; exit 2; }
command -v git >/dev/null || die 'git is required.'
repo=$(cd -- "$1" && pwd -P) || die 'Cannot access repository.'
[[ -d "$repo/.git" && ! -L "$repo/.git" ]] ||
  die 'Expected a repository root with a real .git directory (not bare or linked worktree).'

# Ambient Git variables could redirect operations to another repository.
for name in $(compgen -e); do
  case "$name" in
    GIT_DIR|GIT_WORK_TREE|GIT_COMMON_DIR|GIT_INDEX_FILE|GIT_OBJECT_DIRECTORY|GIT_ALTERNATE_OBJECT_DIRECTORIES|GIT_NAMESPACE|GIT_SHALLOW_FILE)
      die "Unset $name before running this script." ;;
  esac
done
[[ ! -e "$repo/.git/objects/info/alternates" ]] || die 'Repositories using alternate object stores are not supported.'
[[ ! -d "$repo/.git/worktrees" ]] || die 'Repositories with linked worktrees are not supported.'
[[ -z $(find "$repo/.git" -name '*.lock' -print -quit) ]] || die 'Git lock file found; investigate before proceeding.'

git -C "$repo" rev-parse --git-dir >/dev/null || die 'Not a recognizable Git repository.'
remote=${2:-origin}
if url=$(git -C "$repo" remote get-url "$remote" 2>/dev/null); then
  remote=$url
fi
printf 'Repository: %s\nA full backup will be created beside it.\n' "$repo"
if ! "$auto_yes"; then
  read -r -p 'Have you stopped other writes, and should recovery proceed? [y/N] ' answer
  [[ $answer == y || $answer == Y ]] || die 'Cancelled.'
fi

recovery=$(mktemp -d "$(dirname "$repo")/git-recovery.XXXXXXXX")
trap 'rc=$?; printf "Recovery stopped (exit %s). Backup/logs: %s\n" "$rc" "$recovery" >&2; exit "$rc"' ERR
printf 'Recovery directory: %s\n' "$recovery"
printf 'Backing up the entire repository...\n'
cp -a -- "$repo" "$recovery/backup"

printf 'Checking original object database...\n'
if git -C "$repo" fsck --full >"$recovery/fsck-before.log" 2>&1; then
  printf 'Integrity check passed; no repair needed. Backup: %s\n' "$recovery"
  exit 0
fi

objects="$repo/.git/objects"
empty=()
while IFS= read -r -d '' file; do
  relative=${file#"$objects/"}
  # Only loose object paths, never pack files or metadata.
  if [[ $relative =~ ^[0-9a-f]{2}/[0-9a-f]{38}$ || $relative =~ ^[0-9a-f]{2}/[0-9a-f]{62}$ ]]; then
    empty+=("$relative")
  fi
done < <(find "$objects" -mindepth 2 -maxdepth 2 -type f -empty -print0)
[[ ${#empty[@]} -gt 0 ]] || die "No empty loose objects found. See $recovery/fsck-before.log; no repair attempted."
printf '%s\n' "${empty[@]}" > "$recovery/empty-objects.txt"
printf 'Found %s empty loose objects. Downloading replacement database...\n' "${#empty[@]}"
# Run from repo so relative local remote paths have the expected meaning.
(cd -- "$repo" && git clone --mirror --no-local -- "$remote" "$recovery/upstream.git")
donor="$recovery/upstream.git"
git --git-dir="$donor" fsck --full >"$recovery/fsck-donor.log" 2>&1

printf 'Verifying every required replacement before modifying the repository...\n'
missing=0
for relative in "${empty[@]}"; do
  oid=${relative/\//}
  if ! git --git-dir="$donor" cat-file -e "$oid"; then
    printf 'Replacement unavailable: %s\n' "$oid" >&2
    missing=$((missing + 1))
  fi
done
[[ $missing -eq 0 ]] || die "$missing objects unavailable from remote. Original repository untouched."

# Repack ensures donor objects are available in packs, rather than loose files
# that would collide with the damaged files we need to quarantine.
git --git-dir="$donor" repack -a -d
printf 'Installing verified pack files...\n'
for source in "$donor"/objects/pack/*; do
  [[ -f $source ]] || continue
  destination="$objects/pack/${source##*/}"
  if [[ -e $destination ]]; then
    cmp -s -- "$source" "$destination" || die "Conflicting pack file: $destination"
  else
    # Stage outside the object database, then rename on the same filesystem.
    cp -a -- "$source" "$recovery/pack-stage"
    mv -- "$recovery/pack-stage" "$destination"
  fi
done

printf 'Quarantining empty loose objects...\n'
for relative in "${empty[@]}"; do
  file="$objects/$relative"
  [[ -f $file && ! -s $file ]] || die "Object changed during recovery: $file"
  mkdir -p -- "$recovery/empty-objects/${relative%/*}"
  mv -- "$file" "$recovery/empty-objects/$relative"
done

printf 'Checking repaired repository...\n'
if ! git -C "$repo" fsck --full >"$recovery/fsck-after.log" 2>&1; then
  die "Integrity check still fails. Keep the backup and inspect $recovery/fsck-after.log. Do not reset or update."
fi
git -C "$repo" status --short
printf '\nRecovery succeeded. Working files, index and refs were not changed.\n'
printf 'Backup, quarantined objects and logs: %s\n' "$recovery"
printf 'Review local changes before running any normal pull/update command.\n'
