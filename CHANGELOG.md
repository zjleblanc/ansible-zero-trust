# Changelog

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
