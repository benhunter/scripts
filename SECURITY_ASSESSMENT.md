# Security Assessment

Date: 2026-06-08

## Scope and Method

Reviewed all 48 script-like files in this repository:

- 40 shell scripts
- 3 PowerShell scripts
- 3 Python scripts
- 1 JavaScript userscript
- 1 HTML/JavaScript utility

The review covered command injection, path traversal, unsafe deletion, privilege
boundaries, credential exposure, network exposure, supply-chain integrity,
temporary-file handling, browser injection, and sensitive-data handling.

Static validation performed:

- Python AST parsing: passed for all Python files.
- PowerShell parsing: `Monitor-ADGroupChanges.ps1` failed at line 50.
- JavaScript syntax checking: passed.
- Secret-pattern scan: no committed private keys or recognizable access tokens found.
- Shell syntax/static analysis could not be run because ShellCheck is unavailable
  and Windows Subsystem for Linux has no installed distribution.

## Findings

### High: Remote code is loaded over plaintext HTTP

File: `tampermonkey/edx-download-transcripts.js:10`

The userscript loads `jquery-latest.js` over HTTP. A network attacker can replace
the response and execute arbitrary JavaScript in the context of every matching
edX page. Using the mutable `latest` target also makes the dependency
non-reproducible.

Recommendation: remove jQuery if possible. Otherwise pin an exact HTTPS asset
and verify the userscript manager's integrity mechanism, if supported.

### High: Root setup executes unverified third-party content

File: `setup-kali.sh:105-125`, `setup-kali.sh:137-138`

The script runs as root, downloads a Ghidra archive without checksum or signature
verification, clones a mutable Git repository, and installs its requirements.
It also installs unpinned Python packages as root. Compromise of a download,
repository, dependency, or account can become root code execution.

Recommendation: pin immutable versions/commits, verify release signatures or
checksums, install Python tools in an unprivileged isolated environment, and
avoid running repository-controlled installation code as root.

### High: TeX compilation explicitly permits command execution

File: `generate-pdf-from-tex.ps1:1`

`pdflatex -shell-escape` allows the TeX document to execute commands. The current
directory is mounted writable into an unpinned `texlive/texlive:latest` image.
Compiling an untrusted `week_8.tex` can modify repository files and run commands
inside the container; container/runtime weaknesses could increase the impact.

Recommendation: remove `-shell-escape` unless required, pin the image by digest,
mount source read-only, and write output to a separate directory.

### High: Recursive deletion follows directory symlinks

Files:

- `rm-recursive-.gradle.sh:6-12`
- `rm-recursive-build.sh:5-11`
- `rm-recursive-node_modules.sh:5-11`
- `rm-recursive-postgres-data.sh:5-11`

`[ -d "$file" ]` follows symlinks, and the recursive functions descend through
them. A symlink below the starting directory can redirect traversal outside the
tree, where a matching directory may then be deleted.

Recommendation: use `find` without `-L`, constrain results to the resolved
starting directory, reject symbolic links explicitly, and add confirmation or
dry-run behavior.

### Medium: ZFS status is exposed without authentication

File: `zfsdash.py:6`, `zfsdash.py:394-416`

The server binds to `0.0.0.0` and exposes pool names, device paths, errors, and
status to any reachable client. Every API request launches `zpool`, so a remote
client can also repeatedly consume process and I/O resources.

Recommendation: bind to `127.0.0.1` by default. Put authentication, TLS, request
limits, and caching in front of it if remote access is required.

### Medium: Stored DOM injection through filenames

File: `file-manager.html:282-291`

Stored filenames are interpolated into `innerHTML`, including text and an HTML
attribute. A crafted filename can inject markup and script-capable event
handlers. Because records persist in IndexedDB, the injection is persistent for
the page's origin.

Recommendation: construct elements with DOM APIs, assign filenames with
`textContent`, and set `href` and `download` properties directly.

### Medium: Predictable privileged temporary files

Files:

- `git-delete-merged-branches.sh:2`
- `storage_diagnose.sh:4-7`

Both scripts create predictable files under `/tmp` without `mktemp` or exclusive
creation. When run by a privileged user, a local attacker can pre-create a
symlink and cause truncation or appending to another file. The storage report
also contains sensitive filesystem, UUID, path, and host information and will
normally be created with permissive default mode bits.

Recommendation: use `mktemp`, set `umask 077`, install cleanup traps, and avoid
running the branch helper with elevated privileges.

### Medium: Root installer tracks mutable upstream state

File: `example-deploy.sh:24-36`, `example-deploy.sh:63-100`

This root-only installer trusts the latest reachable Git tag, forcibly checks it
out, and exposes the downloaded executable through root's `PATH`. Tags are
mutable and no commit/signature allowlist is enforced.

Recommendation: pin a reviewed commit or signed release and verify it before
installing the executable.

### Medium: AD data is exported without spreadsheet neutralization

File: `Monitor-ADGroupChanges.ps1:43-51`, `Monitor-ADGroupChanges.ps1:90-120`

AD-controlled values are exported to CSV. If an attribute begins with `=`, `+`,
`-`, or `@`, spreadsheet software may interpret it as a formula when an
administrator opens the report. The output directory also has no explicit
restrictive ACL despite containing detailed account and distinguished-name data.

Recommendation: neutralize formula-leading cells and create the output directory
with an ACL limited to the monitoring identity and intended readers.

### Low: GitHub token is placed in a process argument

File: `github-latest-tag.sh:65-73`

The authorization header, including `GITHUB_TOKEN`, is passed in curl's command
line. Depending on operating-system process visibility, another local user may
be able to observe it.

Recommendation: use a protected curl configuration or credential mechanism that
does not expose the token in process arguments.

### Low: Sensitive inventory reports use default permissions

File: `find-backup-files.sh:7`, `find-backup-files.sh:57-68`

The report lists SSH files, database files, archives, and other sensitive paths,
but no restrictive `umask` is set.

Recommendation: set `umask 077` before creating the report.

### Low: Dynamic command execution is unrestricted by design

File: `Watch-Command.ps1:8-24`

`Invoke-Expression` executes the supplied string as PowerShell code. This is
expected for an interactive watch helper, but it is unsafe if callers pass data
from another user, file, service, or automation boundary.

Recommendation: accept a `[scriptblock]` and invoke it with `&`, and document
that the input must be trusted.

### Low: SSH target can be interpreted as an option

File: `ssh-wait.sh:12-17`

A target beginning with `-` may be interpreted by `ssh` as another option. This
can become dangerous if the target originates outside the invoking user's trust
boundary, especially with options such as `ProxyCommand`.

Recommendation: validate the target as `user@host`/host syntax and reject values
beginning with `-`.

## Correctness Defects Affecting Security Operations

- `Monitor-ADGroupChanges.ps1:50` has a missing closing parenthesis and does not
  parse.
- `Monitor-ADGroupChanges.ps1:47` uses `$StateFile` before it is initialized in
  the first implementation block.
- `gitlab-clone-group.sh:59` has an unterminated quote and is not executable as
  written.
- `docker-debug-container.sh:1` uses `"$*"`, collapsing all arguments into one
  Docker argument.
- Several GitLab/GCP scripts use unquoted expansions. Current API naming rules
  reduce direct injection risk, but spaces, globbing, and malformed responses can
  alter behavior.

## Per-Script Disposition

| Script | Risk | Assessment |
|---|---:|---|
| `bash-3-version-check-mac.sh` | None | No material security issue. |
| `bash-5-version-check-mac.sh` | None | No material security issue. |
| `clean-storage-safe.sh` | Low | Destructive by purpose, but fixed `PATH`, quoting, prompts, and non-following `find` defaults are good controls. Running the whole script with `sudo` changes `HOME` behavior and blast radius; prefer per-command elevation. |
| `combine-md.sh` | Low | Overwrites `combined.md` in the current directory by design; avoid privileged or attacker-controlled directories. |
| `diagnose-disk-space-ubuntu.sh` | None | Read-only; destructive commands are printed only. |
| `docker-debug-container.sh` | Low | No injection found; argument collapsing is a correctness issue. Container image trust remains the caller's responsibility. |
| `docker-list-tags-remote.sh` | Low | Uses a deprecated endpoint and fragile text parsing; no direct code-execution path found. |
| `example-deploy.sh` | Medium | Root install trusts mutable upstream tags and repository content. |
| `expand_root_volume.sh` | Medium | Ignores the detected root device and always modifies `/dev/vda2`, even after confirming a different device. This can corrupt the wrong partition. |
| `file-manager.html` | Medium | Persistent DOM injection through stored filenames. |
| `find-backup-files.sh` | Low | Sensitive path inventory is written with default permissions. |
| `gcp-subnets-enable-flow-logs.sh` | Low | Privileged cloud-wide configuration change lacks confirmation and quotes; no shell code injection found under normal GCP naming rules. |
| `generate-pdf-from-tex.ps1` | High | Untrusted TeX can execute commands; writable bind mount and mutable image increase risk. |
| `get-ip-from-domain-names.sh` | None | Input is quoted; no material security issue. |
| `git-delete-merged-branches.sh` | Medium | Predictable `/tmp` file enables symlink attacks under elevated execution. |
| `git-pull-recursive.sh` | Low | Pulls and merges untrusted remote content across many repositories; no automatic code execution in this script. |
| `git-remotes-recursive.sh` | None | Read-only repository inspection. |
| `git-status-directories.sh` | None | Read-only repository inspection; missing argument validation is operational. |
| `github-latest-release.sh` | None | Quoted HTTPS API request; no material issue found. |
| `github-latest-tag.sh` | Low | Token may be visible in process arguments; prefix is treated as a regex rather than a literal. |
| `gitlab-check-image-publish-time.sh` | Low | Unquoted API path components and multiple registry IDs can produce unintended requests; identifiers come from trusted CLI/API contexts. |
| `gitlab-clone-group.sh` | Low | Unquoted expansions and malformed recursion are unsafe operationally; script also has a syntax error. |
| `gitlab-clone-projects-recursive.sh` | Low | Unquoted clone URL/path and trusted-JSON assumptions can mis-handle malformed project data. Validate paths remain below `BASE_DIR`. |
| `gitlab-get-project-id-from-current-repo.sh` | None | Uses structured `jq` arguments and URL encoding; no material issue found. |
| `gitlab-list-registry-images.sh` | Low | Unquoted identifiers and word splitting can target unintended tags. |
| `http-wait.sh` | Low | Permits cleartext HTTP and arbitrary destinations by design; do not use it as a security/identity check. |
| `hub-sync-recursive.sh` | Low | Broadly mutates local branches based on remotes; remote names are quoted at execution. |
| `is-command-in-path.sh` | None | No material security issue. |
| `java_home.sh` | Low | Unquoted version argument can be split into extra tool arguments if exposed to untrusted input. |
| `Monitor-ADGroupChanges.ps1` | Medium | CSV formula/ACL risk; currently fails to parse. |
| `python-run-on-change.sh` | Low | Repeatedly executes the watched Python file; safe only when that file and its directory are trusted. |
| `rm-recursive-.gradle.sh` | High | Recursive deletion can traverse directory symlinks outside the starting tree. |
| `rm-recursive-build.sh` | High | Recursive deletion can traverse directory symlinks outside the starting tree. |
| `rm-recursive-node_modules.sh` | High | Recursive deletion can traverse directory symlinks outside the starting tree. |
| `rm-recursive-postgres-data.sh` | High | Recursive deletion can traverse directory symlinks outside the starting tree. |
| `setup-kali.sh` | High | Root execution of unverified archives, repositories, and package installation. |
| `ssh-wait.sh` | Low | SSH target option injection is possible if target input is untrusted. |
| `storage_diagnose.sh` | Medium | Predictable privileged `/tmp` report and sensitive output permissions. |
| `tag.sh` | Low | Pushes all local tags, not only the new tag; compromised local tags could be published. |
| `update-apt.sh` | Low | Performs broad unattended package changes as root; repository trust and package-manager signatures are the primary controls. |
| `utils.sh` | None | No material security issue. |
| `Watch-Command.ps1` | Low | Arbitrary expression execution by design; only trusted callers should supply commands. |
| `zfsdash.py` | Medium | Unauthenticated all-interface status disclosure and remotely triggerable subprocess load. |
| `macos/ruby/chruby_local.sh` | Medium | Downloads and installs an archive without checksum/signature verification. |
| `macos/ruby/ruby-install_local.sh` | Medium | Downloads installer code without verification, then uses it to fetch/build Ruby. |
| `python/clone-gitlab-group.py` | Low | Destination paths are derived from API fields without containment checks; GitLab path rules normally constrain them. `subprocess.run` does not use a shell. |
| `python/list-gitlab-projects.py` | None | Token is read from the environment and passed through the library; no material issue found. |
| `tampermonkey/edx-download-transcripts.js` | High | Plaintext, mutable remote script dependency permits browser-context code injection. |

## Priority Order

1. Remove the HTTP userscript dependency.
2. Replace the four recursive deletion implementations with symlink-safe traversal.
3. Harden or retire `setup-kali.sh`.
4. Remove `-shell-escape` and pin the TeX image.
5. Bind `zfsdash.py` to localhost and add access controls for remote use.
6. Replace filename `innerHTML` rendering in `file-manager.html`.
7. Replace predictable `/tmp` files and restrict report permissions.
