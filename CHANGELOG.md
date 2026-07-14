# Changelog

## 2026-07-13 — Add project tooling and linting configuration

### Added

- Ansible configuration with Red Hat Automation Hub and Galaxy server list (`ansible.cfg`)
- Pre-commit hooks for trailing whitespace, YAML validation, and ansible-lint (`.pre-commit-config.yaml`)
- Ansible-lint production profile with FQCN enforcement and custom kind mappings (`.ansible-lint`)
- Yamllint rules for line length, truthy values, and octal handling (`.yamllint.yml`)
- EditorConfig for consistent formatting across editors (`.editorconfig`)
- Gitignore covering Ansible artifacts, Python, IDE files, Molecule, and local collections (`.gitignore`)
