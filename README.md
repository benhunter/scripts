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
- [`csv-explorer.html`](csv-explorer.html) - Browser-based CSV explorer for loading local CSV files, searching and sorting rows, and calculating per-column statistics. Because it imports [`csv-explorer-core.js`](csv-explorer-core.js) as a native ES module, open it through a local HTTP server instead of a `file://` URL during local use: run `pnpm install`, then `pnpm start`, then open the Vite localhost landing page and choose CSV Explorer.
- [`json-explorer.html`](json-explorer.html) - Browser-based JSON explorer for inspecting JSON with searchable tree and table views.

### CSV Explorer filter semantics

The CSV Explorer core helpers apply table operations in this order: global search,
column filters, sorting, then row limit. Global search performs a
case-insensitive substring match across the provided headers.

Column filters also use case-insensitive substring matching. Empty filters are
ignored. On a single column, include filters are ORed together, exclude filters
supersede include filters, and a row is rejected if any exclude filter matches.
Across different columns, filters are ANDed together, so every filtered column
must pass. Missing or unknown cell values are treated as empty strings.

### CSV Explorer manual QA checklist

Automated coverage for the core parser/filter helpers and the main browser
journey lives in [`tests/csv-explorer-core.test.js`](tests/csv-explorer-core.test.js)
and [`tests/e2e/csv-explorer.spec.js`](tests/e2e/csv-explorer.spec.js). Keep this
manual checklist focused on visual checks and interactions that are not covered
by those automated tests.

Sample CSV: [`csv-explorer-sample.csv`](csv-explorer-sample.csv)

1. Start the local server with `pnpm start`, open the landing page, and choose
   **CSV Explorer**.
2. Load [`csv-explorer-sample.csv`](csv-explorer-sample.csv). Confirm the rows,
   detected delimiter, column list, all-column statistics, profile selector, and
   entire table appear.
3. Use global search for `Data`; confirm only Cora and Drew remain visible and
   the shown row count updates to `2`.
4. Sort the entire table by `Score`; confirm the sort label updates and scores
   sort numerically rather than lexicographically.
5. Set the row limit to `1,000`; confirm the displayed row count still reflects
   the current search result because the sample has fewer than 1,000 rows.
6. Click a column name in the all-column statistics table; confirm the column
   profile section scrolls into view and shows top values plus KPIs for that
   column.
7. Change null tokens to include `Pending`, recompute stats, and confirm the
   `Status` column null count changes.
8. Clear search and reload the sample or load a different CSV file; confirm
   search text, sort order, row limit, selected profile, statistics, and row
   data reset for the new load.
