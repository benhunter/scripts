# Scripts

- Powershell, Active Directory
- Kali Linux Setup
- Linux apt auto-update
- Ventoy CLI config
- LaTeX to PDF by docker container
- `get-ip-from-domain-names.sh` - take a list of domain names and print their IP addresses.
- `gitlab-wiki-url.sh` - resolve a GitLab project or group wiki clone URL.

## GitLab wiki URL helper

Required environment variables:

- `GITLAB_TOKEN` (only when `glab` is not available)

Examples:

```bash
gitlab-wiki-url.sh https://gitlab.example.com/my-group/my-project
gitlab-wiki-url.sh https://gitlab.example.com/my-group
```
