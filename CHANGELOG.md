# Changelog

## 2026-07-28 — Add Podman network and rootless Quadlet support

### Added

- Optional shared Podman network vars (`vault_podman_network`, `cloudflare_podman_network`) so Vault and cloudflared can reach each other by container name
- Rootless Podman Quadlet support for vault and cloudflare (`*_podman_rootless` defaults to `true`, `*_podman_user` defaults to `ansible_user`) with linger setup and user-scoped systemd
- Vault rootless `UserNS=keep-id` so host-owned volumes remain writable to the container vault user
- Shared `set_vault_cli_context` helper so init/configure tasks run `podman exec` as the rootless Podman user
- Cloudflare tunnel ingress Jinja template (`tunnel_ingress.json.j2`) that emits valid JSON, including custom `originRequest` merged with `no_tls_verify`

### Changed

- Vault and cloudflare install/uninstall paths use computed become/`become_user`/systemd scope for rootful vs rootless deployments
- `configure_hostnames` builds ingress rules via `lookup('ansible.builtin.template')` instead of inline set_fact loops

### Fixed

- Rootless Vault CLI tasks no longer run `podman exec` as root (which could not see the user container)
- Custom `originRequest` settings from inventory are preserved in tunnel ingress configuration
- Prefer `ansible_facts.getent_passwd` over deprecated top-level `getent_passwd` injection

## 2026-07-28 — Add Cloudflare tunnel uninstall and destroy support

### Added

- Cloudflare role `uninstall_podman` entry point to stop the Quadlet service and remove the unit, container, Podman secret, and optionally the image
- Cloudflare role `destroy_tunnel` entry point to delete Access apps, DNS CNAME records, and soft-delete the tunnel via the Cloudflare API
- End-to-end playbook `playbooks/pb_uninstall_cloudflare_tunnel.yml` with independent local and remote cleanup steps
- Default `cloudflare_uninstall_remove_image` and argument specs for the new entry points

## 2026-07-22 — Apply preferred Ansible task key order across roles

### Changed

- Reordered vault and cloudflare role tasks and related playbooks to match `AGENTS.md` key order (`name`, `when`, `loop`, `loop_control`, misc, `vars`, then module)
- Ordered module parameters with `name` / `description` / `state` first, then remaining keys alphabetically
- Added missing `loop_control.label` values on loops that lacked them (no other functional changes)

## 2026-07-22 — Add Cloudflare Tunnel role and setup playbook

### Added

- `demo.zero_trust.cloudflare` role with discrete entry points: `create_tunnel`, `install_podman`, `configure_hostnames`, `configure_access`
- End-to-end playbook `playbooks/pb_setup_cloudflare_tunnel.yml`
- Podman Quadlet deployment for `cloudflared` with tunnel token stored as a Podman secret (`TUNNEL_TOKEN` env injection)
- Public hostname ingress configuration via Cloudflare API and proxied CNAME records via `community.general.cloudflare_dns`
- Optional Cloudflare Access application/policy data model (`cloudflare_access_policies`)
- API token resolution: `CLOUDFLARE_API_TOKEN` env first, ansible-vault `vars/secrets.yml` fallback

### Changed

- Collection dependencies now include `community.general` (>=9.0.0) alongside `containers.podman`

## 2026-07-22 — Document preferred Ansible task key order for agents

### Added

- Preferred key order guidance in `AGENTS.md` for Ansible tasks (name, when, loop, vars, module params)

## 2026-07-14 — Forward VAULT_TOKEN into Podman vault CLI

### Fixed

- Podman `vault_cli` now passes `-e VAULT_TOKEN` so Ansible `environment: VAULT_TOKEN=...` reaches the vault CLI inside the container during JWT, userpass, and KV configure tasks

## 2026-07-14 — Add KV v2 secrets engine with sample secrets for e2e testing

### Added

- Vault role `configure_kv_engine` entry point that enables the KV v2 secrets engine and seeds sample secrets aligned with the static and dynamic JWT policy paths
- Uninstall playbook `playbooks/pb_uninstall_vault.yml` and local inventory `inventory/local.yml`
- Argument specs and defaults for KV engine path, version, and sample secrets list

### Changed

- `init_vault` is now idempotent — preflight status check skips init/unseal when already done, and re-reads saved `init_data.json` on subsequent runs
- Setup playbook defaults to `vault` host group and runs `configure_kv_engine` between JWT auth and userpass auth
- TLS cert/key destination defaults added to `configure_host`, `install_rpm`, and `install_podman` argument specs

## 2026-07-14 — Add Vault userpass auth from JSON users config

### Added

- Vault role `configure_userpass_auth` entry point that enables userpass auth, writes admin/user policies, and creates users from `files/vault_users.json`
- Auto-generated passwords (when omitted in config) are written to `{{ vault_storage_path }}/userpass_credentials.json`
- Admin policy (full access) and user policy (read policies and KV secrets) Jinja templates
- Argument specs and defaults for userpass users file, policy names, secret paths, and password generation

## 2026-07-14 — Add Vault JWT auth for AAP OIDC workload identity

### Added

- Vault role `configure_jwt_auth` entry point that enables JWT auth, configures AAP OIDC discovery, and creates static and dynamic JWT roles with matching policies (`aap-role-static` / `aap-policy-static`, `aap-role-dynamic` / `aap-policy-dynamic`)
- Static and templated Vault policy Jinja templates for JWT-bound secret paths
- Sample AAP workload identity claims reference under the vault role `files/` directory
- Argument specs and defaults for JWT OIDC discovery, bound audiences (via `vault_addr`), bound claims, and claim mappings

## 2026-07-14 — Add Vault uninstall and prefer Podman modules

### Added

- Vault role `uninstall` task entry point that auto-detects RPM or Podman installs, removes artifacts, and closes the firewall port
- Argument spec for the `uninstall` entry point
- `AGENTS.md` guidance to discover Ansible modules via `ansible-doc -t module -l` before using `command`/`shell`

### Changed

- Podman install and uninstall paths now use `containers.podman` modules (`podman_login`, `podman_image`, `podman_container`) instead of raw `command`
- Declare `containers.podman` as a collection dependency in `galaxy.yml`

## 2026-07-13 — Add demo.zero_trust collection with Vault role

### Added

- `demo.zero_trust` collection with Galaxy metadata, runtime requirements, and collection changelog
- `vault` role with discrete task entry points for host TLS/firewall setup, RPM install, Podman Quadlet install, and Vault init/unseal
- Setup playbook `playbooks/pb_setup_vault.yml` and vault-encrypted `playbooks/vars/secrets.yml`

### Changed

- Track the in-tree `demo.zero_trust` collection in git while still ignoring other locally installed collections
- Point ansible-lint at collection role tasks, run offline, and skip secrets files to avoid vault decrypt noise

### Removed

- Standalone `.yamllint.yml` in favor of ansible-lint’s YAML checks

## 2026-07-13 — Add project tooling and linting configuration

### Added

- Ansible configuration with Red Hat Automation Hub and Galaxy server list (`ansible.cfg`)
- Pre-commit hooks for trailing whitespace, YAML validation, and ansible-lint (`.pre-commit-config.yaml`)
- Ansible-lint production profile with FQCN enforcement and custom kind mappings (`.ansible-lint`)
- Yamllint rules for line length, truthy values, and octal handling (`.yamllint.yml`)
- EditorConfig for consistent formatting across editors (`.editorconfig`)
- Gitignore covering Ansible artifacts, Python, IDE files, Molecule, and local collections (`.gitignore`)
