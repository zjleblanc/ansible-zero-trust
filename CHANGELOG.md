# Changelog

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
