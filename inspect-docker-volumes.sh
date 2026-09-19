#!/usr/bin/env bash
# Inspect Docker volumes, largest first. Does not modify or delete volumes.
set -euo pipefail

if (( EUID != 0 )); then
    exec sudo bash "$0" "$@"
fi

# Measure allocated disk usage in KiB, then sort numerically descending.
docker volume ls -q | while IFS= read -r volume; do
    mountpoint=$(docker volume inspect --format '{{.Mountpoint}}' "$volume")
    size=$(du -sk -- "$mountpoint" | cut -f1)
    printf '%s\t%s\n' "$size" "$volume"
done | sort -k1,1nr | while read -r size volume; do
    printf '\n=== %s (%s) ===\n' "$volume" "$(numfmt --from-unit=1024 --to=iec "$size")"
    docker volume inspect \
        --format 'Created: {{.CreatedAt}} Labels: {{json .Labels}}' "$volume"
    mountpoint=$(docker volume inspect --format '{{.Mountpoint}}' "$volume")
    # Consume all output to avoid SIGPIPE under pipefail, printing only 15 lines.
    ls -lah -- "$mountpoint" | awk 'NR <= 15'
done

# Lists all volumes that have a .package-lock.json file at the root
# sudo docker volume ls -q | while IFS= read -r v; do p=$(sudo docker volume inspect --format '{{.Mountpoint}}' "$v") || continue; sudo test -f "$p/.package-lock.json" && printf '%s\n' "$v"; done

# Removes all volumes that have a .package-lock.json file at the root
# sudo docker volume ls -q | while IFS= read -r v; do p=$(sudo docker volume inspect --format '{{.Mountpoint}}' "$v") || continue; if sudo test -f "$p/.package-lock.json"; then sudo docker volume rm "$v"; fi; done

# Lists completely empty volumes (including no hidden files or subdirectories):
# sudo docker volume ls -q | while IFS= read -r v; do p=$(sudo docker volume inspect --format '{{.Mountpoint}}' "$v") || continue; entries=$(sudo find "$p" -mindepth 1 -maxdepth 1 -print -quit) || continue; [ -z "$entries" ] && printf '%s\n' "$v"; done

# Removes completely empty volumes (no files, hidden files, or subdirectories). Docker refuses volumes referenced by containers.
# sudo docker volume ls -q | while IFS= read -r v; do p=$(sudo docker volume inspect --format '{{.Mountpoint}}' "$v") || continue; entries=$(sudo find "$p" -mindepth 1 -maxdepth 1 -print -quit) || continue; if [ -z "$entries" ]; then sudo docker volume rm "$v"; fi; done

