#!/bin/zsh

# Script to identify files that might need to be backed up on Ubuntu
# Usage: find-backup-files.sh [days_modified]

DAYS=${1:-7}
OUTPUT_FILE="backup-candidates-$(date +%Y%m%d-%H%M%S).txt"

echo "Finding files modified in the last $DAYS days that might need backup..."
echo "Output will be saved to: $OUTPUT_FILE"
echo ""

{
    echo "=========================================="
    echo "Backup Candidates Report"
    echo "Generated: $(date)"
    echo "Files modified in last $DAYS days"
    echo "=========================================="
    echo ""

    # User home directory documents
    echo "=== HOME DIRECTORY DOCUMENTS ==="
    find ~ -type f \
        \( -path "*/.*" -prune -o \
           -path "*/node_modules" -prune -o \
           -path "*/.cache" -prune -o \
           -path "*/.local/share/Trash" -prune -o \
           -name "*.txt" -o \
           -name "*.doc" -o -name "*.docx" -o \
           -name "*.pdf" -o \
           -name "*.xls" -o -name "*.xlsx" -o \
           -name "*.ppt" -o -name "*.pptx" -o \
           -name "*.odt" -o -name "*.ods" -o -name "*.odp" \) \
        -mtime -$DAYS -print 2>/dev/null | head -50
    echo ""

    # Code and project files
    echo "=== CODE AND PROJECT FILES ==="
    find ~ -type f \
        \( -path "*/.*" -prune -o \
           -path "*/node_modules" -prune -o \
           -path "*/.cache" -prune -o \
           -name "*.py" -o -name "*.js" -o -name "*.ts" -o \
           -name "*.java" -o -name "*.c" -o -name "*.cpp" -o \
           -name "*.go" -o -name "*.rs" -o -name "*.rb" -o \
           -name "*.php" -o -name "*.sh" -o -name "*.zsh" \) \
        -mtime -$DAYS -print 2>/dev/null | head -50
    echo ""

    # Configuration files
    echo "=== CONFIGURATION FILES ==="
    find ~ -maxdepth 2 -type f \
        \( -name ".*rc" -o -name ".*profile" -o -name "*.conf" -o -name "*.config" \) \
        -mtime -$DAYS -print 2>/dev/null
    echo ""

    # SSH keys and configs
    echo "=== SSH FILES ==="
    if [ -d ~/.ssh ]; then
        find ~/.ssh -type f -print 2>/dev/null
    fi
    echo ""

    # Database dumps
    echo "=== DATABASE FILES ==="
    find ~ -type f \
        \( -name "*.sql" -o -name "*.db" -o -name "*.sqlite" -o -name "*.dump" \) \
        -mtime -$DAYS -print 2>/dev/null | head -20
    echo ""

    # Images and media
    echo "=== RECENT IMAGES/MEDIA ==="
    find ~ -type f \
        \( -path "*/.*" -prune -o \
           -path "*/.cache" -prune -o \
           -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o \
           -name "*.gif" -o -name "*.svg" -o -name "*.mp4" -o \
           -name "*.mov" -o -name "*.avi" \) \
        -mtime -$DAYS -print 2>/dev/null | head -50
    echo ""

    # Archives and backups
    echo "=== ARCHIVES ==="
    find ~ -type f \
        \( -name "*.zip" -o -name "*.tar" -o -name "*.tar.gz" -o \
           -name "*.tgz" -o -name "*.bz2" -o -name "*.7z" \) \
        -mtime -$DAYS -print 2>/dev/null | head -20
    echo ""

    # Large files (over 100MB)
    echo "=== LARGE FILES (>100MB) ==="
    find ~ -type f -size +100M -mtime -$DAYS -print 2>/dev/null | head -20
    echo ""

    # System files that might be important
    echo "=== SYSTEM CONFIGURATION (requires sudo) ==="
    echo "Run with sudo to check system configs"
    echo "Checking /etc/hosts, /etc/fstab, /etc/crontab..."
    ls -lh /etc/hosts /etc/fstab /etc/crontab 2>/dev/null
    echo ""

    # Summary statistics
    echo "=========================================="
    echo "SUMMARY"
    echo "=========================================="
    echo "Total home directory size:"
    du -sh ~ 2>/dev/null
    echo ""
    echo "Files modified in last $DAYS days:"
    find ~ -type f -mtime -$DAYS 2>/dev/null | wc -l

} | tee "$OUTPUT_FILE"

echo ""
echo "Report saved to: $OUTPUT_FILE"
echo ""
echo "TIP: Review this list and copy important files to your backup location"
echo "Common backup locations:"
echo "  - External drive: /media/username/drive"
echo "  - Network: rsync -avz ~ user@server:/backup/"
echo "  - Cloud: rclone copy ~ remote:backup/"
