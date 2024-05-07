# This function checks if a directory is a git repository
is_git_repository() {
    if [ -d "$1/.git" ]; then
    #if git -C "$1" rev-parse 2> /dev/null; then
        return 0
    else
        return 1
    fi
}
