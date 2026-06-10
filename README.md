# Scripts

A collection of administration, development, Git, cloud, and platform utility
scripts. Review each script and its dependencies before running it, especially
scripts that delete files or modify system configuration.

## Legend

- `⚠️ Destructive` - Deletes data or makes significant system or remote changes.
- `🚧 WIP` - Incomplete, experimental, or known to contain unfinished behavior.
- `🔐 Elevated` - Requires root, administrator, or other privileged access.
- `🧪 Example` - Demonstration code that needs customization before use.
- `Retired` - Kept as a fail-closed stub for discoverability; it no longer performs its former operation.

## Git and GitHub

- `⚠️` [`git-delete-merged-branches.sh`](git-delete-merged-branches.sh) - Uses a private temporary file to edit and delete selected branches already merged into `main` or `master`.
- [`git-pull-recursive.sh`](git-pull-recursive.sh) - Recursively finds Git repositories under a directory and fetches and pulls each one.
- [`git-remotes-recursive.sh`](git-remotes-recursive.sh) - Recursively lists Git repositories and their fetch remotes.
- [`git-status-directories.sh`](git-status-directories.sh) - Recursively reports Git repositories with uncommitted changes.
- [`github-latest-release.sh`](github-latest-release.sh) - Gets the latest GitHub release tag for a repository through the GitHub API.
- [`github-latest-tag.sh`](github-latest-tag.sh) - Finds the highest semantic-version GitHub tag, with optional prefix filtering and token authentication.
- [`hub-sync-recursive.sh`](hub-sync-recursive.sh) - Recursively fetches repositories, creates local tracking branches, and synchronizes them with the `hub` CLI.
- `⚠️` [`tag.sh`](tag.sh) - Bumps a repository's major, minor, or patch version tag and pushes it.
- [`utils.sh`](utils.sh) - Provides the shared `is_git_repository` shell helper used by recursive Git scripts.

## GitLab

- [`gitlab-check-image-publish-time.sh`](gitlab-check-image-publish-time.sh) - Reports how long ago a GitLab container registry image tag was published.
- `Retired` [`gitlab-clone-group.sh`](gitlab-clone-group.sh) - Retired unsafe prototype; use `python/clone-gitlab-group.py`.
- [`gitlab-clone-projects-recursive.sh`](gitlab-clone-projects-recursive.sh) - Exports or reads GitLab project metadata and clones projects into their namespace directory structure.
- [`gitlab-get-project-id-from-current-repo.sh`](gitlab-get-project-id-from-current-repo.sh) - Resolves the current repository's GitLab project ID by matching its remote URL.
- [`gitlab-list-registry-images.sh`](gitlab-list-registry-images.sh) - Lists container registry tags for the current GitLab repository and reports each tag's age.
- [`python/clone-gitlab-group.py`](python/clone-gitlab-group.py) - Recursively clones a GitLab group's projects, project wikis, and subgroups.
- [`python/list-gitlab-projects.py`](python/list-gitlab-projects.py) - Lists accessible GitLab projects using `python-gitlab` and environment-based credentials.

## Storage and System Administration

- `⚠️` `🔐` [`clean-storage-safe.sh`](clean-storage-safe.sh) - Interactively reviews and cleans package caches, build artifacts, logs, temporary files, user caches, and trash.
- [`diagnose-disk-space-ubuntu.sh`](diagnose-disk-space-ubuntu.sh) - Performs a read-only Ubuntu disk-usage audit and prints possible cleanup commands.
- `⚠️` `🔐` [`expand_root_volume.sh`](expand_root_volume.sh) - Identifies and confirms a directly mounted ext4 root partition before resizing it.
- [`find-backup-files.sh`](find-backup-files.sh) - Creates a report of recently modified documents, code, configuration, media, database, archive, and large files.
- `⚠️` [`rm-recursive-.gradle.sh`](rm-recursive-.gradle.sh) - Previews and confirms symlink-safe removal of `.gradle` directories below a selected root.
- `⚠️` [`rm-recursive-build.sh`](rm-recursive-build.sh) - Previews and confirms symlink-safe removal of `build` directories below a selected root.
- `⚠️` [`rm-recursive-node_modules.sh`](rm-recursive-node_modules.sh) - Previews and confirms symlink-safe removal of `node_modules` directories below a selected root.
- `⚠️` [`rm-recursive-postgres-data.sh`](rm-recursive-postgres-data.sh) - Previews and confirms symlink-safe removal of `postgres-data` directories below a selected root.
- `🔐` [`storage_diagnose.sh`](storage_diagnose.sh) - Collects disk, partition, LVM, inode, large-file, ZFS, and snapshot diagnostics into a log in `/tmp`.
- `⚠️` `🔐` [`update-apt.sh`](update-apt.sh) - Updates, upgrades, cleans, and removes unused packages on apt-based systems.
- [`zfsdash.py`](zfsdash.py) - Serves a localhost-only, cached web dashboard for ZFS pool status, scrub progress, and resilver progress.

## Docker, Cloud, and Deployment

- [`docker-debug-container.sh`](docker-debug-container.sh) - Starts a Docker image interactively with `/bin/sh` as its entrypoint and removes the container afterward.
- [`docker-list-tags-remote.sh`](docker-list-tags-remote.sh) - Lists Docker Hub tags for an image, optionally filtering them by text.
- `Retired` [`example-deploy.sh`](example-deploy.sh) - Retired root installer that trusted mutable upstream tags.
- `⚠️` [`gcp-subnets-enable-flow-logs.sh`](gcp-subnets-enable-flow-logs.sh) - Enables VPC Flow Logs on every subnet in the active Google Cloud project.

## Networking

- [`get-ip-from-domain-names.sh`](get-ip-from-domain-names.sh) - Reads domain names from a file and prints the IP addresses returned by `dig`.
- [`http-wait.sh`](http-wait.sh) - Polls a complete HTTP or HTTPS URL until it becomes reachable.
- [`ssh-wait.sh`](ssh-wait.sh) - Retries an SSH connection until the target becomes reachable.

## Development Utilities

- [`combine-md.sh`](combine-md.sh) - Combines Markdown files in the current directory into `combined.md`, adding a heading for each source file.
- [`generate-pdf-from-tex.ps1`](generate-pdf-from-tex.ps1) - Runs `pdflatex` in a restricted, digest-pinned TeX Live container; shell escape requires explicit opt-in.
- `🧪` [`is-command-in-path.sh`](is-command-in-path.sh) - Demonstrates checking whether a configured command, currently `cargo`, exists in `PATH`.
- [`python-run-on-change.sh`](python-run-on-change.sh) - Uses `fswatch` to rerun a Python file whenever it changes.
- [`Watch-Command.ps1`](Watch-Command.ps1) - Repeatedly invokes a trusted PowerShell script block at a configurable interval.

## Platform Setup

- [`bash-3-version-check-mac.sh`](bash-3-version-check-mac.sh) - Prints the version of macOS's system Bash.
- [`bash-5-version-check-mac.sh`](bash-5-version-check-mac.sh) - Prints the version of Bash installed at `/usr/local/bin/bash`.
- [`java_home.sh`](java_home.sh) - Defines macOS shell functions for switching `JAVA_HOME` between common JDK versions.
- `Retired` [`macos/ruby/chruby_local.sh`](macos/ruby/chruby_local.sh) - Retired unverified chruby installer.
- `Retired` [`macos/ruby/ruby-install_local.sh`](macos/ruby/ruby-install_local.sh) - Retired unverified ruby-install bootstrapper.
- `Retired` [`setup-kali.sh`](setup-kali.sh) - Retired root bootstrapper for obsolete, unverified third-party software.

## Windows and Active Directory

- [`Monitor-ADGroupChanges.ps1`](Monitor-ADGroupChanges.ps1) - Atomically tracks Active Directory group membership in an ACL-restricted, spreadsheet-safe CSV state file.

## Browser Tools

- [`file-manager.html`](file-manager.html) - Standalone browser file vault that stores, downloads, and deletes files using IndexedDB.
- [`tampermonkey/edx-download-transcripts.js`](tampermonkey/edx-download-transcripts.js) - Tampermonkey userscript that adds an edX button for downloading a video's transcript as text.
