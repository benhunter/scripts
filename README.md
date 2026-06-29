# Scripts

A collection of administration, development, Git, cloud, and platform utility
scripts. Review each script and its dependencies before running it, especially
scripts that delete files or modify system configuration.

## Legend

- `⚠️ Destructive` - Deletes data or makes significant system or remote changes.
- `🚧 WIP` - Incomplete, experimental, or known to contain unfinished behavior.
- `🔐 Elevated` - Requires root, administrator, or other privileged access.
- `🧪 Example` - Demonstration code that needs customization before use.

## Git and GitHub

- `⚠️` [`git-delete-merged-branches.sh`](git-delete-merged-branches.sh) - Opens a list of branches already merged into `main` in Neovim, then deletes the selected branches.
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
- `🚧` [`gitlab-clone-group.sh`](gitlab-clone-group.sh) - Clones projects from a GitLab group and attempts to process its subgroups; currently a work in progress.
- [`gitlab-clone-projects-recursive.sh`](gitlab-clone-projects-recursive.sh) - Exports or reads GitLab project metadata and clones projects into their namespace directory structure.
- [`gitlab-get-project-id-from-current-repo.sh`](gitlab-get-project-id-from-current-repo.sh) - Resolves the current repository's GitLab project ID by matching its remote URL.
- [`gitlab-list-registry-images.sh`](gitlab-list-registry-images.sh) - Lists container registry tags for the current GitLab repository and reports each tag's age.
- [`python/clone-gitlab-group.py`](python/clone-gitlab-group.py) - Recursively clones a GitLab group's projects, project wikis, and subgroups.
- [`python/list-gitlab-projects.py`](python/list-gitlab-projects.py) - Lists accessible GitLab projects using `python-gitlab` and environment-based credentials.

## Storage and System Administration

- `⚠️` `🔐` [`clean-storage-safe.sh`](clean-storage-safe.sh) - Interactively reviews and cleans package caches, build artifacts, logs, temporary files, user caches, and trash.
- [`diagnose-disk-space-ubuntu.sh`](diagnose-disk-space-ubuntu.sh) - Performs a read-only Ubuntu disk-usage audit and prints possible cleanup commands.
- `⚠️` `🔐` [`expand_root_volume.sh`](expand_root_volume.sh) - Expands partition 2 and its ext4 root filesystem with `growpart` and `resize2fs`.
- [`find-backup-files.sh`](find-backup-files.sh) - Creates a report of recently modified documents, code, configuration, media, database, archive, and large files.
- `⚠️` [`rm-recursive-.gradle.sh`](rm-recursive-.gradle.sh) - Recursively deletes every `.gradle` directory below the current directory.
- `⚠️` [`rm-recursive-build.sh`](rm-recursive-build.sh) - Recursively deletes every `build` directory below the current directory.
- `⚠️` [`rm-recursive-node_modules.sh`](rm-recursive-node_modules.sh) - Recursively deletes every `node_modules` directory below the current directory.
- `⚠️` [`rm-recursive-postgres-data.sh`](rm-recursive-postgres-data.sh) - Recursively deletes every `postgres-data` directory below the current directory.
- `🔐` [`storage_diagnose.sh`](storage_diagnose.sh) - Collects disk, partition, LVM, inode, large-file, ZFS, and snapshot diagnostics into a log in `/tmp`.
- `⚠️` `🔐` [`update-apt.sh`](update-apt.sh) - Updates, upgrades, cleans, and removes unused packages on apt-based systems.
- [`zfsdash.py`](zfsdash.py) - Serves a small web dashboard for ZFS pool status, scrub progress, and resilver progress.

## Docker, Cloud, and Deployment

- [`docker-debug-container.sh`](docker-debug-container.sh) - Starts a Docker image interactively with `/bin/sh` as its entrypoint and removes the container afterward.
- [`docker-list-tags-remote.sh`](docker-list-tags-remote.sh) - Lists Docker Hub tags for an image, optionally filtering them by text.
- `⚠️` `🔐` `🧪` [`example-deploy.sh`](example-deploy.sh) - Example installer that clones or updates HeavyScript to its latest tag and creates a command wrapper.
- `⚠️` [`gcp-subnets-enable-flow-logs.sh`](gcp-subnets-enable-flow-logs.sh) - Enables VPC Flow Logs on every subnet in the active Google Cloud project.

## Networking

- [`get-ip-from-domain-names.sh`](get-ip-from-domain-names.sh) - Reads domain names from a file and prints the IP addresses returned by `dig`.
- [`http-wait.sh`](http-wait.sh) - Polls an HTTP host until it becomes reachable.
- [`ssh-wait.sh`](ssh-wait.sh) - Retries an SSH connection until the target becomes reachable.

## Development Utilities

- [`combine-md.sh`](combine-md.sh) - Combines Markdown files in the current directory into `combined.md`, adding a heading for each source file.
- `🧪` [`generate-pdf-from-tex.ps1`](generate-pdf-from-tex.ps1) - Runs `pdflatex` in a TeX Live Docker container to generate a PDF from `week_8.tex`.
- `🧪` [`is-command-in-path.sh`](is-command-in-path.sh) - Demonstrates checking whether a configured command, currently `cargo`, exists in `PATH`.
- [`python-run-on-change.sh`](python-run-on-change.sh) - Uses `fswatch` to rerun a Python file whenever it changes.
- [`Watch-Command.ps1`](Watch-Command.ps1) - Defines a PowerShell function that repeatedly runs a command at a configurable interval.

## Platform Setup

- [`bash-3-version-check-mac.sh`](bash-3-version-check-mac.sh) - Prints the version of macOS's system Bash.
- [`bash-5-version-check-mac.sh`](bash-5-version-check-mac.sh) - Prints the version of Bash installed at `/usr/local/bin/bash`.
- [`java_home.sh`](java_home.sh) - Defines macOS shell functions for switching `JAVA_HOME` between common JDK versions.
- [`macos/ruby/chruby_local.sh`](macos/ruby/chruby_local.sh) - Installs `chruby` under the current user's home directory and configures shell startup files.
- [`macos/ruby/ruby-install_local.sh`](macos/ruby/ruby-install_local.sh) - Installs `ruby-install` locally and uses it to install the latest stable Ruby.
- `⚠️` `🔐` [`setup-kali.sh`](setup-kali.sh) - Bootstraps a Kali Linux installation with packages, tools, shell configuration, Ghidra, and security utilities.

## Windows and Active Directory

- `🚧` [`Monitor-ADGroupChanges.ps1`](Monitor-ADGroupChanges.ps1) - Compares current Active Directory group membership with saved CSV state and reports additions and removals; includes work-in-progress code.

## Browser Tools

- [`file-manager.html`](file-manager.html) - Standalone browser file vault that stores, downloads, and deletes files using IndexedDB.
- [`tampermonkey/edx-download-transcripts.js`](tampermonkey/edx-download-transcripts.js) - Tampermonkey userscript that adds an edX button for downloading a video's transcript as text.
- [`csv-explorer.html`](csv-explorer.html) - Browser-based CSV explorer for loading local CSV files, viewing rows, and calculating per-column statistics.
- [`json-explorer.html`](json-explorer.html) - Browser-based JSON explorer for inspecting JSON with searchable tree and table views.

### csv-explorer.html manual QA checklist

TODO: Convert this manual checklist into an automated browser test in the future.

Keep this checklist as documentation-only manual coverage unless a browser test
framework is introduced later.

Sample CSV:

```csv
Name,Team,Status,Score
Ada,Platform,Active,91
Ben,Platform,Inactive,77
Cora,Data,Active,88
Drew,Data,Pending,82
Eli,Support,Active,73
```

1. Save the sample as `csv-explorer-sample.csv`, open
   [`csv-explorer.html`](csv-explorer.html) in a browser, and load the file.
   Confirm the rows render and column statistics appear.
2. Use global search for `Data`; confirm only Cora and Drew remain visible.
3. Add an include filter on `Status` for `Active`; confirm Ada, Cora, and Eli
   are visible.
4. Add multiple include filters on the `Team` column for `Platform` and `Data`;
   confirm Ada, Ben, Cora, and Drew are visible before any other filters are
   applied.
5. Add an exclude filter on `Status` for `Inactive`; confirm Ben is hidden.
6. With filters still applied, sort by `Score`; confirm the filtered rows sort
   by score rather than restoring filtered-out rows.
7. Set a row limit after filtering; confirm the displayed row count is capped
   after search and column filters are applied.
8. Clear filters and search; confirm all five sample rows are visible again.
9. Load a different CSV file; confirm search text, include filters, exclude
   filters, sort order, row limit, selected columns, and row data reset for the
   new file.
